local skynet = require "skynet"
local log = require "log"
local pbnet_util = require "pbnet_util"
local hall_agents = require "hall_agents"
local errors_msg = require "errors_msg"
local login_msg = require "login_msg"
local timer = require "timer"
local errorcode = require "errorcode"

local CMD = {}

local function dispatch(fd,source,packname,req)
	skynet.ignoreret()
	if not packname then
		log.error("unpack err ",packname,req)
		return
	end
	log.info('dispatch:',fd,source,packname,req)

	if packname == '.login.LoginOutReq' then
		local agent = hall_agents.get_agent(fd)
		if not agent then
			log.error("LoginOutReq not agent ",fd,packname)
			return
		end
		
		local ok,errorcode,errormsg = CMD.goout(agent.player_id)
		if not ok then
			errors_msg.errors(fd,errorcode,errormsg,packname)
		else
			login_msg.login_out_res(fd,agent.player_id)
		end
	else
		hall_agents.send_request(fd,packname,req)
	end
end

function CMD.join(player_id,player_info,fd,gate)
	log.info("join:",player_id,player_info,fd,gate)
	return hall_agents.join(player_id,player_info,fd,gate)
end

function CMD.disconnect(player_id)
	log.info("disconnect:",player_id)
	return hall_agents.disconnect(player_id)
end

function CMD.goout(player_id)
	log.info("goout:",player_id)
	return hall_agents.goout(player_id)
end

function CMD.start()
	skynet.register_protocol {
		id = skynet.PTYPE_CLIENT,
		name = "client",
		unpack = pbnet_util.unpack,
		dispatch = dispatch,
	}

	return true
end

function CMD.exit()
	timer:new(timer.minute,0,function()
		if hall_agents.is_empty() then
			skynet.exit()
		end
	end)
end

return CMD