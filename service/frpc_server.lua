local skynet = require "skynet"
local contriner_client = require "skynet-fly.client.contriner_client"
local rpc_redis = require "skynet-fly.rpc.rpc_redis"
local log = require "skynet-fly.log"
local timer = require "skynet-fly.timer"
local skynet_util = require "skynet-fly.utils.skynet_util"
local FRPC_PACK_ID = require "skynet-fly.enum.FRPC_PACK_ID"
local env_util = require "skynet-fly.utils.env_util"
local frpcpack = require "frpcpack.core"
local socket = require "skynet.socket"

local pairs = pairs
local assert = assert
local tonumber = tonumber
local setmetatable = setmetatable
local type = type
local string = string
local pcall = pcall
local tremove = table.remove
local ipairs = ipairs
local tostring = tostring

local g_gate = nil
local g_svr_name = env_util.get_svr_name()
local g_svr_id = env_util.get_svr_id()
local g_fd_agent_map = {}                           --fd 连接管理

contriner_client:register("share_config_m")

local g_client_map = setmetatable({},{__index = function(t,key)
	t[key] = contriner_client:new_raw(key)
	return t[key]
end})

local function close_fd(fd)
	if fd <= 0 then return end
	local agent = g_fd_agent_map[fd]
	if not agent then
		log.info("close_fd not agent ",fd)
		return
	end
	skynet.send(agent.gate, 'lua', 'kick', fd)
end

local function response(fd, session, isok, msg, sz)
	local rsp = frpcpack.packresponse(session, isok, msg, sz)
	if type(rsp) == 'table' then
		for i = 1, #rsp do
			socket.lwrite(fd, rsp[i])
		end
	else
		socket.write(fd, rsp)
	end
end

local HANDLE = {}

HANDLE[FRPC_PACK_ID.hand_shake] = function(fd, pack_id, module_name, instance_name, session_id, mod_num, msg, sz, ispart, iscall)
    local agent = g_fd_agent_map[fd]
    if not agent then
        log.warn("hand_shake fd not exists ", fd)
        return
    end
	--log.info("hand_shake :", pack_id, module_name, instance_name, session_id, mod_num, msg, sz, ispart, iscall)
	local cluster_name, cluster_svr_id = skynet.unpack(msg, sz)
    if not cluster_name or not cluster_svr_id then
        log.warn("hand_shake err not cluster_name and cluster_svr_id ", cluster_name, cluster_svr_id)
        return
    end

    local name = cluster_name .. ':' .. cluster_svr_id
	agent.login_time_out:cancel()
    agent.is_hand_shake = true
    agent.cluster_name = cluster_name
    agent.cluster_svr_id = cluster_svr_id
	agent.name = name
	
	local msg = skynet.packstring("ok")
	response(fd, session_id, true, msg)
end

local function create_handle(func)
	return function(fd, pack_id, module_name, instance_name, session_id, mod_num, msg, sz, ispart, iscall)
		local agent = g_fd_agent_map[fd]
		if not agent then
			log.warn("agent not exists ", fd)
			return
		end

		if not agent.is_hand_shake then
			log.warn("agent not hand_shake ", fd, session_id)
			return 
		end

		local cli = g_client_map[module_name]
		if not cli then
			log.warn("frpc module_name not exists ",module_name, instance_name, agent.name)
			if iscall then
				response(fd, session_id, false, " module_name not exists :" .. tostring(module_name))
			end
			return
		end

		if ispart then
			local req = agent.large_request[session_id] or {module_name = module_name, instance_name = instance_name, iscall = iscall, mod_num = mod_num}
			agent.large_request[session_id] = req
			frpcpack.append(req, msg, sz)
			return
		else
			local req = agent.large_request[session_id]
			if req then
				agent.large_request[session_id] = nil
				frpcpack.append(req, msg, sz)
				msg, sz = frpcpack.concat(req)
				module_name = req.module_name
				iscall = req.iscall
				mod_num = req.mod_num
			end

			if not msg and iscall then
				response(fd, session_id, false, "Invalid large req from " .. agent.name)
				return
			end
		end

		if not iscall then
			func(agent, module_name, instance_name, mod_num, msg, sz)
		else
			local isok, msg, sz = pcall(func, agent, module_name, instance_name, mod_num, msg, sz)
			if not isok then
				response(fd, session_id, false, "call err " .. msg)
			else
				response(fd, session_id, true, msg, sz)
			end
		end
	end
end

HANDLE[FRPC_PACK_ID.balance_send] = create_handle(function(agent, module_name, instance_name, mod_num, msg, sz)
	local cli = g_client_map[module_name]
	cli:balance_send(msg, sz)
end)

HANDLE[FRPC_PACK_ID.mod_send] = create_handle(function(agent, module_name, instance_name, mod_num, msg, sz)
	local cli = g_client_map[module_name]
	cli:set_mod_num(mod_num)
	cli:mod_send(msg, sz)
end)

HANDLE[FRPC_PACK_ID.broadcast] = create_handle(function(agent, module_name, instance_name, mod_num, msg, sz)
	local msgstr = skynet.tostring(msg, sz)	--由于需要发给多个服务，每个服务再消费完消息后会释放c的数据指针，所有这里先转成lua str再发送
	skynet.trash(msg, sz)
	local cli = g_client_map[module_name]					
	cli:broadcast(msgstr)
end)

HANDLE[FRPC_PACK_ID.balance_send_by_name] = create_handle(function(agent, module_name, instance_name, mod_num, msg, sz)
	local cli = g_client_map[module_name]
	cli:set_instance_name(instance_name)
	cli:balance_send_by_name(msg, sz)
end)

HANDLE[FRPC_PACK_ID.mod_send_by_name] = create_handle(function(agent, module_name, instance_name, mod_num, msg, sz)
	local cli = g_client_map[module_name]
	cli:set_instance_name(instance_name)
	cli:set_mod_num(mod_num)
	cli:mod_send_by_name(msg, sz)
end)

HANDLE[FRPC_PACK_ID.broadcast_by_name] = create_handle(function(agent, module_name, instance_name, mod_num, msg, sz)
	local msgstr = skynet.tostring(msg, sz)	--由于需要发给多个服务，每个服务再消费完消息后会释放c的数据指针，所有这里先转成lua str再发送
	skynet.trash(msg, sz)
	local cli = g_client_map[module_name]
	cli:set_instance_name(instance_name)
	cli:broadcast_by_name(msgstr)
end)

HANDLE[FRPC_PACK_ID.balance_call] = create_handle(function(agent, module_name, instance_name, mod_num, msg, sz)
	local cli = g_client_map[module_name]
	return cli:balance_call(msg, sz)
end)

HANDLE[FRPC_PACK_ID.mod_call] = create_handle(function(agent, module_name, instance_name, mod_num, msg, sz)
	local cli = g_client_map[module_name]
	cli:set_mod_num(mod_num)
	return cli:mod_call(msg, sz)
end)

HANDLE[FRPC_PACK_ID.broadcast_call] = create_handle(function(agent, module_name, instance_name, mod_num, msg, sz)
	local msgstr = skynet.tostring(msg, sz)	--由于需要发给多个服务，每个服务再消费完消息后会释放c的数据指针，所有这里先转成lua str再发送
	skynet.trash(msg, sz)
	local cli = g_client_map[module_name]
	return skynet.packstring(cli:broadcast_call(msgstr))
end)

HANDLE[FRPC_PACK_ID.balance_call_by_name] = create_handle(function(agent, module_name, instance_name, mod_num, msg, sz)
	local cli = g_client_map[module_name]
	cli:set_instance_name(instance_name)
	return cli:balance_call_by_name(msg, sz)
end)

HANDLE[FRPC_PACK_ID.mod_call_by_name] = create_handle(function(agent, module_name, instance_name, mod_num, msg, sz)
	local cli = g_client_map[module_name]
	cli:set_instance_name(instance_name)
	cli:set_mod_num(mod_num)
	return cli:mod_call_by_name(msg, sz)
end)

HANDLE[FRPC_PACK_ID.broadcast_call_by_name] = create_handle(function(agent, module_name, instance_name, mod_num, msg, sz)
	local msgstr = skynet.tostring(msg, sz)	--由于需要发给多个服务，每个服务再消费完消息后会释放c的数据指针，所有这里先转成lua str再发送
	skynet.trash(msg, sz)
	local cli = g_client_map[module_name]
	cli:set_instance_name(instance_name)
	return skynet.packstring(cli:broadcast_call_by_name(msgstr))
end)

local function handle_dispatch(fd, pack_id, module_name, instance_name, session_id, mod_num, msg, sz, ispart, iscall)
    local func = HANDLE[pack_id]
    if not func then
        log.error("unknown pack_id ", pack_id)
        return
    end
    func(fd, pack_id, module_name, instance_name, session_id, mod_num, msg, sz, ispart, iscall)
end

local CMD = {}

local SOCKET = {}

--ws_gate会传入gate
function SOCKET.open(fd, addr, gate)
	gate = gate or g_gate
	--先设置转发，成功后再建立连接管理映射，不然存在建立连接，客户端立马断开的情况，掉线无法通知到此服务
	if not skynet.call(gate,'lua','forward',fd) then --设置转发不成功，此处会断言，以下就不会执行了，就当它没有来连接过
		return
	end
	
	local agent = {
		fd = fd,
		addr = addr,
		gate = gate,
		login_time_out = timer:new(timer.second * 10, 1, close_fd, fd),
        is_hand_shake = nil,                                            --是否握手了
        cluster_name  = nil,                                            --连接的集群服务名
        cluster_svr_id = nil,                                           --连接的集群服务ID

		large_request = {},
	}
	g_fd_agent_map[fd] = agent
end

function SOCKET.close(fd)
    local agent = g_fd_agent_map[fd]
	if not agent then
		log.warn("close not agent ",fd)
		return
	end
	agent.fd = 0
	g_fd_agent_map[fd] = nil
	agent.login_time_out:cancel()
end

function SOCKET.data(fd, msg)
	log.info('SOCKET.data:',fd, msg)
end

function CMD.socket(cmd,...)
	assert(SOCKET[cmd],'not cmd '.. cmd)
	local f = SOCKET[cmd]
	f(...)
end

contriner_client:CMD(CMD)

skynet.start(function()
	skynet_util.lua_dispatch(CMD)

	local confclient = contriner_client:new("share_config_m")
	local conf = confclient:mod_call('query','frpc_server')
	assert(conf.host,"not host")
	
	local register = conf.register
	if register == 'redis' then --注册到redis
		local rpccli = rpc_redis:new()
		--一秒写一次
		local timer_obj = timer:new(timer.second * 5,timer.loop,function()
			rpccli:register(g_svr_name,g_svr_id,conf.host)
		end)
		timer_obj:after_next()
	end

    skynet.register_protocol {
		id = skynet.PTYPE_CLIENT,
		name = "client",
		unpack = frpcpack.unpackrequest,
		dispatch = function(fd,source,...)
			skynet.ignoreret()
			handle_dispatch(fd, ...)
		end,
	}
	g_gate = skynet.newservice("gate")
	skynet.call(g_gate,'lua','open',conf.gateconf)
end)