local skynet = require "skynet"
require "skynet.manager"
local timer = require "timer"
local log = require "log"
local queue = require "skynet.queue"
local contriner_client = require "contriner_client"
local assert = assert
local x_pcall = x_pcall

local gate
local check_module = nil

local g_fd_agent_map = {}
local g_player_map = {}

local function del_agent(fd)
	local agent = g_fd_agent_map[fd]
	if not agent then
		log.info("del_agent not agent ",fd)
		return
	end

	local player_id = agent.player_id
	
	if player_id and g_player_map[player_id] then
		check_module.disconnect(fd,player_id)
	end

	g_fd_agent_map[fd] = nil

	if agent.fd > 0 then
		--通知网关关闭
		skynet.send(gate,'lua','kick',fd)
	end

	log.info("del_agent ",fd)
end

local CMD = {}

function CMD.goout(player_id)
	assert(g_player_map[player_id])

	log.error("goout:",player_id)
	g_player_map[player_id] = nil
	check_module.login_out(player_id)
end

local SOCKET = {}

function SOCKET.open(fd, addr)
	log.info('SOCKET.open:',fd,addr)
	local agent = {
		fd = fd,
		addr = addr,
		queue = queue(),
		login_time_out = timer:new(check_module.time_out,1,del_agent,fd)
	}
	g_fd_agent_map[fd] = agent
	skynet.send(gate,'lua','forward',fd)
end

function SOCKET.close(fd)
	log.info('SOCKET.close:',fd)
	local agent = g_fd_agent_map[fd]
	if not agent then
		log.warn("close not agent ",fd)
		return
	end
	agent.fd = 0
	agent.queue(del_agent,fd)
end

function SOCKET.error(fd, msg)
	log.info('SOCKET.error:',fd,msg)
	local agent = g_fd_agent_map[fd]
	if not agent then
		log.warn("error not agent ",fd)
		return
	end

	agent.queue(del_agent,fd)
end

function SOCKET.warning(fd, size)
	log.info('SOCKET.error:',fd,size)
end

function SOCKET.data(msg)
	log.info('SOCKET.data:',msg)
end

function CMD.socket(cmd,...)
	assert(SOCKET[cmd],'not cmd '.. cmd)
	local f = SOCKET[cmd]
	f(...)
end

skynet.start(function()
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
	local loginconf = confclient:mod_call('query','loginconf')
	assert(loginconf.gateconf,"not gateconf")
	assert(loginconf.check_module,"not check_module")

	check_module = require (loginconf.check_module)
	assert(check_module.unpack,"check_module not unpack")
	assert(check_module.check,"check_module not check")
	assert(check_module.login_out,"check_module not login_out")
	assert(check_module.disconnect,"check_module not disconnect")
	assert(check_module.init,"check_module not init")
	assert(check_module.time_out,"check_module not time_out")
	skynet.register_protocol {
		id = skynet.PTYPE_CLIENT,
		name = "client",
		unpack = check_module.unpack,
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

			local player_id = agent.queue(check_module.check,fd,...)
			if not player_id then
				agent.queue(del_agent,fd)
			else
				agent.login_time_out:cancel()
				agent.player_id = player_id
				agent.is_login = true
				g_player_map[player_id] = agent
			end
		end,
	}

	gate = skynet.newservice('gate')
	check_module.init(gate)
	skynet.call(gate,'lua','open',loginconf.gateconf)	
	skynet.register('.login')
end)