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
local crypt = require "skynet.crypt"
local watch_syn = require "skynet-fly.watch.watch_syn"
local wait = require "skynet-fly.time_extend.wait"
local string_util = require "skynet-fly.utils.string_util"
local watch_server = require "skynet-fly.rpc.watch_server"
local SYSCMD = require "skynet-fly.enum.SYSCMD"
local WATCH_SYN_RET = require "skynet-fly.enum.WATCH_SYN_RET"
local contriner_interface = require "skynet-fly.contriner.contriner_interface"
local SERVER_STATE_TYPE = require "skynet-fly.enum.SERVER_STATE_TYPE"

local string = string
local tonumber = tonumber
local assert = assert
local pairs = pairs
local ipairs = ipairs
local next = next
local tinsert = table.insert
local tremove = table.remove
local type = type
local pcall = pcall
local tostring = tostring
local error = error
local coroutine = coroutine
local math = math

local UINIT32MAX = math_util.uint32max
local g_node_info_map = {}
local g_node_map = {}
local g_redis_watch_cancel_map = {}               --redis监听取消函数
local g_svr_name = env_util.get_svr_name()
local g_svr_id = env_util.get_svr_id()
local g_session_id = 0

local g_wait_svr_name = nil					  --等待channel准备好的
local g_wait_svr_id	= nil			      	  --等待指定svr_id准备好
local g_wait_watch_svr_id = nil               --等待指定watch svr_id准备好

local g_watch_server = nil
local g_active_map = {}							  --活跃列表

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

--握手服务端那边就不区分了，但是channel用的模式1
local function read_pub_hand_shake_rsp(sock)
	local sz = socket.header(sock:read(2))
	local msg = sock:read(sz)
	local _,ok, data, padding = frpcpack.unpackresponse(msg) -- ok, data, padding
	return ok, data, padding
end

local function read_pub_response(sock)
	local sz = socket.header(sock:read(2))
	local msg = sock:read(sz)
	return frpcpack.unpackpubmessage(msg) -- ok, data, padding
end

local function new_session_id()
	if g_session_id >= UINIT32MAX then
		g_session_id = 0
	end
	g_session_id = g_session_id + 1
	return g_session_id
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

local function rpc_hand_shake_req(channel, msg_secret, info)
	local session_id = new_session_id()
	local msg, sz = nil, nil
	if msg_secret then
		local msg_buff = skynet.packstring(info)
		msg = crypt.desencode(msg_secret, msg_buff)
	else
		msg, sz = skynet.pack(info)
	end
	local req, padding = frpcpack.packrequest(FRPC_PACK_ID.hand_shake, "hand_shake", "", session_id, 0, msg, sz, 1)
	local isok, rsp = pcall(channel.request, channel, req, session_id, padding)
	if not isok then
		log.warn("frpc client hand_shake err ", tostring(rsp))
		return
	end

	local ret = skynet.unpack(rsp)
	return ret
end

local function watch_hand_shake_req(channel, msg_secret, info)
	local session_id = new_session_id()
	local msg, sz = nil, nil
	if msg_secret then
		local msg_buff = skynet.packstring(info)
		msg = crypt.desencode(msg_secret, msg_buff)
	else
		msg, sz = skynet.pack(info)
	end
	local req, padding = frpcpack.packrequest(FRPC_PACK_ID.hand_shake, "hand_shake", "", session_id, 0, msg, sz, 1)
	local isok, rsp = pcall(channel.request, channel, req, read_pub_hand_shake_rsp, padding)
	if not isok then
		log.warn("frpc client hand_shake err ", tostring(rsp))
		return
	end

	local ret = skynet.unpack(rsp)
	return ret
end

local function do_hand_shake_channel(channel, secret_key, is_encrypt, is_watch)
	local msg_secret = nil
	local hand_shake_req = rpc_hand_shake_req
	if is_watch then
		hand_shake_req = watch_hand_shake_req
	end

	if (secret_key or is_encrypt) then
		local info = {
			step = 1,
		}

		local challenge = hand_shake_req(channel, msg_secret, info)
		if not challenge then
			log.warn("frpc client hand_shake get challenge err")
			return
		end

		challenge = crypt.base64decode(challenge)

		local client_key = crypt.randomkey()
		info.step = 2
		info.client_key = crypt.base64encode((crypt.dhexchange(client_key)))
		local server_key = hand_shake_req(channel, msg_secret, info)
		if not server_key then
			log.warn("frpc client hand_shake get server_key err")
			return
		end
		server_key = crypt.base64decode(server_key)
		local secret = crypt.dhsecret(server_key, client_key)

		info.client_key = nil
		info.step = 3
		info.challenge = crypt.hmac64(challenge, secret)
		local ret = hand_shake_req(channel, msg_secret, info)
		if ret ~= 'ok' then
			log.warn("frpc client hand_shake msg_secret err")
			return
		end

		msg_secret = secret
	end

	local info = {
		cluster_name = g_svr_name,
		cluster_svr_id = g_svr_id,
		secret_key = secret_key,
		is_watch = is_watch,
	}

	local ret = hand_shake_req(channel, msg_secret, info)
	if ret ~= "ok" then
		log.warn("frpc client hand_shake err ", ret)
		return
	end
	
	return true, msg_secret
end

local function add_node(svr_name, svr_id, host, secret_key, is_encrypt)
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

	local cluster_name = svr_name .. ':' .. svr_id
	
	local isok, msg_secret = do_hand_shake_channel(channel, secret_key, is_encrypt) 
	if not isok then
		log.warn("frpc client hand_shake err ", svr_name, svr_id, host)
		g_wait_svr_name:wakeup(svr_name)
		g_wait_svr_id:wakeup(cluster_name)
		return
	end

	socket.onclose(channel.__sock[1], function(fd)
		del_node(svr_name, svr_id)
	end)

	if not g_node_info_map[svr_name] then
		g_node_info_map[svr_name] = {
			name_list = {},           --结点名称列表
			host_list = {},			  --结点地址列表
			channel_map = {},		  --连接表
			secret_map = {},		  --密钥表
			id_host_map = {},
			id_name_map = {},		  --svr_id映射结点名称
			balance = 1,              --简单轮询负载均衡
			secret_key_map = {},	  --连接密钥表
			is_encrypt_map = {},	  --是否加密消息
			
			watch_connecting = {},    --是否watch连接中
			watch_channel_map = {},   --监听连接表
			watch_secret_map = {},    --监听密钥表
			watch_syn_map = {},		  --监听同步列表信息
		}

		g_active_map[svr_name] = {}
	end
	g_active_map[svr_name][svr_id] = channel.__sock[1]

	local node_info = g_node_info_map[svr_name]
	local id_name_map = node_info.id_name_map
	assert(not id_name_map[svr_id], "is exists " .. svr_id)
	
	local name_list = node_info.name_list
	local host_list = node_info.host_list
	local id_host_map = node_info.id_host_map
	local channel_map = node_info.channel_map
	local secret_map = node_info.secret_map
	local secret_key_map = node_info.secret_key_map
	local is_encrypt_map = node_info.is_encrypt_map

	tinsert(name_list,cluster_name)
	tinsert(host_list,host)
	id_name_map[svr_id] = cluster_name
	id_host_map[svr_id] = host
	channel_map[cluster_name] = channel

	secret_key_map[cluster_name] = secret_key
	is_encrypt_map[cluster_name] = is_encrypt

	if is_encrypt then
		secret_map[cluster_name] = msg_secret
	end

	g_wait_svr_name:wakeup(svr_name)
	g_wait_svr_id:wakeup(cluster_name)

	g_watch_server:publish("active", g_active_map)
	log.info("connected to " .. cluster_name .. ' host ' .. host)
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
	local secret_map = node_info.secret_map
	local secret_key_map = node_info.secret_key_map
	local is_encrypt_map = node_info.is_encrypt_map
	local watch_connecting = node_info.watch_connecting
	local watch_channel_map = node_info.watch_channel_map
	local watch_secret_map = node_info.watch_secret_map
	local watch_syn_map = node_info.watch_syn_map

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
	local host = id_host_map[svr_id]
	id_name_map[svr_id] = nil
	id_host_map[svr_id] = nil
	local channel = channel_map[cluster_name]
	channel_map[cluster_name] = nil
	secret_key_map[cluster_name] = nil
	is_encrypt_map[cluster_name] = nil

	watch_connecting[cluster_name] = nil
	local watch_channel = watch_channel_map[cluster_name]
	watch_channel_map[cluster_name] = nil
	node_info.balance = 1

	g_active_map[svr_name][svr_id] = nil
	if not next(name_list) then
		g_active_map[svr_name] = nil
		g_node_info_map[svr_name] = nil
	end
	g_watch_server:publish("active", g_active_map)
	channel:close()
	if watch_channel then
		watch_channel:close()
	end
	secret_map[cluster_name] = nil
	watch_secret_map[cluster_name] = nil
	watch_syn_map[cluster_name] = nil
	log.info("disconnect to " .. cluster_name .. ' host ' .. host)
end

local function connect_watch(host, secret_key, is_encrypt)
	local ip, port = string.match(host, "([^:]+):(.*)$")
	local channel = socketchannel.channel {
        host = ip,
        port = tonumber(port),
        nodelay = true,
    }
	
	local isok, msg_secret = do_hand_shake_channel(channel, secret_key, is_encrypt, true)
	if not isok then
		error("frpc client hand_shake err " .. host)
	end
	
	return channel, msg_secret
end

local function rsp_source_map(channel_info, ret, version, luamsg)
	if not channel_info then return end
	local source_map = channel_info.source_map
	local source_v_map = channel_info.source_v_map
	if not source_map then return end

	for source,response in pairs(source_map) do
		local v = source_v_map[source]
		if version ~= v then
			response(true, ret, version, luamsg)
			source_map[source] = nil
			source_v_map[source] = nil
		end
	end
end

local function add_node_watch(cluster_name)
	local sp = string_util.split(cluster_name, ':')
	local svr_name, svr_id = sp[1], tonumber(sp[2])
	local node_info = g_node_info_map[svr_name]
	assert(node_info, "not node info")
	local watch_connecting = node_info.watch_connecting
	if watch_connecting[cluster_name] then   --连接中
		return
	end

	watch_connecting[cluster_name] = true
	local id_host_map = node_info.id_host_map
	local host = id_host_map[svr_id]
	assert(host, "not host")

	local secret_key_map = node_info.secret_key_map
	local is_encrypt_map = node_info.is_encrypt_map

	local secret_key, is_encrypt = secret_key_map[cluster_name], is_encrypt_map[cluster_name]
	local isok, channel, msg_secret = pcall(connect_watch, host, secret_key, is_encrypt)

	watch_connecting[cluster_name] = nil
	if not isok then
		log.error("connect_watch err ", channel, cluster_name)
		g_wait_watch_svr_id:wakeup(cluster_name)
		return
	end

	local watch_channel_map = node_info.watch_channel_map
	local watch_secret_map = node_info.watch_secret_map
	local watch_syn_map = node_info.watch_syn_map
	watch_channel_map[cluster_name] = channel
	watch_secret_map[cluster_name] = msg_secret
	watch_syn_map[cluster_name] = {}

	g_wait_watch_svr_id:wakeup(cluster_name)

	local sub_watch_map = {}
	log.info("watch connected to " .. cluster_name .. ' host ' .. host)

	local watch_syn_info = watch_syn_map[cluster_name]

	skynet.fork(function()
		while true do
			local isok, rsp = pcall(channel.response, channel, read_pub_response)
			if not isok then
				log.error("watch message err ", cluster_name, rsp)
				break
			end
			local isok,pack_id, session, channel_name
			if type(rsp) == 'table' then
				--large msg
				local head_msg = rsp[1]
				if not head_msg then
					log.error("watch message not head_msg ", cluster_name)
				else
					local totalsz = head_msg:byte(1) | head_msg:byte(2)<<8 | head_msg:byte(3)<<16 | head_msg:byte(4)<<24
					pack_id = head_msg:byte(5)
					session = head_msg:byte(6) | head_msg:byte(7)<<8 | head_msg:byte(8)<<16 | head_msg:byte(9)<<24
					--local channel_sz = head_msg:byte(10)
					channel_name = head_msg:sub(11)
					rsp[1] = totalsz
					local msg, sz = frpcpack.concat(rsp)
					if not msg then
						log.error("watch message concat rsp err ", #rsp, cluster_name)
					else
						log.warn_fmt("watch large msg size = %dkb from %s", math.floor(totalsz / 1024), cluster_name)
						rsp = skynet.tostring(msg, sz)
						skynet.trash(msg, sz)
						isok = true
					end
				end
			else
				pack_id = rsp:byte(1)
				session = rsp:byte(2) | rsp:byte(3)<<8 | rsp:byte(4)<<16 | rsp:byte(5)<<24
				local channel_sz = rsp:byte(6)
				channel_name = rsp:sub(7, channel_sz + 6)
				rsp = rsp:sub(channel_sz + 7)
				isok = true
			end

			if isok then
				if msg_secret then
					rsp = crypt.desdecode(msg_secret, rsp)
				end			
			
				if pack_id == FRPC_PACK_ID.pubmessage then
					local source_map = sub_watch_map[channel_name]
					if source_map then
						for _, source in pairs(source_map) do
							skynet.send(source, 'lua', SYSCMD.frpcpubmsg, session, svr_name, svr_id, channel_name, rsp)
						end
					end
				elseif pack_id == FRPC_PACK_ID.sub then
					local source, unique_name = skynet.unpack(rsp)
					if not sub_watch_map[channel_name] then
						sub_watch_map[channel_name] = {}
					end
					sub_watch_map[channel_name][unique_name] = source
				elseif pack_id == FRPC_PACK_ID.unsub then
					local _, unique_name = skynet.unpack(rsp)
					if sub_watch_map[channel_name] then
						sub_watch_map[channel_name][unique_name] = nil

						if not next(sub_watch_map[channel_name]) then
							sub_watch_map[channel_name] = nil
						end
					end
				elseif pack_id == FRPC_PACK_ID.subsyn then
					local version, luamsg = skynet.unpack(rsp)
					local channel_info = watch_syn_info[channel_name]
					if channel_info then
						channel_info.version = version
						channel_info.luamsg = luamsg
						channel_info.req_syned = false
						rsp_source_map(channel_info, WATCH_SYN_RET.syn, version, luamsg)
					end
				elseif pack_id == FRPC_PACK_ID.unsubsyn then

				else
					log.warn("unknown pub msg ",cluster_name, pack_id)
				end
			end
		end

		channel:close()
		watch_channel_map[cluster_name] = nil
		watch_secret_map[cluster_name] = nil
		watch_syn_map[cluster_name] = nil

		
		for channel_name,channel_info in pairs(watch_syn_info) do
			rsp_source_map(channel_info, WATCH_SYN_RET.disconnect)
		end

		log.info("watch disconnected ", cluster_name, host)
	end)
end

contriner_interface.hook_fix_exit_after(function()
	for svr_name, node_info in pairs(g_node_info_map) do
		local watch_syn_map = node_info.watch_syn_map
		for cluster_name, watch_syn_info in pairs(watch_syn_map) do
			for channel_name,channel_info in pairs(watch_syn_info) do
				rsp_source_map(channel_info, WATCH_SYN_RET.move)
			end
		end
	end
end)

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
		g_wait_svr_name:wait(svr_name)
	end

	node_info = g_node_info_map[svr_name]
	if not node_info then   --还没有，说明超时了，还没有准备好的channel
		return false
	end

	local name_list = node_info.name_list
	local channel_map = node_info.channel_map
	local secret_map = node_info.secret_map
	
	local index = get_balance(node_info)
	local cluster_name = name_list[index]
	local channel = channel_map[cluster_name]
	local secret = secret_map[cluster_name]
	return channel, cluster_name, secret
end

--指定svr_id拿channel
local function get_svr_id_channel(svr_name, svr_id)
	assert(g_node_map[svr_name], "not exists svr_name " .. svr_name)       --没有配置连接该服务
	local cluster_name = svr_name .. ':' .. svr_id
	if not is_exists_node(svr_name, svr_id) then
		g_wait_svr_id:wait(cluster_name)
	end

	if not is_exists_node(svr_name, svr_id) then
		return false
	end
	local node_info = g_node_info_map[svr_name]
	local channel_map = node_info.channel_map
	local secret_map = node_info.secret_map
	local channel = channel_map[cluster_name]
	local secret = secret_map[cluster_name]
	return channel, cluster_name, secret
end

--拿svr_name所有channel
local function get_svr_name_all_channel(svr_name)
	assert(g_node_map[svr_name], "not exists svr_name " .. svr_name)       --没有配置连接该服务
	local node_info = g_node_info_map[svr_name]
	if not node_info then
		g_wait_svr_name:wait(svr_name)
	end

	node_info = g_node_info_map[svr_name]
	if not node_info then   --还没有，说明超时了，还没有准备好的channel
		return false
	end

	local channel_map = node_info.channel_map
	local secret_map = node_info.secret_map

	return channel_map, secret_map
end

--获得准备好的watch_channel
local function get_watch_channel(svr_name, svr_id)
	assert(g_node_map[svr_name], "not exists svr_name " .. svr_name)       --没有配置连接该服务
	local _, cluster_name = get_svr_id_channel(svr_name, svr_id)
	if not cluster_name then
		return false
	end

	local node_info = g_node_info_map[svr_name]
	local watch_channel_map = node_info.watch_channel_map

	if not watch_channel_map[cluster_name] then                            --不存在连接
		--watch 连接惰性建立，因为可能不是必须要建立(可能业务逻辑不需要watch其他服务)
		skynet.fork(add_node_watch, cluster_name)
		g_wait_watch_svr_id:wait(cluster_name)
	end

	node_info = g_node_info_map[svr_name]
	if not node_info then
		return false
	end
	watch_channel_map = node_info.watch_channel_map

	if not watch_channel_map[cluster_name] then
		return false
	end

	local watch_secret_map = node_info.watch_secret_map
	local watch_syn_map = node_info.watch_syn_map
	local channel = watch_channel_map[cluster_name]	
	local secret = watch_secret_map[cluster_name]
	local watch_syn_info = watch_syn_map[cluster_name]
	return channel, cluster_name, secret, watch_syn_info
end

local CMD = {}

local function crypt_msg(secret, msg, sz)
	local msg_buff = skynet.tostring(msg, sz)
	skynet.trash(msg, sz)
	msg_buff = crypt.desencode(secret, msg_buff)
	return msg_buff
end

--轮询给单个集群结点发
function CMD.balance_send(svr_name, module_name, instance_name, packid, mod_num, msg, sz)
	local channel, _, secret = get_balance_channel(svr_name)
	if not channel then
		log.error("frpc balance_send not connect ", svr_name, module_name, skynet.unpack(msg, sz))
		skynet.trash(msg, sz)
		return
	end
	if secret then
		msg, sz = crypt_msg(secret, msg, sz)
	end
	local req, padding = frpcpack.packrequest(packid, module_name, instance_name or "", new_session_id(), mod_num or 0, msg, sz, 0)
	channel:request(req, nil ,padding)
end

--轮询给单个集群结点发
function CMD.balance_call(svr_name, module_name, instance_name, packid, mod_num, msg, sz)
	local channel, cluster_name, secret = get_balance_channel(svr_name)
	if not channel then
		log.error("frpc balance_call not connect ",svr_name, module_name, skynet.unpack(msg, sz))
		skynet.trash(msg, sz)
		return
	end
	if secret then
		msg, sz = crypt_msg(secret, msg, sz)
	end
	local session_id = new_session_id()
	local req, padding = frpcpack.packrequest(packid, module_name, instance_name or "", session_id, mod_num or 0, msg, sz, 1)
	local isok, rsp = pcall(channel.request, channel, req, session_id, padding)
	if not isok then
		log.error("frpc balance_call req err ", isok, tostring(rsp))
		return
	end

	return cluster_name, rsp, secret
end

--指定结点id发
function CMD.send_by_id(svr_name, svr_id, module_name, instance_name, packid, mod_num, msg, sz)
	local channel, _, secret = get_svr_id_channel(svr_name, svr_id)
	if not channel then
		log.error("frpc send_by_id not connect ", svr_name, svr_id, module_name, skynet.unpack(msg, sz))
		skynet.trash(msg, sz)
		return
	end
	if secret then
		msg, sz = crypt_msg(secret, msg, sz)
	end
	local req, padding = frpcpack.packrequest(packid, module_name, instance_name or "", new_session_id(), mod_num or 0, msg, sz, 0)
	channel:request(req, nil, padding)
end

--指定结点id发
function CMD.call_by_id(svr_name, svr_id, module_name, instance_name, packid, mod_num, msg, sz)
	local channel, cluster_name, secret = get_svr_id_channel(svr_name, svr_id)
	if not channel then
		log.error("frpc call_by_id not connect ", svr_name, svr_id, module_name, skynet.unpack(msg, sz))
		skynet.trash(msg, sz)
		return
	end
	if secret then
		msg, sz = crypt_msg(secret, msg, sz)
	end
	local session_id = new_session_id()
	local req, padding = frpcpack.packrequest(packid, module_name, instance_name or "", session_id, mod_num or 0, msg, sz, 1)
	local isok, rsp = pcall(channel.request, channel, req, session_id, padding)
	if not isok then
		log.error("frpc call_by_id req err ", isok, tostring(rsp))
		return
	end

	return cluster_name, rsp, secret
end

--给集群所有结点发
function CMD.send_all(svr_name, module_name, instance_name, packid, mod_num, msg, sz)
	local channel_map, secret_map = get_svr_name_all_channel(svr_name)
	if not channel_map then
		log.error("frpc send_all not connect ", svr_name, module_name, skynet.unpack(msg, sz))
		skynet.trash(msg, sz)
		return
	end

	local msg_buff = skynet.tostring(msg, sz)
	skynet.trash(msg, sz)

	local multreq, multpadding = nil, nil					--没有加密的话，可以发相同的包
	local session_id = new_session_id()
	for cluster_name, channel in pairs(channel_map) do
		local req, padding
		local secret = secret_map[cluster_name]
		if secret then
			local curmsg, cursz = crypt.desencode(secret, msg_buff)
			req, padding = frpcpack.packrequest(packid, module_name, instance_name or "", session_id, mod_num or 0, curmsg, cursz, 0)
		else
			if not multreq then
				multreq, multpadding = frpcpack.packrequest(packid, module_name, instance_name or "", session_id, mod_num or 0, msg_buff, nil, 0)
			end
			req, padding = multreq, multpadding
		end

		local isok, rsp = pcall(channel.request, channel, req, nil, padding)
		if not isok then
			log.error("frpc send_all req err ", cluster_name, isok, tostring(rsp))
		end
	end
end

--给集群所有结点发
function CMD.call_all(svr_name, module_name, instance_name, packid, mod_num, msg, sz)
	local channel_map, secret_map = get_svr_name_all_channel(svr_name)
	if not channel_map then
		log.error("frpc call_all not connect ", svr_name, module_name, skynet.unpack(msg, sz))
		skynet.trash(msg, sz)
		return
	end

	local msg_buff = skynet.tostring(msg, sz)
	skynet.trash(msg, sz)
	local session_id = new_session_id()
	local cluster_rsp_map = {}
	local multreq, multpadding = nil, nil					--没有加密的话，可以发相同的包
	for cluster_name, channel in pairs(channel_map) do
		local req, padding
		local secret = secret_map[cluster_name]
		if secret then
			local curmsg, cursz = crypt.desencode(secret, msg_buff)
			req, padding = frpcpack.packrequest(packid, module_name, instance_name or "", session_id, mod_num or 0, curmsg, cursz, 1)
		else
			if not multreq then
				multreq, multpadding = frpcpack.packrequest(packid, module_name, instance_name or "", session_id, mod_num or 0, msg_buff, nil, 1)
			end
			req, padding = multreq, multpadding
		end

		local isok, rsp = pcall(channel.request, channel, req, session_id, padding)
		if not isok then
			log.error("frpc call_all req err ", cluster_name, isok, tostring(rsp))
		else
			cluster_rsp_map[cluster_name] = rsp
		end
	end
	return cluster_rsp_map, secret_map
end

--订阅
function CMD.sub(svr_name, svr_id, source, channel_name, unique_name)
	local channel, _, secret = get_watch_channel(svr_name, svr_id)
	if not channel then
		log.error("frpc watch not connect ", svr_name, source, channel_name)
		return nil, "not watch channel"
	end

	local msg_buff = skynet.packstring(channel_name, source, unique_name)
	if secret then
		msg_buff = crypt.desencode(secret, msg_buff)
	end
	local session_id = new_session_id()
	local req, padding = frpcpack.packrequest(FRPC_PACK_ID.sub, "", "", session_id, 0, msg_buff, nil, 0)
	local isok, err = pcall(channel.request, channel, req, nil, padding)
	if not isok then 
		return nil, err
	end
	return true
end

--取消订阅
function CMD.unsub(svr_name, svr_id, source, channel_name, unique_name)
	local channel, _, secret = get_watch_channel(svr_name, svr_id)
	if not channel then
		log.error("frpc watch not connect ", svr_name, source, channel_name)
		return nil, "not watch channel"
	end
	local msg_buff = skynet.packstring(channel_name, source, unique_name)
	if secret then
		msg_buff = crypt.desencode(secret, msg_buff)
	end
	local session_id = new_session_id()
	local req, padding = frpcpack.packrequest(FRPC_PACK_ID.unsub, "", "", session_id, 0, msg_buff, nil, 0)
	local isok, err = pcall(channel.request, channel, req, nil, padding)
	if not isok then 
		return nil, err
	end
	return true
end

--订阅同步
function CMD.subsyn(svr_name, svr_id, source, channel_name, version)
	if contriner_interface.get_server_state == SERVER_STATE_TYPE.fix_exited then
		return WATCH_SYN_RET.move
	end
	local channel, cluster_name, secret, watch_syn_info = get_watch_channel(svr_name, svr_id)
	if not channel then
		log.error("frpc watch not connect ", svr_name, source, channel_name)
		return nil, "not watch channel"
	end

	local channel_info = watch_syn_info[channel_name]
	if not channel_info or not channel_info.version or channel_info.version == version then
		if not channel_info then
			watch_syn_info[channel_name] = {}
			channel_info = watch_syn_info[channel_name]
		end
		if not channel_info.source_map then
			channel_info.source_map = {}
			channel_info.source_v_map = {}
		end                                                          
		local source_map = channel_info.source_map
		local source_v_map = channel_info.source_v_map
		assert(not source_map[source], "repeat subsyn ", cluster_name, channel_name)
		
		source_map[source] = skynet.response()
		source_v_map[source] = version
		
		if not channel_info.req_syned then
			channel_info.req_syned = true
			local msg_buff = skynet.packstring(channel_name, channel_info.version or 0)
			if secret then
				msg_buff = crypt.desencode(secret, msg_buff)
			end
			local session_id = new_session_id()
			local req, padding = frpcpack.packrequest(FRPC_PACK_ID.subsyn, "", "", session_id, 0, msg_buff, nil, 0)
			local isok, err = pcall(channel.request, channel, req, nil, padding)
			if not isok then 
				return nil, err
			end
		end

		return skynet_util.NOT_RET
	else
		return WATCH_SYN_RET.syn, channel_info.version, channel_info.luamsg
	end
end

--取消订阅同步
function CMD.unsubsyn(svr_name, svr_id, source, channel_name)
	local channel, _, secret, watch_syn_info = get_watch_channel(svr_name, svr_id)
	if not channel then
		log.error("frpc watch not connect ", svr_name, source, channel_name)
		return nil, "not watch channel"
	end
	local channel_info = watch_syn_info[channel_name]
	if not channel_info then return end

	local source_map = channel_info.source_map
	if not source_map then return end
	local rsp = source_map[source]
	source_map[source] = nil
	if not rsp then return end
	rsp(true, WATCH_SYN_RET.unsyn)

	if next(source_map) then
		return
	end

	local msg_buff = skynet.packstring(channel_name)
	if secret then
		msg_buff = crypt.desencode(secret, msg_buff)
	end
	local session_id = new_session_id()
	local req, padding = frpcpack.packrequest(FRPC_PACK_ID.unsubsyn, "", "", session_id, 0, msg_buff, nil, 0)
	local isok, err = pcall(channel.request, channel, req, nil, padding)
	if not isok then 
		return nil, err
	end
	return true
end

function CMD.start(config)
	local node_map = config.node_map
	g_node_map = node_map
	assert(node_map, "not node_map")
	local watch = config.watch
	local time_out = config.time_out or 1000
	g_wait_svr_name = wait:new(time_out)
	g_wait_svr_id = wait:new(time_out)
	g_wait_watch_svr_id = wait:new(time_out)
	
	skynet.fork(function()
		if watch == 'redis' then
			--redis服务发现方式
			local rpccli = rpc_redis:new()
			for svr_name,node in pairs(node_map) do
				g_redis_watch_cancel_map[svr_name] = rpccli:watch(svr_name, function(event, name, id, host, secret_key, is_encrypt)
					if event == 'set' then            --设置
						local old_host = get_node_host(name, id)
						if old_host ~= host then
							del_node(name, id)
							add_node(name, id, host, secret_key, is_encrypt)
							log.info("change cluster node :",name, id, old_host, host, secret_key, is_encrypt)
						end
					elseif event == 'expired' then    --过期
						del_node(name,id)
						log.info("down cluster node :",name,id)
					elseif event == 'get_failed' then --拿不到配置，通常是因为redis挂了，或者key被意外删除，或者redis出现性能瓶颈了
						del_node(name,id)
						log.error("get_failed cluster node :",name,id)
					end
				end)
			end
		else
			local function add_node_info()
				for svr_name,node in pairs(node_map) do
					for _,info in pairs(node) do
						local svr_id = info.svr_id
						local host = info.host
						local secret_key = info.secret_key
						local is_encrypt = info.is_encrypt
						if not is_exists_node(svr_name, svr_id) then
							add_node(svr_name, svr_id, host, secret_key, is_encrypt)
						end
					end
				end
			end

			add_node_info()
			--本机配置方式
			timer:new(timer.second * 1, 0, add_node_info):after_next()
		end
	end)

	g_watch_server:register("active", g_active_map)
	
	return true
end

function CMD.fix_exit()
	--取消监听
	for _,cancel in pairs(g_redis_watch_cancel_map) do
		cancel()
	end

	timer:new(timer.minute, 1, function()
		for svr_name, node_info in pairs(g_node_info_map) do
			local id_name_map = node_info.id_name_map
			for svr_id in pairs(id_name_map) do
				skynet.fork(del_node, svr_name, svr_id)
			end
		end
	end)
	return true
end

function CMD.exit()
	
	return true
end

g_watch_server = watch_syn.new_server(CMD)

return CMD