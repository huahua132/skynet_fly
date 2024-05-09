local skynet = require "skynet"
local timer = require "skynet-fly.timer"
local log = require "skynet-fly.log"
local rpc_redis = require "skynet-fly.rpc.rpc_redis"
local socketchannel	= require "skynet.socketchannel"
local socket = require "skynet.socket"
local frpc_netpack = require "skynet-fly.netpack.frpc_netpack"
local math_util = require "skynet-fly.utils.math_util"
local FRPC_PACK_ID = require "skynet-fly.enum.FRPC_PACK_ID"
local env_util = require "skynet-fly.utils.env_util"
local skynet_util = require "skynet-fly.utils.skynet_util"

local string = string
local tonumber = tonumber
local assert = assert
local pairs = pairs
local ipairs = ipairs
local next = next
local tinsert = table.insert
local tremove = table.remove
local tunpack = table.unpack
local pcall = pcall
local spackstring = skynet.packstring

local g_reqtab = {}
local UINIT32MAX = math_util.uint32max
local g_node_info_map = {}
local g_config = nil
local g_redis_watch_cancel_map = {}               --redis监听取消函数
local g_svr_name = env_util.get_svr_name()
local g_svr_id = env_util.get_svr_id()

local function get_node_host(svr_name,svr_id)
	svr_id = tonumber(svr_id)
	assert(svr_name, "not svr_name")
	assert(svr_id, "not svr_id")

	local node_info = g_node_info_map[svr_name]
	if not node_info then
		return nil
	end

	local id_host_map = node_info.id_host_map
	return id_host_map[svr_id]
end

local function read_response(sock)
	local sz = socket.header(sock:read(2))
	local msg = sock:read(sz)
    local pack_id, packbody = frpc_netpack.unpack_by_id(msg)
	if not pack_id then
		return nil
	end

	local session_id = packbody.session_id
	return session_id, true, packbody
end

local function new_session_id(node_info)
	local session_id = node_info.session_id
	if session_id >= UINIT32MAX then
		session_id = 0
	end
	session_id = session_id + 1
	node_info.session_id = session_id
	return session_id
end

local function add_node(svr_name,svr_id,host)
	svr_id = tonumber(svr_id)
	assert(svr_name, "not svr_name")
	assert(svr_id, "not svr_id")
	assert(host, "not host")
	if not g_node_info_map[svr_name] then
		g_node_info_map[svr_name] = {
			name_list = {},           --结点名称列表
			host_list = {},			  --结点地址列表
			channel_map = {},		  --连接列表
			id_host_map = {},
			id_name_map = {},		  --svr_id映射结点名称
			balance = 1,              --简单轮询负载均衡
			session_id = 0,
		}
	end

	local node_info = g_node_info_map[svr_name]
	local id_name_map = node_info.id_name_map
	assert(not id_name_map[svr_id], "is exists " .. svr_id)
	
	local name_list = node_info.name_list
	local host_list = node_info.host_list
	local id_host_map = node_info.id_host_map
	local channel_map = node_info.channel_map

	local cluster_name = svr_name .. ':' .. svr_id
	tinsert(name_list,cluster_name)
	tinsert(host_list,host)
	id_name_map[svr_id] = cluster_name
	id_host_map[svr_id] = host
    local ip, port = string.match(host, "([^:]+):(.*)$")
	local channel = socketchannel.channel {
        host = ip,
        port = tonumber(port),
        response = read_response,
        nodelay = true,
    }

	channel_map[cluster_name] = channel
	local session_id = new_session_id(node_info)
	local req = {
		module_name = "",
		session_id = session_id,
		mod_num = 0,
		lua_msgs = spackstring({g_svr_name, g_svr_id}),
	}

	local msg = frpc_netpack.pack_by_id(FRPC_PACK_ID.hand_shake, req)
	local send_buffer = string.pack(">I2",msg:len()) .. msg
	local rsp = channel:request(send_buffer, session_id)
end

local function del_node(svr_name,svr_id)
	svr_id = tonumber(svr_id)
	assert(svr_name, "not svr_name")
	assert(svr_id, "not svr_id")

	if not g_node_info_map[svr_name] then return end

	local node_info = g_node_info_map[svr_name]
	local id_name_map = node_info.id_name_map
	local cluster_name = id_name_map[svr_id]

	if not cluster_name then return end

	local name_list = node_info.name_list
	local host_list = node_info.host_list
	local id_host_map = node_info.id_host_map

	local del_index = nil
	for i = #name_list,1,-1 do
		local tmp_name = name_list[i]
		if tmp_name == cluster_name then
			del_index = i
			break
		end
	end

	if not del_index then return end

	tremove(name_list,del_index)
	tremove(host_list,del_index)
	id_name_map[svr_id] = nil
	id_host_map[svr_id] = nil

	node_info.balance = 1
	if not next(name_list) then
		g_node_info_map[svr_name] = nil
	end
	node_info.channel:close()
end

local function get_balance(node_info)
	local name_list = node_info.name_list
	local len = #name_list
	local balance = node_info.balance

	node_info.balance = node_info.balance + 1
	if node_info.balance > len then
		node_info.balance = 1
	end
	return balance
end

local CMD = {}

--轮询给单个集群结点发
function CMD.balance_send(svr_name, module_name, lua_msgs)
	if not g_node_info_map[svr_name] then
		log.warn("balance_send not exists " .. svr_name)
		return
	end

	local node_info = g_node_info_map[svr_name]
	local name_list = node_info.name_list
	local channel_map = node_info.channel_map

	local index = get_balance(node_info)
	local cluster_name = name_list[index]

	local req = {
		module_name = module_name,
		session_id = 0,
		mod_num = 0,
		lua_msgs = lua_msgs
	}

	local msg = frpc_netpack.pack_by_id(FRPC_PACK_ID.balance_send, req)
	local send_buffer = string.pack(">I2",msg:len()) .. msg
	channel_map[cluster_name]:request(send_buffer)
end

--轮询给单个集群结点发
function CMD.balance_call(svr_name, module_name, lua_msgs)
	if not g_node_info_map[svr_name] then
		log.warn("balance_call not exists " .. svr_name)
		return
	end

	local node_info = g_node_info_map[svr_name]
	local name_list = node_info.name_list
	local channel_map = node_info.channel_map

	local index = get_balance(node_info)
	local cluster_name = name_list[index]

	local session_id = new_session_id(node_info)
	local req = g_reqtab
	req.module_name = module_name
	req.session_id = session_id
	req.mod_num = 0
	req.lua_msgs = lua_msgs

	local msg = frpc_netpack.pack_by_id(FRPC_PACK_ID.balance_call, req)
	local send_buffer = string.pack(">I2",msg:len()) .. msg
	local rsp = channel_map[cluster_name]:request(send_buffer, session_id)

	return cluster_name, rsp.lua_msgs
end

--指定结点id发
function CMD.send_by_id(svr_name,svr_id,...)

end

--指定结点id发
function CMD.call_by_id(svr_name,svr_id,...)

end

--给集群所有结点发
function CMD.send_all(svr_name,...)

end

--给集群所有结点发
function CMD.call_all(svr_name,...)

end

function CMD.start(config)
	g_config = config
	local node_map = config.node_map
	assert(node_map, "not node_map")
	local watch = config.watch

	skynet.fork(function()
		if watch == 'redis' then
			--redis服务发现方式
			local rpccli = rpc_redis:new()
			for svr_name,node in pairs(node_map) do
				g_redis_watch_cancel_map[svr_name] = rpccli:watch(svr_name,function(event,name,id,host)
					if event == 'set' then            --设置
						local old_host = get_node_host(name,id)
						if old_host ~= host then
							del_node(name,id)
							add_node(name,id,host)
							log.error("change cluster node :",name,id,old_host,host)
						end
					elseif event == 'expired' then    --过期
						del_node(name,id)
						log.error("down cluster node :",name,id)
					elseif event == 'get_failed' then --拿不到配置，通常是因为redis挂了，或者key被意外删除，或者redis出现性能瓶颈了
						del_node(name,id)
						log.error("get_failed cluster node :",name,id)
					end
				end)
			end
		else
			--本机配置方式
			for svr_name,node in pairs(node_map) do
				for svr_id,host in pairs(node) do
					add_node(svr_name,svr_id,host)
				end
			end
		end
	end)
	
	return true
end

function CMD.exit()
	--取消监听
	for _,cancel in pairs(g_redis_watch_cancel_map) do
		cancel()
	end
	return true
end

return CMD