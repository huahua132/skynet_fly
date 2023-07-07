local skynet = require "skynet"
local log = require "log"
local pbnet_util = require "pbnet_util"
local hall_agents = require "hall_agents"
local timer = require "timer"

local function dispatch(fd,source,packname,tab)
	skynet.ignoreret()
	if not packname then
		log.error("unpack err ",packname,tab)
		return
	end
	log.info('dispatch:',fd,source,packname,tab)
	hall_agents.send_request(fd,packname,tab)
end

local CMD = {}

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
	timer:new(timer.second * 60,0,function()
		if hall_agents.is_empty() then
			skynet.exit()
		end
	end)
end

return CMD