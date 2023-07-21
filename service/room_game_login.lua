local skynet = require "skynet"
require "skynet.manager"
local timer = require "timer"
local log = require "log"
local queue = require "skynet.queue"
local contriner_client = require "contriner_client"
local assert = assert
local x_pcall = x_pcall

local login_plug = nil
local SELF_ADDRESS = nil

local g_gate = nil

local g_fd_agent_map = {}
local g_player_map = {}
local g_login_lock_map = {}

local function close_fd(fd)
	local agent = g_fd_agent_map[fd]
	if not agent then
		log.info("close_fd not agent ",fd)
		return
	end

	skynet.send(agent.gate,'lua','kick',fd)
end

local CMD = {}

function CMD.goout(player_id)
	local agent = assert(g_player_map[player_id])

	g_player_map[player_id] = nil
	login_plug.login_out(player_id)
end

local SOCKET = {}

--ws_gate会传入gate
function SOCKET.open(fd, addr,gate)
	gate = gate or g_gate
	local agent = {
		fd = fd,
		addr = addr,
		gate = gate,
		queue = queue(),
		login_time_out = timer:new(login_plug.time_out,1,close_fd,fd)
	}
	g_fd_agent_map[fd] = agent
	skynet.send(gate,'lua','forward',fd)
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
		local hall_client = player.hall_client
		hall_client:mod_send('disconnect',agent.gate,fd,player_id)
		login_plug.disconnect(agent.gate,fd,player_id)
	end
end

function SOCKET.data(msg)
	log.info('SOCKET.data:',msg)
end

function CMD.socket(cmd,...)
	assert(SOCKET[cmd],'not cmd '.. cmd)
	local f = SOCKET[cmd]
	f(...)
end

local function connect_hall(gate,fd,player_id)
	local old_agent = g_player_map[player_id]
	local hall_client = nil
	if old_agent then
		hall_client = old_agent.hall_client
		login_plug.repeat_login(old_agent.gate,old_agent.fd,player_id)
		close_fd(old_agent.fd)
	else
		hall_client = contriner_client:new("room_game_hall_m",nil,function() return false end)
		hall_client:set_mod_num(player_id)
	end
	
	local ret,errcode,errmsg = hall_client:mod_call("connect",gate,fd,player_id,SELF_ADDRESS)
	if not ret then
		login_plug.login_failed(gate,fd,player_id,errcode,errmsg)
		return
	end

	g_player_map[player_id] = {
		player_id = player_id,
		hall_client = hall_client,
		gate = gate,
		fd = fd,
	}

	login_plug.login_succ(gate,fd,player_id,ret)
	return true
end

local function check_func(gate,fd,...)
	local player_id,errcode,errmsg = login_plug.check(gate,fd,...)
	if not player_id then
		login_plug.login_failed(gate,fd,player_id,errcode,errmsg)
		return
	end

	if g_login_lock_map[player_id] then
		--正在登入中
		login_plug.logining(gate,fd,player_id)
		return
	end
	
	g_login_lock_map[player_id] = true
	local isok,err = x_pcall(connect_hall,gate,fd,player_id)
	g_login_lock_map[player_id] = nil
	if not isok then
		log.fatal("connect_hall failed ",err)
		return
	end
	
	return player_id
end

skynet.start(function()
	SELF_ADDRESS = skynet.self()

	skynet.dispatch('lua',function(session,source,cmd,...)
		local f = CMD[cmd]
		assert(f,'cmd no found :'..cmd)
	
		if session == 0 then
			f(...)
		else
			skynet.retpack(f(...))
		end
	end)

	local confclient = contriner_client:new("share_config_m")
	local room_game_login = confclient:mod_call('query','room_game_login')

	assert(room_game_login.gateservice,"not gateservice")
	assert(room_game_login.gateconf,"not gateconf")
	assert(room_game_login.login_plug,"not login_plug")

	login_plug = require (room_game_login.login_plug)
	assert(login_plug.init,"login_plug not init")				   --初始化
	assert(login_plug.unpack,"login_plug not unpack")              --解包函数
	assert(login_plug.check,"login_plug not check")				   --登录检查
	assert(login_plug.login_succ,"login_plug not login_succ")	   --登录成功
	assert(login_plug.login_failed,"login_plug not login_failed")  --登录失败
	assert(login_plug.disconnect,"login_plug not disconnect")      --掉线
	assert(login_plug.login_out,"login_plug not login_out")        --登出
	assert(login_plug.time_out,"login_plug not time_out")		   --登录超时时间
	
	assert(login_plug.logining,"login_plug not logining")          --正在登录中
	assert(login_plug.repeat_login,"login_plug not repeat_login")  --重复登录

	skynet.register_protocol {
		id = skynet.PTYPE_CLIENT,
		name = "client",
		unpack = login_plug.unpack,
		dispatch = function(fd,source,...)
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
			
			local player_id = agent.queue(check_func,agent.gate,fd,...)
			if not player_id then
				close_fd(fd)
			else
				agent.login_time_out:cancel()
				agent.player_id = player_id
				agent.is_login = true
			end
		end,
	}
	g_gate = skynet.newservice(room_game_login.gateservice)
	login_plug.init()
	skynet.call(g_gate,'lua','open',room_game_login.gateconf)
end)