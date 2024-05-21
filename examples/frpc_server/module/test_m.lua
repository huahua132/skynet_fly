local log = require "skynet-fly.log"
local skynet = require "skynet"
local contriner_client = require "skynet-fly.client.contriner_client"

contriner_client:register("share_config_m")
local string = string

local g_config = nil
local g_host_conf = nil

local CMD = {}

function CMD.hello(who)
	log.info(string.format("%s send hello msg for me " .. g_config.instance_name, who))
end

function CMD.ping(msg)
	if not g_host_conf then
		local confclient = contriner_client:new("share_config_m")
		g_host_conf = confclient:mod_call('query','frpc_server')
	end
	
	return string.format("pong %s %s %s msg[%s]", g_config.instance_name, g_host_conf.host, skynet.self(), msg)
end

function CMD.large_msg(list)
	return list
end

function CMD.start(config)
	g_config = config
	return true
end

function CMD.exit()
	return true
end

return CMD