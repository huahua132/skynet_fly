local log = require "log"
local skynet = require "skynet"
local contriner_client = require "contriner_client"

local string = string

local g_config = nil

local CMD = {}

function CMD.hello(who)
	log.info(string.format("%s send hello msg for me",who))
end

function CMD.ping()
	local confclient = contriner_client:new("share_config_m")
	local conf = confclient:mod_call('query','cluster_server')
	return string.format("pong %s %s %s",g_config.instance_name,conf.host,skynet.self())
end

function CMD.start(config)
	g_config = config
	return true
end

function CMD.exit()

end

return CMD