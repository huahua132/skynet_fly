local skynet = require "skynet"
local mod_config = require "mod_config"
local contriner_launcher = require "contriner_launcher"

skynet.start(function()
	skynet.error("start log_hook!!!>>>>>>>>>>>>>>>>>")
	contriner_launcher.run()

	skynet.exit()
end)