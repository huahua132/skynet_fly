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
local crypt = require "skynet.crypt"

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

local g_secret_key = nil						    --连接密钥
local g_is_encrypt = nil 							--是否加密传输

contriner_client:register("share_config_m")

local g_client_map = setmetatable({},{__index = function(t,key)
	t[key] = contriner_client:new_raw(key)
	return t[key]
end})

local function close_fd(fd)
	if fd <= 0 then return end
	local agent = g_fd_agent_map[fd]
	if not agent then
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

local function hand_shake(fd, session_id, msg, sz)
	local msgbuff = skynet.tostring(msg, sz)
	skynet.trash(msg, sz)

	local agent = g_fd_agent_map[fd]
    if not agent then
        log.warn("hand_shake fd not exists ", fd)
        return
    end

	local info = nil
	if agent.is_challenge_ok and agent.msg_secret then
		info = crypt.desdecode(agent.msg_secret, msgbuff)
		info = skynet.unpack(info)
	else
		info = skynet.unpack(msgbuff)
	end
	if (g_secret_key or g_is_encrypt) and not agent.is_challenge_ok then			--交换密钥
		local step = info.step
		if step == 1 then									--stop 1 S2C 8bytes random challenge
			local challenge = crypt.randomkey()
			agent.challenge = challenge

			local c = crypt.base64encode(challenge)
			response(fd, session_id, true, skynet.packstring(c))
		elseif step == 2 then								--交换公钥
			local client_key = info.client_key
			if not client_key then
				log.warn("hand_shake err not client_key", fd, session_id)
				return
			end

			client_key = crypt.base64decode(client_key)
			if #client_key ~= 8 then
				log.warn("hand_shake err client_key len ", fd, session_id, #client_key)
				return
			end

			agent.client_key = client_key

			local server_key = crypt.randomkey()
			agent.msg_secret = crypt.dhsecret(client_key, server_key)
			response(fd, session_id, true, skynet.packstring(crypt.base64encode(crypt.dhexchange(server_key))))
		elseif step == 3 then
			local challenge = info.challenge
			if not challenge then
				log.warn("hand_shake err not challenge", fd, session_id)
				return
			end

			local hmac = crypt.hmac64(agent.challenge, agent.msg_secret)
			if hmac ~= challenge then
				log.warn("hand_shake err challenge", fd, session_id)
				return
			end

			response(fd, session_id, true, skynet.packstring("ok"))
			agent.is_challenge_ok = true
		else
			log.warn("hand_shake unknown step ", step)
		end
		return
	end
	
	local cluster_name, cluster_svr_id = info.cluster_name, info.cluster_svr_id
    if not cluster_name or not cluster_svr_id then
        log.warn("hand_shake err not cluster_name and cluster_svr_id ", cluster_name, cluster_svr_id, agent.addr, fd)
        return
    end

	--检查密钥
	if g_secret_key	then
		local secret_key = info.secret_key
		if not secret_key or secret_key ~= g_secret_key then
			log.warn("hand_shake err secret_key err ", cluster_name, cluster_svr_id, agent.addr, fd)
			response(fd, session_id, true, skynet.packstring("secret_key err"))
			return
		end
	end

    local name = cluster_name .. ':' .. cluster_svr_id
	agent.login_time_out:cancel()
    agent.is_hand_shake = true
    agent.cluster_name = cluster_name
    agent.cluster_svr_id = cluster_svr_id
	agent.name = name
	
	response(fd, session_id, true, skynet.packstring("ok"))
end

local function create_handle(func)
	return function(fd, module_name, instance_name, session_id, mod_num, msg, sz, iscall)
		local agent = g_fd_agent_map[fd]
		if not agent then
			skynet.trash(msg, sz)
			log.warn("agent not exists ", fd)
			return
		end
		local cli = g_client_map[module_name]
		if not cli then
			skynet.trash(msg, sz)
			log.warn("frpc module_name not exists ",module_name, instance_name, agent.name)
			if iscall then
				response(fd, session_id, false, " module_name not exists :" .. tostring(module_name))
			end
			return
		end
		if not iscall then
			func(agent, module_name, instance_name, mod_num, msg, sz)
		else
			local isok, msg, sz = pcall(func, agent, module_name, instance_name, mod_num, msg, sz)
			if not isok then
				response(fd, session_id, false, "call err " .. msg)
			else
				if g_is_encrypt then
					if type(msg) == 'userdata' then
						msg = skynet.tostring(msg, sz)
					end
					msg = crypt.desencode(agent.msg_secret, msg) --加密回复消息
					sz = nil
				end
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
	local msgstr = msg
	if type(msg) == 'userdata' then
		msgstr = skynet.tostring(msg, sz)	--由于需要发给多个服务，每个服务再消费完消息后会释放c的数据指针，所有这里先转成lua str再发送
		skynet.trash(msg, sz)
	end
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
	local msgstr = msg
	if type(msg) == 'userdata' then
		msgstr = skynet.tostring(msg, sz)	--由于需要发给多个服务，每个服务再消费完消息后会释放c的数据指针，所有这里先转成lua str再发送
		skynet.trash(msg, sz)
	end
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
	local msgstr = msg
	if type(msg) == 'userdata' then
		msgstr = skynet.tostring(msg, sz)	--由于需要发给多个服务，每个服务再消费完消息后会释放c的数据指针，所有这里先转成lua str再发送
		skynet.trash(msg, sz)
	end
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
	local msgstr = msg
	if type(msg) == 'userdata' then
		msgstr = skynet.tostring(msg, sz)	--由于需要发给多个服务，每个服务再消费完消息后会释放c的数据指针，所有这里先转成lua str再发送
		skynet.trash(msg, sz)
	end
	local cli = g_client_map[module_name]
	cli:set_instance_name(instance_name)
	return skynet.packstring(cli:broadcast_call_by_name(msgstr))
end)

local function handle_dispatch(fd, pack_id, module_name, instance_name, session_id, mod_num, msg, sz, ispart, iscall)
	local agent = g_fd_agent_map[fd]
	if not agent then
		skynet.trash(msg, sz)
		log.warn("agent not exists ", fd)
		return
	end

	if not agent.is_hand_shake then
		if pack_id ~= FRPC_PACK_ID.hand_shake then
			skynet.trash(msg, sz)
			log.warn("agent not hand_shake ", fd, session_id)
		else
			hand_shake(fd, session_id, msg, sz)
		end
		return
	end

	if ispart then
		local req = agent.large_request[session_id] or {module_name = module_name, instance_name = instance_name, iscall = iscall, mod_num = mod_num, pack_id = pack_id}
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
			instance_name = req.instance_name
			iscall = req.iscall
			mod_num = req.mod_num
			pack_id = req.pack_id
		end

		if not msg and iscall then
			response(fd, session_id, false, "Invalid large req from " .. agent.name)
			return
		end
	end

    local func = HANDLE[pack_id]
    if not func then
		skynet.trash(msg, sz)
        log.error("unknown pack_id ", pack_id, agent.name)
		if iscall then
			response(fd, session_id, false, "unknown pack_id = " .. pack_id .. ' name = ' .. agent.name)
		end
        return
    end

	if g_is_encrypt then
		local info = skynet.tostring(msg, sz)
		skynet.trash(msg, sz)
		local isok
		isok, msg = pcall(crypt.desdecode, agent.msg_secret, info)
		if not isok then
			log.error("desdecode err ", agent.name)
			if iscall then
				response(fd, session_id, false, "desdecode err name = " .. agent.name)
				return
			end
		end
	end
    func(fd, module_name, instance_name, session_id, mod_num, msg, sz, iscall)
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

function SOCKET.error(fd, msg)
	log.info("socket error:", fd, msg)
	close_fd(fd)
end

function SOCKET.warning(fd, size)
	-- size K bytes havn't send out in fd
	log.info("socket warning", fd, size)
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

	g_secret_key = conf.secret_key
	g_is_encrypt = conf.is_encrypt
	
	local register = conf.register
	if register == 'redis' then --注册到redis
		local rpccli = rpc_redis:new()
		rpccli:register(g_svr_name, g_svr_id, conf.host, g_secret_key, g_is_encrypt)
		--1秒写一次
		timer:new(timer.second,timer.loop,function()
			rpccli:register(g_svr_name, g_svr_id, conf.host, g_secret_key, g_is_encrypt)
		end):after_next()
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