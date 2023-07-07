local skynet = require "skynet"
require "skynet.manager"
local contriner_client = require "contriner_client"
local pb_util = require "pb_util"
local pbnet_util = require "pbnet_util"
local timer = require "timer"
local log = require "log"
local queue = require "skynet.queue"
local errorcode = require "errorcode"
local assert = assert

local gate

local g_fd_agent_map = {}
local g_player_map = {}

local function del_agent(fd)
	local agent = g_fd_agent_map[fd]
	if not agent then
		log.error("del_agent fd err ",fd)
		return
	end

	local player_id = agent.player_id

	if agent.hall_client then
		agent.hall_client:mod_call('disconnect',player_id)
	end

	g_fd_agent_map[player_id] = nil

	if agent.fd > 0 then
		--通知网关关闭
		skynet.send(gate,'lua','kick',fd)
	end

	log.info("del_agent ",fd)
end

local function login_check(fd,packname,tab)
	local agent = g_fd_agent_map[fd]
	if not agent then
		log.error("login_check not agent err ",agent)
		return
	end

	agent.login_time_out:cancel()

	if not packname then
		log.error("unpack err ",packname,tab)
		return
	end

	if packname ~= '.login.LoginReq' then
		log.error("login_check msg err ",fd)
		return
	end

	--登录检查
	if tab.password ~= '123456' then
		log.error("login err ",tab)
		pbnet_util.send(fd,'.error.ErrorMsg',{
			code = errorcode.LOGIN_PASS_ERR,
			reqcmd = packname,
			msg = "login pass err"
		})
		return
	else
		local old_agent = g_player_map[tab.player_id]
		local hall_client = nil
		if old_agent then
			hall_client = old_agent.hall_client
			del_agent(old_agent.fd)
		else
			hall_client = contriner_client:new("hall_m",nil,function() return false end)
			hall_client:set_mod_num(tab.player_id)
		end
		
		if hall_client:mod_call("join",tab.player_id,tab,fd,gate) then
			agent.hall_client = hall_client
			agent.player_id = tab.player_id
			pbnet_util.send(fd,'.login.LoginRes',{player_id = tab.player_id})
		else
			log.error("join hall err ",tab.player_id)
			return
		end
	end

	return true
end

local CMD = {}

function CMD.goout(player_id)
	assert(g_player_map[player_id])

	log.error("goout:",player_id)
	g_player_map[player_id] = nil
end

local SOCKET = {}

function SOCKET.open(fd, addr)
	log.info('SOCKET.open:',fd,addr)
	local agent = {
		fd = fd,
		addr = addr,
		queue = queue(),
		login_time_out = timer:new(timer.second * 5,1,del_agent,fd)
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
	pb_util.load('./proto')

	skynet.dispatch('lua',function(session,source,cmd,...)
		local f = CMD[cmd]
		assert(f,'cmd no found :'..cmd)
	
		if session == 0 then
			f(...)
		else
			skynet.retpack(f(...))
		end
	end)

	skynet.register_protocol {
		id = skynet.PTYPE_CLIENT,
		name = "client",
		unpack = pbnet_util.unpack,
		dispatch = function(fd,source,packname,tab)
			skynet.ignoreret()
			local agent = g_fd_agent_map[fd]
			if not agent then
				log.warn("dispatch not agent ",fd)
				return
			end

			if not agent.queue(login_check,fd,packname,tab) then
				agent.queue(del_agent,fd)
			end
		end,
	}

	local confclient = contriner_client:new("share_config_m")
	local gateconf = confclient:mod_call('query','gate')

	gate = skynet.newservice('gate')
	skynet.call(gate,'lua','open',gateconf)

	skynet.register('.login')
end)