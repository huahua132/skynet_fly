local skynet = require "skynet"
local contriner_client = require "skynet-fly.client.contriner_client"
local rpc_redis = require "skynet-fly.rpc.rpc_redis"
local log = require "skynet-fly.log"
local timer = require "skynet-fly.timer"
local skynet_util = require "skynet-fly.utils.skynet_util"
local frpcnet_byid = require "skynet-fly.utils.net.frpcnet_byid"
local FRPC_PACK_ID = require "skynet-fly.enum.FRPC_PACK_ID"
local env_util = require "skynet-fly.utils.env_util"

local pairs = pairs
local assert = assert
local tonumber = tonumber
local setmetatable = setmetatable
local type = type
local string = string
local pcall = pcall
local tremove = table.remove

local g_gate = nil
local g_svr_name = env_util.get_svr_name()
local g_svr_id = env_util.get_svr_id()
local g_fd_agent_map = {}                           --fd 连接管理
local g_cluster_map = {}                            --集群映射

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

local function send_msg(fd, req_packbody, pack_id, lua_msgs)
	if type(lua_msgs) == 'table' then
		lua_msgs = skynet.packstring(lua_msgs)
	end

	local packbody = {
		module_name = req_packbody.module_name,
		session_id = req_packbody.session_id,
		mod_num = req_packbody.mod_num,
		lua_msgs = lua_msgs,
	}
	
	frpcnet_byid.send(g_gate, fd, pack_id, packbody)
end

local HANDLE = {}

HANDLE[FRPC_PACK_ID.hand_shake] = function(fd, packbody)
    local agent = g_fd_agent_map[fd]
    if not agent then
        log.warn("hand_shake fd not exists ", fd)
        return
    end

	local lua_msgs = skynet.unpack(packbody.lua_msgs)
    local cluster_name = lua_msgs[1]
    local cluster_svr_id = lua_msgs[2]
    if not cluster_name or not cluster_svr_id then
        log.warn("hand_shake err not cluster_name and cluster_svr_id ", cluster_name, cluster_svr_id)
        return
    end

    local name = cluster_name .. ':' .. cluster_svr_id
    if g_cluster_map[name] then
        log.warn("hand_shake err is exists cluster connect ", name)
		send_msg(fd, packbody, FRPC_PACK_ID.hand_shake_rsp, {"exists"})
        return
    end

    g_cluster_map[name] = agent
    agent.is_hand_shake = true
    agent.cluster_name = cluster_name
    agent.cluster_svr_id = cluster_svr_id
	agent.name = name
	
	send_msg(fd, packbody, FRPC_PACK_ID.hand_shake_rsp, {"ok"})
end

local function create_handle(func, is_need_rsp)
	return function(fd, packbody)
		local agent = g_fd_agent_map[fd]
		if not agent then
			log.warn("agent not exists ", fd)
			return
		end

		if not agent.is_hand_shake then
			log.warn("agent not hand_shake ", fd)
			send_msg(fd, packbody, FRPC_PACK_ID.call_error, {"not hand_shake"})
			return 
		end

		local module_name = packbody.module_name
		local cli = g_client_map[module_name]
		if not cli then
			log.warn("frpc module_name not exists ",module_name, agent.name)
			send_msg(fd, packbody, FRPC_PACK_ID.call_error, {"module_name not exists"})
			return
		end

		if not is_need_rsp then
			func(fd, packbody)
		else

			local isok, msg, sz = pcall(func, fd, packbody)
			local lua_msgs = skynet.tostring(msg, sz)
			if not isok then
				send_msg(fd, packbody, FRPC_PACK_ID.call_error, lua_msgs)
			else
				send_msg(fd, packbody, FRPC_PACK_ID.call_rsp, lua_msgs)
			end
		end
	end
end

HANDLE[FRPC_PACK_ID.balance_send] = create_handle(function(agent, packbody)
	local module_name = packbody.module_name
	local cli = g_client_map[module_name]
	cli:balance_send(packbody.lua_msgs)
end)

HANDLE[FRPC_PACK_ID.mod_send] = create_handle(function(agent, packbody)
	local module_name = packbody.module_name
	local mod_num = packbody.mod_num
	local cli = g_client_map[module_name]
	cli:set_mod_num(mod_num)
	cli:mod_send(packbody.lua_msgs)
end)

HANDLE[FRPC_PACK_ID.broadcast] = create_handle(function(agent, packbody)
	local module_name = packbody.module_name
	local cli = g_client_map[module_name]
	cli:broadcast(packbody.lua_msgs)
end)

HANDLE[FRPC_PACK_ID.balance_send_by_name] = create_handle(function(agent, packbody)
	local module_name = packbody.module_name
	local cli = g_client_map[module_name]
	cli:balance_send_by_name(packbody.lua_msgs)
end)

HANDLE[FRPC_PACK_ID.mod_send_by_name] = create_handle(function(agent, packbody)
	local module_name = packbody.module_name
	local mod_num = packbody.mod_num
	local cli = g_client_map[module_name]
	cli:set_mod_num(mod_num)
	cli:mod_send_by_name(packbody.lua_msgs)
end)

HANDLE[FRPC_PACK_ID.broadcast_by_name] = create_handle(function(agent, packbody)
	local module_name = packbody.module_name
	local cli = g_client_map[module_name]
	cli:broadcast_by_name(packbody.lua_msgs)
end)

HANDLE[FRPC_PACK_ID.balance_call] = create_handle(function(agent, packbody)
	local module_name = packbody.module_name
	local cli = g_client_map[module_name]
	return cli:balance_call(packbody.lua_msgs)
end, true)

HANDLE[FRPC_PACK_ID.mod_call] = create_handle(function(agent, packbody)
	local module_name = packbody.module_name
	local mod_num = packbody.mod_num
	local cli = g_client_map[module_name]
	cli:set_mod_num(mod_num)
	return cli:mod_call(packbody.lua_msgs)
end, true)

HANDLE[FRPC_PACK_ID.broadcast_call] = create_handle(function(agent, packbody)
	local module_name = packbody.module_name
	local cli = g_client_map[module_name]
	return cli:broadcast_call(packbody.lua_msgs)
end, true)

HANDLE[FRPC_PACK_ID.balance_call_by_name] = create_handle(function(agent, packbody)
	local module_name = packbody.module_name
	local cli = g_client_map[module_name]
	return cli:balance_call_by_name(packbody.lua_msgs)
end, true)

HANDLE[FRPC_PACK_ID.mod_call_by_name] = create_handle(function(agent, packbody)
	local module_name = packbody.module_name
	local mod_num = packbody.mod_num
	local cli = g_client_map[module_name]
	cli:set_mod_num(mod_num)
	return cli:mod_call_by_name(packbody.lua_msgs)
end, true)

HANDLE[FRPC_PACK_ID.broadcast_call_by_name] = create_handle(function(agent, packbody)
	local module_name = packbody.module_name
	local cli = g_client_map[module_name]
	return cli:broadcast_call_by_name(packbody.lua_msgs)
end, true)

local function handle_dispatch(fd, pack_id, packbody)
    local func = HANDLE[pack_id]
    if not func then
        log.error("unknown pack_id ", pack_id)
        return
    end
    func(fd, packbody)
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
    if agent.name then
        g_cluster_map[agent.name] = nil
    end
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
		unpack = frpcnet_byid.unpack,
		dispatch = function(fd,source,...)
			skynet.ignoreret()
			handle_dispatch(fd, ...)
		end,
	}
	g_gate = skynet.newservice("gate")
	skynet.call(g_gate,'lua','open',conf.gateconf)
end)