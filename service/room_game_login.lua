---@diagnostic disable: need-check-nil, undefined-field
local skynet = require "skynet.manager"
local timer = require "skynet-fly.timer"
local log = require "skynet-fly.log"
local queue = require "skynet.queue"
local contriner_client = require "skynet-fly.client.contriner_client"
local skynet_util = require "skynet-fly.utils.skynet_util"

local assert = assert
local x_pcall = x_pcall
local pairs = pairs
local tinsert = table.insert

contriner_client:register("share_config_m","room_game_hall_m")

local login_plug = nil
local SELF_ADDRESS = nil

local g_gate = nil

local g_fd_agent_map = {}
local g_player_map = {}
local g_login_lock_map = {}
local g_isjumping = false

local interface = {}
local EMPTY = {}
local NOT_SWITCH_FUNC = function() return false end

local continue = {}
----------------------------------------------------------------------------------
--private
----------------------------------------------------------------------------------
local function jump_one_player(agent)
	local player_id = agent.player_id
	if agent.fd > 0 then
		skynet.call(agent.gate, 'lua', 'pause', agent.fd)
	end
	local hall_client = agent.hall_client
	local server_id = hall_client:get_mod_server_id()
	local ret, errno, errmsg = hall_client:mod_call("jump_exit", player_id)					--从旧服务中跳出
	log.warn_fmt("jump_exits server_id[%s] gate[%s] fd[%s] is_ws[%s] player_id[%s] ret[%s] errno[%s] errmsg[%s]", skynet.address(server_id), agent.gate, agent.fd, agent.is_ws, player_id, ret, errno, errmsg)
	if ret then																				--成功
		local new_hall_client = contriner_client:new("room_game_hall_m", nil, NOT_SWITCH_FUNC)
		new_hall_client:set_mod_num(player_id)
		local server_id = new_hall_client:get_mod_server_id()
		ret,errno,errmsg = new_hall_client:mod_call("jump_join", agent.gate, agent.fd, agent.is_ws, agent.addr, player_id, SELF_ADDRESS)	--跳入新服务
		log.warn_fmt("jump_join server_id[%s] gate[%s] fd[%s] is_ws[%s] player_id[%s] ret[%s] errno[%s] errmsg[%s]", skynet.address(server_id), agent.gate, agent.fd, agent.is_ws, player_id, ret, errno, errmsg)
		if ret then
			agent.hall_client = new_hall_client
		end
	end

	if agent.fd > 0 then
		skynet.call(agent.gate, 'lua', 'play', agent.fd)
	end
end

contriner_client:add_updated_cb("room_game_hall_m", function()
	if not login_plug.is_jump_new then return end
	if g_isjumping then return end

	g_isjumping = true
	skynet.fork(function()
		while true do
			local cnt = 0
			for player_id, agent in pairs(g_player_map) do
				if agent and not agent.is_goout and agent.hall_client and agent.hall_client:is_visitor_old() then
					cnt = cnt + 1
					agent.queue(jump_one_player, agent)
					if cnt >= login_plug.jump_once_cnt then
						break
					end
				end
			end
			
			local isok = true
			for player_id, agent in pairs(g_player_map) do
				if agent and not agent.is_goout and agent.hall_client and agent.hall_client:is_visitor_old() then
					isok = false
					break
				end
			end

			if isok then break end

			skynet.sleep(login_plug.jump_inval_time * 100)		--等一段时间再试
		end

		g_isjumping = false
	end)
end)

local function close_fd(fd)
	if fd <= 0 then return end
	local agent = g_fd_agent_map[fd]
	if not agent then
		return
	end
	skynet.send(agent.gate,'lua','kick',fd)
end

local function connect_hall(gate, fd, is_ws, addr, player_id, header, rsp_session)
	local old_agent = g_player_map[player_id]
	local hall_client = nil
	if old_agent then
		hall_client = old_agent.hall_client
		if interface:is_online(player_id) then
			login_plug.repeat_login(player_id, header, rsp_session)
		end
		close_fd(old_agent.fd)
	else
		hall_client = contriner_client:new("room_game_hall_m", nil, NOT_SWITCH_FUNC)
		hall_client:set_mod_num(player_id)
	end
	
	local ret,errcode,errmsg = hall_client:mod_call("connect",gate, fd, is_ws, addr, player_id, SELF_ADDRESS)
	if not ret then
		login_plug.login_failed(player_id, errcode, errmsg, header, rsp_session)
		return
	end

	if old_agent then
		old_agent.hall_client = hall_client
		old_agent.fd = fd
		old_agent.gate = gate
		old_agent.is_ws = is_ws
		old_agent.addr = addr
	else
		g_player_map[player_id] = {
			player_id = player_id,
			hall_client = hall_client,
			gate = gate,
			fd = fd,
			is_ws = is_ws,
			addr = addr,
			queue = queue(),
		}
	end

	login_plug.login_succ(player_id, ret, header, rsp_session)
	return true
end

local function check_func(gate, fd, is_ws, addr, header, body, rsp_session)
	local player_id,errcode,errmsg = login_plug.check(header, body, rsp_session)
	if player_id == continue then
		return continue
	end

	if not player_id then
		login_plug.login_failed(player_id, errcode, errmsg, header, rsp_session, fd)
		return
	end

	if g_login_lock_map[player_id] then
		--正在登入中
		login_plug.logining(player_id, header, rsp_session, fd)
		return
	end
	
	g_login_lock_map[player_id] = true
	local isok,err = x_pcall(connect_hall, gate, fd, is_ws, addr, player_id, header, rsp_session)
	g_login_lock_map[player_id] = nil
	if not isok then
		log.error("connect_hall failed ", gate, fd, is_ws, addr, player_id, header, rsp_session, err)
		return
	end
	
	return player_id
end

----------------------------------------------------------------------------------
--interface
----------------------------------------------------------------------------------
local function send_msg(agent, header, body)
	if agent.is_ws then
		login_plug.ws_send(agent.gate, agent.fd, header, body)
	else
		login_plug.send(agent.gate, agent.fd, header, body)
	end
end

function interface:is_online(player_id)
	local agent = g_player_map[player_id]
	if not agent then
		return false
	end

	return agent.fd ~= 0
end

--发送消息
function interface:send_msg(player_id, header, body)
	if not interface:is_online(player_id) then
		log.info("send msg not online ", player_id, header)
		return
	end
	local agent = g_player_map[player_id]
	send_msg(agent, header, body)
end

--发送消息通过fd
function interface:send_msg_byfd(fd, header, body)
	local agent = g_fd_agent_map[fd]
	if not agent then
		log.info("send msg fd not exists ", fd, header)
		return
	end

	send_msg(agent, header, body)
end

--发送消息给部分玩家
function interface:send_msg_by_player_list(player_list, header, body)
	local gate_list = {}
	local fd_list = {}

	local ws_gate_list = {}
	local ws_fd_list = {}

	for i = 1, #player_list do
		local player_id = player_list[i]
		local agent = g_player_map[player_id]
		if not agent then
			log.info("send_msg_by_player_list not exists ",player_id)
		else
			if agent.fd > 0 then
				if agent.is_ws then
					tinsert(ws_gate_list, agent.gate)
					tinsert(ws_fd_list, agent.fd)
				else
					tinsert(gate_list, agent.gate)
					tinsert(fd_list, agent.fd)
				end
			else
				log.info("send_msg_by_player_list not online ",player_id)
			end
		end
	end

	if #gate_list > 0 then
		login_plug.broadcast(gate_list, fd_list, header, body)
	end

	if #ws_gate_list > 0 then
		login_plug.ws_broadcast(ws_gate_list, ws_fd_list, header, body)
	end
end

--广播发送消息
function interface:broad_cast_msg(header, body, filter_map)
	filter_map = filter_map or EMPTY

	local gate_list = {}
	local fd_list = {}

	local ws_gate_list = {}
	local ws_fd_list = {}

	for player_id,agent in pairs(g_player_map) do
		if not filter_map[player_id] then
			if agent.fd > 0 then
				if agent.is_ws then
					tinsert(ws_gate_list, agent.gate)
					tinsert(ws_fd_list, agent.fd)
				else
					tinsert(gate_list, agent.gate)
					tinsert(fd_list, agent.fd)
				end
			else
				log.info("broad_cast_msg not online ",player_id)
			end
		end
	end

	if #gate_list > 0 then
		login_plug.broadcast(gate_list, fd_list, header, body)
	end

	if #ws_gate_list > 0 then
		login_plug.ws_broadcast(ws_gate_list, ws_fd_list, header, body)
	end
end

--继续等待登录消息
function interface:continue()
	return continue
end

--获取客户端连接IP:PORT
function interface:get_addr(player_id)
	local agent = g_player_map[player_id]
	if not agent then
		return ""
	end

	return agent.addr
end

--rpc回复消息
function interface:rpc_rsp_msg(player_id, header, msgbody, rsp_session)
	if not interface:is_online(player_id) then
		log.info("rpc_rsp_msg not online ", player_id, header)
		return
	end
	local agent = g_player_map[player_id]

	local body = login_plug.rpc_pack.pack_rsp(msgbody, rsp_session)
	send_msg(agent, header, body)
end

--rpc回复消息
function interface:rpc_rsp_msg_byfd(fd, header, msgbody, rsp_session)
	local agent = g_fd_agent_map[fd]
	if not agent then
		log.info("rpc_rsp_msg_byfd fd not exists ", fd, header)
		return
	end

	local body = login_plug.rpc_pack.pack_rsp(msgbody, rsp_session)
	send_msg(agent, header, body)
end

--rpc回复error消息
function interface:rpc_error_msg(player_id, header, msgbody, rsp_session)
	if not interface:is_online(player_id) then
		log.info("rpc_error_msg not online ", player_id, header)
		return
	end
	local agent = g_player_map[player_id]

	local body = login_plug.rpc_pack.pack_error(msgbody, rsp_session)
	send_msg(agent, header, body)
end

--rpc回复error消息通过fd
function interface:rpc_error_msg_byfd(fd, header, msgbody, rsp_session)
	local agent = g_fd_agent_map[fd]
	if not agent then
		log.info("rpc_error_msg_byfd fd not exists ", fd, header)
		return
	end

	local body = login_plug.rpc_pack.pack_error(msgbody, rsp_session)
	send_msg(agent, header, body)
end

--rpc推送消息
function interface:rpc_push_msg(player_id, header, msgbody)
	if not interface:is_online(player_id) then
		log.info("rpc_push_msg not online ", player_id, header)
		return
	end
	local agent = g_player_map[player_id]
	local body = login_plug.rpc_pack.pack_push(msgbody)
	if not interface:is_online(player_id) then
		log.info("rpc_push_msg not online ", player_id, header)
		return
	end
	send_msg(agent, header, body)
end

--rpc推送消息
function interface:rpc_push_msg_byfd(fd, header, msgbody)
	local agent = g_fd_agent_map[fd]
	if not agent then
		log.info("rpc_push_msg_byfd fd not exists ", fd, header)
		return
	end

	local body = login_plug.rpc_pack.pack_push(msgbody)
	if not agent then
		log.info("rpc_push_msg_byfd fd not exists ", fd, header)
		return
	end
	send_msg(agent, header, body)
end

--rpc推送消息给部分玩家
function interface:rpc_push_by_player_list(player_list, header, msgbody)
	local body = login_plug.rpc_pack.pack_push(msgbody)
	local gate_list = {}
	local fd_list = {}

	local ws_gate_list = {}
	local ws_fd_list = {}

	for i = 1, #player_list do
		local player_id = player_list[i]
		local agent = g_player_map[player_id]
		if not agent then
			log.info("rpc_push_by_player_list not exists ",player_id)
		else
			if agent.fd > 0 then
				if agent.is_ws then
					tinsert(ws_gate_list, agent.gate)
					tinsert(ws_fd_list, agent.fd)
				else
					tinsert(gate_list, agent.gate)
					tinsert(fd_list, agent.fd)
				end
			else
				log.info("rpc_push_by_player_list not online ",player_id)
			end
		end
	end

	if #gate_list > 0 then
		login_plug.broadcast(gate_list, fd_list, header, body)
	end

	if #ws_gate_list > 0 then
		login_plug.ws_broadcast(ws_gate_list, ws_fd_list, header, body)
	end
end

--rpc推送消息给全部玩家
function interface:rpc_push_broad_cast(header, msgbody, filter_map)
	filter_map = filter_map or EMPTY
	local body = login_plug.rpc_pack.pack_push(msgbody)
	local gate_list = {}
	local fd_list = {}

	local ws_gate_list = {}
	local ws_fd_list = {}

	for player_id,agent in pairs(g_player_map) do
		if not filter_map[player_id] then
			if agent.fd > 0 then
				if agent.is_ws then
					tinsert(ws_gate_list, agent.gate)
					tinsert(ws_fd_list, agent.fd)
				else
					tinsert(gate_list, agent.gate)
					tinsert(fd_list, agent.fd)
				end
			else
				log.info("rpc_push_broad_cast not online ",player_id)
			end
		end
	end
	
	if #gate_list > 0 then
		login_plug.broadcast(gate_list, fd_list, header, body)
	end

	if #ws_gate_list > 0 then
		login_plug.ws_broadcast(ws_gate_list, ws_fd_list, header, body)
	end
end
----------------------------------------------------------------------------------
--CMD
----------------------------------------------------------------------------------
local CMD = {}

function CMD.goout(player_id)
	local agent = assert(g_player_map[player_id])
	agent.is_goout = true
	g_player_map[player_id] = nil
	login_plug.login_out(player_id)
	close_fd(agent.fd)
end

local SOCKET = {}

--ws_gate会传入gate
function SOCKET.open(fd, addr, gate, is_ws)
	gate = gate or g_gate				--gate服务不会传递 gate  ws_gate会
	--先设置转发，成功后再建立连接管理映射，不然存在建立连接，客户端立马断开的情况，掉线无法通知到此服务
	if not skynet.call(gate,'lua','forward',fd) then --设置转发不成功，以下就不会执行了，就当它没有来连接过
		return
	end
	local agent = {
		fd = fd,
		addr = addr,
		gate = gate,
		queue = queue(),
		login_time_out = timer:new(login_plug.time_out,1,close_fd,fd),
		is_ws = is_ws,
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

	local player_id = agent.player_id
	local player = g_player_map[player_id]
	if player then
		if fd == player.fd then
			player.fd = 0
			local hall_client = player.hall_client
			login_plug.disconnect(player_id)
			hall_client:mod_send('disconnect',agent.gate,fd,player_id)
		end
	end
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

local function send_player_hall(agent, ...)
	local hall_client = agent.hall_client
	hall_client:mod_send(...)
end

--发送到玩家所在大厅服
function CMD.send_player_hall(player_id, ...)
	local agent = g_player_map[player_id]

	--玩家在线就发到所在服
	if agent then
		agent.queue(send_player_hall, agent, ...)
	else
		--不在线就发到最新的hall服务上
		contriner_client:instance("room_game_hall_m"):set_mod_num(player_id):mod_send(...)
	end
end

local function call_player_hall(agent, ...)
	local hall_client = agent.hall_client
	return hall_client:mod_call(...)
end

--发送到玩家所在大厅服
function CMD.call_player_hall(player_id, ...)
	local agent = g_player_map[player_id]
	--玩家在线就发到所在服
	if agent then
		return agent.queue(call_player_hall, agent, ...)
	else
		--不在线就发到最新的hall服务上
		return contriner_client:instance("room_game_hall_m"):set_mod_num(player_id):mod_call(...)
	end
end

skynet.start(function()
	SELF_ADDRESS = skynet.self()
	skynet_util.lua_dispatch(CMD)

	local confclient = contriner_client:new("share_config_m")
	local room_game_login = confclient:mod_call('query','room_game_login')

	assert(room_game_login.gateconf or room_game_login.wsgateconf,"not gateconf or wsgateconf")
	assert(room_game_login.login_plug,"not login_plug")

	login_plug = require (room_game_login.login_plug)
	assert(login_plug.init,"login_plug not init")				       --初始化
	if room_game_login.gateconf then
		assert(login_plug.unpack,"login_plug not unpack")              --解包函数
		assert(login_plug.send,"login_plug not send")                  --发包函数
		assert(login_plug.broadcast,"login_plug not broadcast")   	   --广播发包函数
	end

	if room_game_login.wsgateconf then
		assert(login_plug.ws_unpack,"login_plug not ws_unpack")        --ws解包函数
		assert(login_plug.ws_send,"login_plug not ws_send")            --ws发包函数
		assert(login_plug.ws_broadcast,"login_plug not ws_broadcast")  --ws广播发包函数
	end

	assert(login_plug.check,"login_plug not check")				   --登录检查
	assert(login_plug.login_succ,"login_plug not login_succ")	   --登录成功
	assert(login_plug.login_failed,"login_plug not login_failed")  --登录失败
	assert(login_plug.disconnect,"login_plug not disconnect")      --掉线
	assert(login_plug.login_out,"login_plug not login_out")        --登出
	assert(login_plug.time_out,"login_plug not time_out")		   --登录超时时间
	
	assert(login_plug.logining,"login_plug not logining")          --正在登录中
	assert(login_plug.repeat_login,"login_plug not repeat_login")  --重复登录

	login_plug.is_jump_new = login_plug.is_jump_new or false 	   --是否跳转到新服务
	login_plug.jump_inval_time = login_plug.jump_inval_time or 60  --跳转尝试间隔时间
	login_plug.jump_once_cnt = login_plug.jump_once_cnt or 10	   --单次尝试跳转人数

	local rpc_pack = login_plug.rpc_pack				   		   --rpc包处理工具
	
	if login_plug.register_cmd then
		for name,func in pairs(login_plug.register_cmd) do
			assert(not CMD[name],"repeat cmd " .. name)
			CMD[name] = func
		end
	end

	skynet.register_protocol {
		id = skynet.PTYPE_CLIENT,
		name = "client",
		unpack = function(msg, sz)
			return msg, sz
		end,
		dispatch = function(fd, source, msg, sz)
			skynet.set_trace_tag()
			skynet.ignoreret()
			local agent = g_fd_agent_map[fd]
			if not agent then
				log.info("dispatch not agent ",fd)
				return
			end

			--避免重复登录，登录成功之后把消息转发到agent那边去，这里只处理登录
			if agent.is_login then
				log.info("repeat login ",fd)
				return
			end

			local unpack = nil
			if agent.is_ws then
				unpack = login_plug.ws_unpack
			else
				unpack = login_plug.unpack
			end

			local header, body = unpack(msg, sz)
			if not header then
				log.error("unpack err ", fd, agent.addr, agent.is_ws, sz, header, body)
				return
			end

			local rsp_session = nil
			if rpc_pack then
				local pre_header = header
				header, body, rsp_session = rpc_pack.handle_msg(header, body)
				if not header then
					log.error("rpc_pack handle_msg err ", fd, agent.addr, agent.is_ws, pre_header, body)
					return
				end
			end

			local player_id = agent.queue(check_func, agent.gate, fd, agent.is_ws, agent.addr, header, body, rsp_session)
			if not player_id then
				close_fd(fd)
			elseif player_id == continue then
				--继续处理后续登录消息
			else
				agent.login_time_out:cancel()
				agent.player_id = player_id
				agent.is_login = true
			end
		end,
	}
	login_plug.init(interface)

	if room_game_login.gateconf then
		g_gate = skynet.newservice("gate")
		skynet.call(g_gate,'lua','open',room_game_login.gateconf)
	end

	if room_game_login.wsgateconf then
		local ws_gate = skynet.newservice("ws_gate")
		skynet.call(ws_gate,'lua','open',room_game_login.wsgateconf)
	end

	skynet.register(".room_game_login")
end)