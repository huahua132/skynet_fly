local log = require "skynet-fly.log"
local skynet = require "skynet"
local contriner_client = require "skynet-fly.client.contriner_client"
local watch_server = require "skynet-fly.rpc.watch_server"
local module_info = require "skynet-fly.etc.module_info"

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
	local base_info = module_info.get_base_info()
	if base_info.index == 1 then
		skynet.fork(function()
			local i = 0
			while true do
				--log.info("publish >>> ", i)
				watch_server.publish("test_pub", "hello test_pub", i)
				skynet.sleep(100)
				i = i + 1
			end
		end)
		-- --large msg
		-- skynet.fork(function()
		-- 	while true do
		-- 		local str = ""
		-- 		for i = 1, 1024 * 100 do
		-- 			str = str .. '1'
		-- 		end
		-- 		watch_server.publish("test_pub_large", str)

		-- 		skynet.sleep(1000)
		-- 	end
		-- end)

		skynet.fork(function()
			local i = 0
			while true do
				watch_server.pubsyn("test_syn", "hello test_syn", i)
				skynet.sleep(100)
				i = i + 1
			end
		end)
	end
	return true
end

function CMD.exit()
	return true
end

return CMD