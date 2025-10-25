local skynet = require "skynet"
local container_launcher = require "skynet-fly.container.container_launcher"

skynet.start(function()
	skynet.error("start orm!!!>>>>>>>>>>>>>>>>>")
	container_launcher.run()

	skynet.exit()
end)