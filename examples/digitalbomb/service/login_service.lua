local skynet = require "skynet"
require "skynet.manager"
local contriner_client = require "contriner_client"
local pb_util = require "pb_util"
local pbnet_util = require "pbnet_util"
local timer = require "timer"
local log = require "log"
local queue = require "skynet.queue"
local errorcode = require "errorcode"
local errors_msg = require "errors_msg"
local login_msg = require "login_msg"
local assert = assert
local x_pcall = x_pcall

local gate

local g_fd_agent_map = {}
local g_player_map = {}
local login_lock_map = {}

local function del_agent(fd)
	local agent = g_fd_agent_map[fd]
	if not agent then
		log.info("del_agent not agent ",fd)
		return
	end

	local player_id = agent.player_id

	if agent.hall_client then
		agent.hall_client:mod_call('disconnect',player_id)
	end

	g_fd_agent_map[fd] = nil

	if agent.fd > 0 then
		--通知网关关闭
		skynet.send(gate,'lua','kick',fd)
	end

	log.info("del_agent ",fd)
end

local function check_join(req,fd,packname,agent,player_id)
	--登录检查
	local login_res,errcode,errmsg
	if req.password ~= '123456' then
		log.error("login err ",req)
		return false,errorcode.LOGIN_PASS_ERR,"pass err"
	else
		local old_agent = g_player_map[player_id]
		local hall_client = nil
		if old_agent then
			hall_client = old_agent.hall_client
			del_agent(old_agent.fd)
		else
			hall_client = contriner_client:new("hall_m",nil,function() return false end)
			hall_client:set_mod_num(player_id)
		end
		
		login_res,errcode,errmsg = hall_client:mod_call("join",player_id,req,fd,gate)
		if login_res then
			agent.hall_client = hall_client
			agent.player_id = player_id
			g_player_map[player_id] = agent
		else
			log.error("join hall err ",player_id)
			return false,errcode,errmsg
		end
	end
	return login_res
end

local function login(fd,packname,req)
	local agent = g_fd_agent_map[fd]
	if not agent then
		log.error("login_check not agent err ",agent)
		return
	end

	agent.login_time_out:cancel()

	if not packname then
		log.error("unpack err ",packname,req)
		return
	end

	if packname ~= '.login.LoginReq' then
		log.error("login_check msg err ",fd)
		return false,errorcode.NOT_LOGIN,"please login"
	end

	local player_id = req.player_id
	if not player_id then
		log.error("req err ",fd,req)
		return false,errorcode.REQ_PARAM_ERR,"not player_id"
	end

	if login_lock_map[player_id] then
		log.error("repeat login ",player_id)
		return false,errorcode.REPAET_LOGIN,"repeat login"
	end

	login_lock_map[player_id] = true
	local isok,login_res,code,errmsg = x_pcall(check_join,req,fd,packname,agent,player_id)
	login_lock_map[player_id] = false
	if not isok or not login_res then
		log.error("login err ",login_res,code,errmsg)
		return login_res,code,errmsg
	else
		login_msg.login_res(fd,login_res)
		return true
	end
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
		dispatch = function(fd,source,packname,req)
			skynet.ignoreret()
			local agent = g_fd_agent_map[fd]
			if not agent then
				log.error("dispatch not agent ",fd)
				return
			end

			local isok,errcode,msg = agent.queue(login,fd,packname,req)
			if not isok then
				errors_msg.errors(fd,errcode,msg,packname)
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