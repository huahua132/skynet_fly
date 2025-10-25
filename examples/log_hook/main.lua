local skynet = require "skynet"
local container_launcher = require "skynet-fly.container.container_launcher"

skynet.start(function()
	skynet.call('.logger','lua','add_hook', 'loghook')
	skynet.error("start log_hook!!!>>>>>>>>>>>>>>>>>")
	container_launcher.run()
	skynet.exit()
end)