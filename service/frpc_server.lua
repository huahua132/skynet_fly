local skynet = require "skynet.manager"
local container_client = require "skynet-fly.client.container_client"
local rpc_redis = require "skynet-fly.rpc.rpc_redis"
local log = require "skynet-fly.log"
local timer = require "skynet-fly.timer"
local skynet_util = require "skynet-fly.utils.skynet_util"
local FRPC_PACK_ID = require "skynet-fly.enum.FRPC_PACK_ID"
local env_util = require "skynet-fly.utils.env_util"
local frpcpack = require "frpcpack.core"
local socket = require "skynet.socket"
local crypt = require "skynet.crypt"
local math_util = require "skynet-fly.utils.math_util"
local string_util = require "skynet-fly.utils.string_util"
local table_util = require "skynet-fly.utils.table_util"
local watch_syn_table = require "skynet-fly.watch.watch_syn_table"

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
local next = next

local g_gate = nil
local g_svr_name = env_util.get_svr_name()
local g_svr_id = env_util.get_svr_id()
local g_fd_agent_map = {}                           --fd 连接管理

local g_secret_key = nil						    --连接密钥
local g_is_encrypt = nil 							--是否加密传输
local g_session_id = 0
local UINIT32MAX = math_util.uint32max

local g_sub_map = {}								--订阅表
local g_sub_cnt_syn_table = watch_syn_table.new_server("frpc_server.sub_cnt_syn_table")
local g_subsyn_map = {}								--订阅同步表
local g_subsyn_channel_info_map = {}				--订阅同步表的数据
local g_subsyn_parsed_map = {}						--订阅同步已经解析过的channel_name
local g_psubsyn_map = {}							--批订阅同步表
local g_psubsyn_channel_info_map = {}				--批订阅同步表的数据

container_client:register("share_config_m")

local g_client_map = setmetatable({},{__index = function(t,key)
	t[key] = container_client:new_raw(key)
	return t[key]
end})

local function new_session_id()
	if g_session_id >= UINIT32MAX then
		g_session_id = 0
	end
	g_session_id = g_session_id + 1
	return g_session_id
end

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

local function pub_message(agent_map, channel_name, pack_id, msg, sz)
	local session = new_session_id()
	local pubmsg = nil
	for agent,_ in pairs(agent_map) do
		local fd = agent.fd
		local sendmsg = nil 
		if g_is_encrypt then
			local luamsg = msg
			if type(luamsg) == 'userdata' then
				luamsg = skynet.tostring(msg, sz)
			end
			luamsg = crypt.desencode(agent.msg_secret, luamsg) --加密回复消息
			sendmsg = frpcpack.packpubmessage(channel_name, luamsg, nil, pack_id, session)
		else
			if not pubmsg then
				pubmsg = frpcpack.packpubmessage(channel_name, msg, sz, pack_id, session)
			end
			sendmsg = pubmsg
		end
		if type(sendmsg) == 'table' then
			for i = 1, #sendmsg do
				socket.lwrite(fd, sendmsg[i])
			end
		else
			socket.lwrite(fd, sendmsg)			--都用lwrite 避免 消息穿插 pub_message 没有用session来标识消息
		end
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
	
	local svr_name, svr_id = info.svr_name, info.svr_id
    if not svr_name or not svr_id then
        log.warn("hand_shake err not svr_name and svr_id ", svr_name, svr_id, agent.addr, fd)
        return
    end

	--检查密钥
	if g_secret_key	then
		local secret_key = info.secret_key
		if not secret_key or secret_key ~= g_secret_key then
			log.warn("hand_shake err secret_key err ", svr_name, svr_id, agent.addr, fd)
			response(fd, session_id, true, skynet.packstring("secret_key err"))
			return
		end
	end

	local is_watch = info.is_watch

    local cluster_name = svr_name .. ':' .. svr_id
	agent.login_time_out:cancel()
    agent.is_hand_shake = true
    agent.svr_name = svr_name
    agent.svr_id = svr_id
	agent.cluster_name = cluster_name
	agent.is_watch = is_watch								--是否是订阅连接
	if is_watch then
		agent.sub_map = {}									--订阅列表
		agent.subsyn_map = {}								--订阅同步列表
		agent.psubsyn_map = {}								--批订阅同步列表
	end
	
	response(fd, session_id, true, skynet.packstring("ok"))

	log.info("connected from " .. cluster_name .. ' addr ' .. agent.addr .. ' is_watch ' .. tostring(is_watch))
end

local function get_module_cli(module_name, instance_name)
	local cli = g_client_map[module_name]
	if instance_name then
		cli:set_instance_name(instance_name)
	end
	return cli
end

local function create_handle(func, is_check_module_name, is_check_instance_name)
	return function(fd, module_name, instance_name, session_id, mod_num, msg, sz, iscall)
		local agent = g_fd_agent_map[fd]
		if not agent then
			skynet.trash(msg, sz)
			log.warn("agent not exists ", fd)
			return
		end
		local isok = true
		local err 
		if is_check_module_name and is_check_instance_name then
			isok, err = pcall(get_module_cli, module_name, instance_name)
		elseif is_check_module_name then
			isok, err = pcall(get_module_cli, module_name)
		end
		if not isok then
			skynet.trash(msg, sz)
			log.warn("frpc module_name not exists ",module_name, instance_name, agent.cluster_name, err)
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
end, true)

HANDLE[FRPC_PACK_ID.mod_send] = create_handle(function(agent, module_name, instance_name, mod_num, msg, sz)
	local cli = g_client_map[module_name]
	cli:set_mod_num(mod_num)
	cli:mod_send(msg, sz)
end, true)

HANDLE[FRPC_PACK_ID.broadcast] = create_handle(function(agent, module_name, instance_name, mod_num, msg, sz)
	local msgstr = msg
	if type(msg) == 'userdata' then
		msgstr = skynet.tostring(msg, sz)	--由于需要发给多个服务，每个服务再消费完消息后会释放c的数据指针，所有这里先转成lua str再发送
		skynet.trash(msg, sz)
	end
	local cli = g_client_map[module_name]					
	cli:broadcast(msgstr)
end, true)

HANDLE[FRPC_PACK_ID.balance_send_by_name] = create_handle(function(agent, module_name, instance_name, mod_num, msg, sz)
	local cli = g_client_map[module_name]
	cli:set_instance_name(instance_name)
	cli:balance_send_by_name(msg, sz)
end, true, true)

HANDLE[FRPC_PACK_ID.mod_send_by_name] = create_handle(function(agent, module_name, instance_name, mod_num, msg, sz)
	local cli = g_client_map[module_name]
	cli:set_instance_name(instance_name)
	cli:set_mod_num(mod_num)
	cli:mod_send_by_name(msg, sz)
end, true, true)

HANDLE[FRPC_PACK_ID.broadcast_by_name] = create_handle(function(agent, module_name, instance_name, mod_num, msg, sz)
	local msgstr = msg
	if type(msg) == 'userdata' then
		msgstr = skynet.tostring(msg, sz)	--由于需要发给多个服务，每个服务再消费完消息后会释放c的数据指针，所有这里先转成lua str再发送
		skynet.trash(msg, sz)
	end
	local cli = g_client_map[module_name]
	cli:set_instance_name(instance_name)
	cli:broadcast_by_name(msgstr)
end, true)

HANDLE[FRPC_PACK_ID.balance_call] = create_handle(function(agent, module_name, instance_name, mod_num, msg, sz)
	local cli = g_client_map[module_name]
	return cli:balance_call(msg, sz)
end, true)

HANDLE[FRPC_PACK_ID.mod_call] = create_handle(function(agent, module_name, instance_name, mod_num, msg, sz)
	local cli = g_client_map[module_name]
	cli:set_mod_num(mod_num)
	return cli:mod_call(msg, sz)
end, true)

HANDLE[FRPC_PACK_ID.broadcast_call] = create_handle(function(agent, module_name, instance_name, mod_num, msg, sz)
	local msgstr = msg
	if type(msg) == 'userdata' then
		msgstr = skynet.tostring(msg, sz)	--由于需要发给多个服务，每个服务再消费完消息后会释放c的数据指针，所以这里先转成lua str再发送
		skynet.trash(msg, sz)
	end
	local cli = g_client_map[module_name]
	return skynet.packstring(cli:broadcast_call(msgstr))
end, true)

HANDLE[FRPC_PACK_ID.balance_call_by_name] = create_handle(function(agent, module_name, instance_name, mod_num, msg, sz)
	local cli = g_client_map[module_name]
	cli:set_instance_name(instance_name)
	return cli:balance_call_by_name(msg, sz)
end, true, true)

HANDLE[FRPC_PACK_ID.mod_call_by_name] = create_handle(function(agent, module_name, instance_name, mod_num, msg, sz)
	local cli = g_client_map[module_name]
	cli:set_instance_name(instance_name)
	cli:set_mod_num(mod_num)
	return cli:mod_call_by_name(msg, sz)
end, true, true)

HANDLE[FRPC_PACK_ID.broadcast_call_by_name] = create_handle(function(agent, module_name, instance_name, mod_num, msg, sz)
	local msgstr = msg
	if type(msg) == 'userdata' then
		msgstr = skynet.tostring(msg, sz)	--由于需要发给多个服务，每个服务再消费完消息后会释放c的数据指针，所以这里先转成lua str再发送
		skynet.trash(msg, sz)
	end
	local cli = g_client_map[module_name]
	cli:set_instance_name(instance_name)
	return skynet.packstring(cli:broadcast_call_by_name(msgstr))
end, true, true)

--用skynet别名的方式
HANDLE[FRPC_PACK_ID.send_by_alias] = create_handle(function(agent, module_name, instance_name, mod_num, msg, sz)
	skynet.rawsend(module_name, 'lua', msg, sz)
end)

HANDLE[FRPC_PACK_ID.call_by_alias] = create_handle(function(agent, module_name, instance_name, mod_num, msg, sz)
	return skynet.rawcall(module_name, 'lua', msg, sz)
end)

--订阅
HANDLE[FRPC_PACK_ID.sub] = create_handle(function(agent, module_name, instance_name, mod_num, msg, sz)
	local channel_name, address, unique_name = skynet.unpack(msg, sz)	--订阅渠道名
	skynet.trash(msg, sz)
	if not agent.is_watch then
		log.warn("drop message not watch conn sub", agent.fd, agent.addr)
		return
	end

	local sub_map = agent.sub_map
	sub_map[channel_name] = true
	
	if not g_sub_map[channel_name] then
		g_sub_map[channel_name] = {}
	end

	g_sub_map[channel_name][agent] = true
	local v = g_sub_cnt_syn_table:get(channel_name) or 0
	v = v + 1
	g_sub_cnt_syn_table:set(channel_name, v)
	
	pub_message({[agent] = true}, channel_name, FRPC_PACK_ID.sub, skynet.packstring(address, unique_name))
end)

--取消订阅
HANDLE[FRPC_PACK_ID.unsub] = create_handle(function(agent, module_name, instance_name, mod_num, msg, sz)
	local channel_name, address, unique_name = skynet.unpack(msg, sz)	--订阅渠道名
	skynet.trash(msg, sz)
	if not agent.is_watch then
		log.warn("drop message not watch conn unsub", agent.fd, agent.addr)
		return
	end

	local sub_map = agent.sub_map
	sub_map[channel_name] = nil
	if g_sub_map[channel_name] then
		g_sub_map[channel_name][agent] = nil
		local v = g_sub_cnt_syn_table:get(channel_name) or 0
		v = v - 1
		g_sub_cnt_syn_table:set(channel_name, v)
		if not next(g_sub_map[channel_name]) then
			g_sub_map[channel_name] = nil
			g_sub_cnt_syn_table:del(channel_name)
		end
	end

	pub_message({[agent] = true}, channel_name, FRPC_PACK_ID.unsub, skynet.packstring(address, unique_name))
end)

--订阅同步
HANDLE[FRPC_PACK_ID.subsyn] = create_handle(function(agent, module_name, instance_name, mod_num, msg, sz)
	local channel_name, version = skynet.unpack(msg, sz)	--订阅渠道名
	skynet.trash(msg, sz)
	if not agent.is_watch then
		log.warn("drop message not watch conn subsyn", agent.fd, agent.addr)
		return
	end

	local channel_name_info = g_subsyn_channel_info_map[channel_name]
	if not channel_name_info or channel_name_info.version == version then
		local subsyn_map = agent.subsyn_map
		subsyn_map[channel_name] = true
		if not g_subsyn_map[channel_name] then
			g_subsyn_map[channel_name] = {}
		end
		g_subsyn_map[channel_name][agent] = version
	else
		--不同直接同步
		local luamsg = channel_name_info.luamsg
		pub_message({[agent] = true}, channel_name, FRPC_PACK_ID.subsyn, skynet.packstring(channel_name_info.version, luamsg))
	end
end)

--取消订阅同步
HANDLE[FRPC_PACK_ID.unsubsyn] = create_handle(function(agent, module_name, instance_name, mod_num, msg, sz)
	local channel_name = skynet.unpack(msg, sz)	--订阅渠道名
	skynet.trash(msg, sz)
	if not agent.is_watch then
		log.warn("drop message not watch conn unsubsyn", agent.fd, agent.addr)
		return
	end

	local subsyn_map = agent.subsyn_map
	subsyn_map[channel_name] = nil

	if g_subsyn_map[channel_name] then
		g_subsyn_map[channel_name][agent] = nil
		if not next(g_subsyn_map[channel_name]) then
			g_subsyn_map[channel_name] = nil
		end
	end
end)

--批订阅同步
HANDLE[FRPC_PACK_ID.psubsyn] = create_handle(function(agent, module_name, instance_name, mod_num, msg, sz)
	local pchannel_name, version = skynet.unpack(msg, sz)	--订阅渠道名
	skynet.trash(msg, sz)
	if not agent.is_watch then
		log.warn("drop message not watch conn psubsyn", agent.fd, agent.addr)
		return
	end
	
	local pchannel_name_info = g_psubsyn_channel_info_map[pchannel_name]
	if not pchannel_name_info or pchannel_name_info.version == version then
		local psubsyn_map = agent.psubsyn_map
		psubsyn_map[pchannel_name] = true
		if not g_psubsyn_map[pchannel_name] then
			g_psubsyn_map[pchannel_name] = {}
		end
		g_psubsyn_map[pchannel_name][agent] = version
	else
		--不同直接同步
		local name_map = pchannel_name_info.name_map
		pub_message({[agent] = true}, pchannel_name, FRPC_PACK_ID.psubsyn, skynet.packstring(pchannel_name_info.version, name_map))
	end
end)

--取消批订阅同步
HANDLE[FRPC_PACK_ID.unpsubsyn] = create_handle(function(agent, module_name, instance_name, mod_num, msg, sz)
	local pchannel_name = skynet.unpack(msg, sz)	--订阅渠道名
	skynet.trash(msg, sz)
	if not agent.is_watch then
		log.warn("drop message not watch conn unpsubsyn", agent.fd, agent.addr)
		return
	end

	local psubsyn_map = agent.psubsyn_map
	psubsyn_map[pchannel_name] = nil

	if g_psubsyn_map[pchannel_name] then
		g_psubsyn_map[pchannel_name][agent] = nil
		if not next(g_psubsyn_map[pchannel_name]) then
			g_psubsyn_map[pchannel_name] = nil
		end
	end
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
			response(fd, session_id, false, "Invalid large req from " .. agent.cluster_name)
			return
		end
	end

    local func = HANDLE[pack_id]
    if not func then
		skynet.trash(msg, sz)
        log.error("unknown pack_id ", pack_id, agent.cluster_name)
		if iscall then
			response(fd, session_id, false, "unknown pack_id = " .. pack_id .. ' cluster_name = ' .. agent.cluster_name)
		end
        return
    end

	if g_is_encrypt then
		local info = skynet.tostring(msg, sz)
		skynet.trash(msg, sz)
		local isok
		isok, msg = pcall(crypt.desdecode, agent.msg_secret, info)
		if not isok then
			log.error("desdecode err ", agent.cluster_name)
			if iscall then
				response(fd, session_id, false, "desdecode err cluster_name = " .. agent.cluster_name)
				return
			end
		end
	end
    func(fd, module_name, instance_name, session_id, mod_num, msg, sz, iscall)
end

local function set_syn_pchannel_name(channel_name)
	local split_str = string_util.split(channel_name, ':')
	local len = #split_str - 1
	if len <= 0 then return end

	if g_subsyn_parsed_map[channel_name] then return end
	g_subsyn_parsed_map[channel_name] = true
	local indexs = {}
	for i = 1, #split_str do
		indexs[i] = i
	end
	local l_len = #split_str
	for i = 1, len do
		for idxs in table_util.combinations_pairs(indexs, i) do
			local p_channel_name = ""
			local k = 1
			for j = 1, l_len do
				if idxs[k] == j then
					p_channel_name = p_channel_name .. '*:'
					k = k + 1
				else
					p_channel_name = p_channel_name .. split_str[j] .. ':'
				end

				if j == l_len then
					p_channel_name = p_channel_name:sub(1, #p_channel_name - 1)
				end
			end
			
			if not g_psubsyn_channel_info_map[p_channel_name] then
				g_psubsyn_channel_info_map[p_channel_name] = {version = 0, name_map = {}}
			end
			local info = g_psubsyn_channel_info_map[p_channel_name]
			info.version = info.version + 1
			info.name_map[channel_name] = true
			local agent_map = g_psubsyn_map[p_channel_name]
			if agent_map then
				local push_map = {}
				for agent, version in pairs(agent_map) do
					if info.version ~= version then
						push_map[agent] = true
						agent_map[agent] = nil
						agent.psubsyn_map[p_channel_name] = nil
					end
				end

				if next(push_map) then
					pub_message(push_map, p_channel_name, FRPC_PACK_ID.psubsyn, skynet.packstring(info.version, info.name_map))
				end
			end
		end
	end
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
        svr_name = nil,                                            		--连接的集群服务名
        svr_id = nil,                                           		--连接的集群服务ID
		cluster_name = nil,												--集群名 svr_name:svr_id 组成
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

	local sub_map = agent.sub_map
	if sub_map then
		for channel_name in pairs(sub_map) do
			g_sub_map[channel_name][agent] = nil
			local v = g_sub_cnt_syn_table:get(channel_name) or 0
			v = v - 1
			g_sub_cnt_syn_table:set(channel_name, v)
			if not next(g_sub_map[channel_name]) then
				g_sub_map[channel_name] = nil
				g_sub_cnt_syn_table:del(channel_name)
			end
		end
	end

	local subsyn_map = agent.subsyn_map
	if subsyn_map then
		for channel_name in pairs(subsyn_map) do
			g_subsyn_map[channel_name][agent] = nil
			if not next(g_subsyn_map[channel_name]) then
				g_subsyn_map[channel_name] = nil
			end
		end
	end
	
	local psubsyn_map = agent.psubsyn_map
	if psubsyn_map then
		for pchannel_name in pairs(psubsyn_map) do
			g_psubsyn_map[pchannel_name][agent] = nil
			if not next(g_psubsyn_map[pchannel_name]) then
				g_psubsyn_map[pchannel_name] = nil
			end
		end
	end
	
	log.info_fmt("disconnected %s addr %s is_watch %s", agent.cluster_name, agent.addr, agent.is_watch)
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

--推送消息
function CMD.publish(channel_name, msg, sz)
	local agent_map = g_sub_map[channel_name]
	if not agent_map then 
		skynet.trash(msg, sz)
		return
	end

	local isok, err = pcall(pub_message, agent_map, channel_name, FRPC_PACK_ID.pubmessage, msg, sz)

	skynet.trash(msg, sz)
	if not isok then
		log.warn("publish err ", channel_name, err)
	end
end

--推送同步
function CMD.pubsyn(channel_name, luamsg)
	local info = g_subsyn_channel_info_map[channel_name]
	if not info then
		g_subsyn_channel_info_map[channel_name] = {
			version = 1,
			luamsg = luamsg,
		}
		info = g_subsyn_channel_info_map[channel_name]
	else
		info = g_subsyn_channel_info_map[channel_name]
		info.luamsg = luamsg
		info.version = info.version + 1
	end
	set_syn_pchannel_name(channel_name)
	local agent_map = g_subsyn_map[channel_name]
	if not agent_map then return end
	local push_map = {}
	for agent, version in pairs(agent_map) do
		if info.version ~= version then
			push_map[agent] = true
			agent_map[agent] = nil
			agent.subsyn_map[channel_name] = nil
		end
	end

	if next(push_map) then
		pub_message(push_map, channel_name, FRPC_PACK_ID.subsyn, skynet.packstring(info.version, luamsg))
	end
end

skynet.start(function()
	skynet.register('.frpc_server')
	skynet_util.lua_dispatch(CMD)

	local confclient = container_client:new("share_config_m")
	local conf = confclient:mod_call('query','frpc_server')
	assert(conf.host,"not host")

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
end)