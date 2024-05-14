local skynet = require "skynet"
local timer = require "skynet-fly.timer"
local log = require "skynet-fly.log"
local rpc_redis = require "skynet-fly.rpc.rpc_redis"
local socketchannel	= require "skynet.socketchannel"
local socket = require "skynet.socket"
local math_util = require "skynet-fly.utils.math_util"
local FRPC_PACK_ID = require "skynet-fly.enum.FRPC_PACK_ID"
local env_util = require "skynet-fly.utils.env_util"
local skynet_util = require "skynet-fly.utils.skynet_util"
local frpcpack = require "frpcpack.core"

local string = string
local tonumber = tonumber
local assert = assert
local pairs = pairs
local ipairs = ipairs
local next = next
local tinsert = table.insert
local tremove = table.remove
local tunpack = table.unpack
local type = type
local pcall = pcall
local coroutine = coroutine
local tostring = tostring
local spackstring = skynet.packstring

local UINIT32MAX = math_util.uint32max
local g_node_info_map = {}
local g_node_map = {}
local g_redis_watch_cancel_map = {}               --redis监听取消函数
local g_svr_name = env_util.get_svr_name()
local g_svr_id = env_util.get_svr_id()
local g_time_out = 1000                            --10秒
local g_session_id = 0

local g_wait_svr_name_map = {}					  --等待channel准备好请求携程列表
local g_wait_svr_id_map = {}				      --等待指定svr_id上线的携程列表

local function add_wait_svr_name_map(svr_name, co)
	if not g_wait_svr_name_map[svr_name] then
		g_wait_svr_name_map[svr_name] = {}
	end
	g_wait_svr_name_map[svr_name][co] = true
end

local function del_wait_svr_name_map(svr_name, co)
	if not g_wait_svr_name_map[svr_name] then return end
	g_wait_svr_name_map[svr_name][co] = nil
end

local function wakeup_svr_name_map(svr_name)
	local wait_map = g_wait_svr_name_map[svr_name]
	if not wait_map then return end
	for co,_ in pairs(wait_map) do
		skynet.wakeup(co)
	end
	g_wait_svr_name_map[svr_name] = nil
end

local function add_wait_svr_id_map(cluster_name, co)
	if not g_wait_svr_id_map[cluster_name] then
		g_wait_svr_id_map[cluster_name] = {}
	end
	g_wait_svr_id_map[cluster_name][co] = true
end

local function del_wait_svr_id_map(cluster_name, co)
	if not g_wait_svr_id_map[cluster_name] then return end
	g_wait_svr_id_map[cluster_name][co] = nil
end

local function wakeup_svr_id_map(cluster_name)
	local wait_map = g_wait_svr_id_map[cluster_name]
	if not wait_map then return end
	for co, _ in pairs(wait_map) do
		skynet.wakeup(co)
	end
	g_wait_svr_id_map[cluster_name] = nil
end

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
	return frpcpack.unpackresponse(msg)	-- session, ok, data, padding
end

local function new_session_id()
	local session = g_session_id
	if session >= UINIT32MAX then
		session = 0
	end
	session = session + 1
	g_session_id = session
	return session
end

local function is_exists_node(svr_name, svr_id)
	if not g_node_info_map[svr_name] then
		return false
	end

	local node_info = g_node_info_map[svr_name]
	local id_name_map = node_info.id_name_map
	if not id_name_map[svr_id] then
		return false
	end

	return true
end

local del_node = nil  --function

local function add_node(svr_name,svr_id,host)
	svr_id = tonumber(svr_id)
	assert(svr_name, "not svr_name")
	assert(svr_id, "not svr_id")
	assert(host, "not host")

	local ip, port = string.match(host, "([^:]+):(.*)$")
	local channel = socketchannel.channel {
        host = ip,
        port = tonumber(port),
        response = read_response,
        nodelay = true,
    }

	local session_id = new_session_id()
	local msg, sz = skynet.pack(g_svr_name, g_svr_id)
	local req, padding = frpcpack.packrequest(FRPC_PACK_ID.hand_shake, "hand_shake", "", session_id, 0, msg, sz, 1)
	local isok, rsp = pcall(channel.request, channel, req, session_id, padding)
	if not isok then
		log.error("frpc client hand_shake err ", svr_name, svr_id, host, tostring(rsp))
		return
	end

	socket.onclose(channel.__sock[1], function(fd)
		del_node(svr_name, svr_id)
	end)

	if not g_node_info_map[svr_name] then
		g_node_info_map[svr_name] = {
			name_list = {},           --结点名称列表
			host_list = {},			  --结点地址列表
			channel_map = {},		  --连接列表
			id_host_map = {},
			id_name_map = {},		  --svr_id映射结点名称
			balance = 1,              --简单轮询负载均衡
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
	channel_map[cluster_name] = channel

	wakeup_svr_name_map(svr_name)
	wakeup_svr_id_map(cluster_name)
end

del_node = function(svr_name,svr_id)
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
	local channel_map = node_info.channel_map

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
	local channel = channel_map[cluster_name]
	channel_map[cluster_name] = nil

	node_info.balance = 1
	if not next(name_list) then
		g_node_info_map[svr_name] = nil
	end
	channel:close()
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

--简单负载均衡拿一个准备好的channel
local function get_balance_channel(svr_name)
	assert(g_node_map[svr_name], "not exists svr_name " .. svr_name)       --没有配置连接该服务
	local node_info = g_node_info_map[svr_name]
	if not node_info then
		local co = coroutine.running()
		local ti = timer:new(g_time_out, 1, skynet.wakeup, co)
		add_wait_svr_name_map(svr_name, co)
		skynet.wait(co)
		del_wait_svr_name_map(svr_name, co)
		ti:cancel()
	end

	node_info = g_node_info_map[svr_name]
	if not node_info then   --还没有，说明超时了，还没有准备好的channel
		return false
	end

	local name_list = node_info.name_list
	local channel_map = node_info.channel_map
	
	local index = get_balance(node_info)
	local cluster_name = name_list[index]
	local channel = channel_map[cluster_name]
	return channel, cluster_name
end

--指定svr_id拿channel
local function get_svr_id_channel(svr_name, svr_id)
	assert(g_node_map[svr_name], "not exists svr_name " .. svr_name)       --没有配置连接该服务
	local cluster_name = svr_name .. ':' .. svr_id
	if not is_exists_node(svr_name, svr_id) then
		local co = coroutine.running()
		local ti = timer:new(g_time_out, 1, skynet.wakeup, co)
		add_wait_svr_id_map(cluster_name, co)
		skynet.wait(co)
		del_wait_svr_id_map(cluster_name, co)
		ti:cancel()
	end

	if not is_exists_node(svr_name, svr_id) then
		return false
	end
	local node_info = g_node_info_map[svr_name]
	local name_list = node_info.name_list
	local channel_map = node_info.channel_map
	local channel = channel_map[cluster_name]
	return channel, cluster_name
end

--拿svr_name所有channel
local function get_svr_name_all_channel(svr_name)
	assert(g_node_map[svr_name], "not exists svr_name " .. svr_name)       --没有配置连接该服务
	local node_info = g_node_info_map[svr_name]
	if not node_info then
		local co = coroutine.running()
		local ti = timer:new(g_time_out, 1, skynet.wakeup, co)
		add_wait_svr_name_map(svr_name, co)
		skynet.wait(co)
		del_wait_svr_name_map(svr_name, co)
		ti:cancel()
	end

	node_info = g_node_info_map[svr_name]
	if not node_info then   --还没有，说明超时了，还没有准备好的channel
		return false
	end

	local name_list = node_info.name_list
	local channel_map = node_info.channel_map
	
	local index = get_balance(node_info)
	local cluster_name = name_list[index]
	local channel = channel_map[cluster_name]
	return channel_map
end

local CMD = {}

--轮询给单个集群结点发
function CMD.balance_send(svr_name, module_name, instance_name, packid, mod_num, msg, sz)
	local channel = get_balance_channel(svr_name)
	if not channel then
		log.error("frpc balance_send get channel err ", svr_name, module_name, skynet.unpack(msg, sz))
		skynet.trash(msg, sz)
		return
	end
	local req, padding = frpcpack.packrequest(packid, module_name, instance_name or "", new_session_id(), mod_num or 0, msg, sz, 0)
	channel:request(req, nil ,padding)
end

--轮询给单个集群结点发
function CMD.balance_call(svr_name, module_name, instance_name, packid, mod_num, msg, sz)
	local channel, cluster_name = get_balance_channel(svr_name)
	if not channel then
		log.error("frpc balance_call get channel err ",svr_name, module_name, skynet.unpack(msg, sz))
		skynet.trash(msg, sz)
		return
	end
	local session_id = new_session_id()
	local req, padding = frpcpack.packrequest(packid, module_name, instance_name or "", session_id, mod_num or 0, msg, sz, 1)
	local isok, rsp = pcall(channel.request, channel, req, session_id, padding)
	if not isok then
		log.error("frpc balance_call req err ", isok, tostring(rsp))
		return
	end

	return cluster_name, rsp
end

--指定结点id发
function CMD.send_by_id(svr_name, svr_id, module_name, instance_name, packid, mod_num, msg, sz)
	local channel = get_svr_id_channel(svr_name, svr_id)
	if not channel then
		log.error("frpc send_by_id  err ", svr_name, svr_id, module_name, skynet.unpack(msg, sz))
		skynet.trash(msg, sz)
		return
	end
	local req, padding = frpcpack.packrequest(packid, module_name, instance_name or "", new_session_id(), mod_num or 0, msg, sz, 0)
	channel:request(req, nil, padding)
end

--指定结点id发
function CMD.call_by_id(svr_name, svr_id, module_name, instance_name, packid, mod_num, msg, sz)
	local channel, cluster_name = get_svr_id_channel(svr_name, svr_id)
	if not channel then
		log.error("frpc call_by_id err ", svr_name, svr_id, module_name, skynet.unpack(msg, sz))
		skynet.trash(msg, sz)
		return
	end
	local session_id = new_session_id()
	local req, padding = frpcpack.packrequest(packid, module_name, instance_name or "", session_id, mod_num or 0, msg, sz, 1)
	local isok, rsp = pcall(channel.request, channel, req, session_id, padding)
	if not isok then
		log.error("frpc call_by_id req err ", isok, tostring(rsp))
		return
	end

	return cluster_name, rsp
end

--给集群所有结点发
function CMD.send_all(svr_name, module_name, instance_name, packid, mod_num, msg, sz)
	local channel_map = get_svr_name_all_channel(svr_name)
	if not channel_map then
		log.error("frpc send_all err ", svr_name, module_name, skynet.unpack(msg, sz))
		skynet.trash(msg, sz)
		return
	end

	local req, padding = frpcpack.packrequest(packid, module_name, instance_name or "", new_session_id(), mod_num or 0, msg, sz, 0)
	for cluster_name, channel in pairs(channel_map) do
		local isok, rsp = pcall(channel.request, channel, req, nil, padding)
		if not isok then
			log.error("frpc send_all req err ", cluster_name, isok, tostring(rsp))
		end
	end
end

--给集群所有结点发
function CMD.call_all(svr_name, module_name, instance_name, packid, mod_num, msg, sz)
	local channel_map = get_svr_name_all_channel(svr_name)
	if not channel_map then
		log.error("frpc call_all err ", svr_name, module_name, skynet.unpack(msg, sz))
		skynet.trash(msg, sz)
		return
	end

	local session_id = new_session_id()
	local cluster_rsp_map = {}
	local req, padding = frpcpack.packrequest(packid, module_name, instance_name or "", session_id, mod_num or 0, msg, sz, 1)
	for cluster_name, channel in pairs(channel_map) do
		local isok, rsp = pcall(channel.request, channel, req, session_id, padding)
		if not isok then
			log.error("frpc call_all req err ", cluster_name, isok, tostring(rsp))
		else
			cluster_rsp_map[cluster_name] = rsp
		end
	end
	return cluster_rsp_map
end

function CMD.start(config)
	local node_map = config.node_map
	g_node_map = node_map
	assert(node_map, "not node_map")
	local watch = config.watch
	g_time_out = config.time_out or 1000
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
			for svr_name,node in pairs(node_map) do
				for svr_id,host in pairs(node) do
					add_node(svr_name,svr_id,host)
				end
			end
			--本机配置方式
			local ti = timer:new(timer.second * 1, 0, function()
				for svr_name,node in pairs(node_map) do
					for svr_id,host in pairs(node) do
						if not is_exists_node(svr_name, svr_id) then
							add_node(svr_name, svr_id, host)
						end
					end
				end
			end)
			ti:after_next()
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