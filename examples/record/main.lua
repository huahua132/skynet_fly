local skynet = require "skynet"
local container_launcher = require "skynet-fly.container.container_launcher"
local sharedata = require "skynet-fly.sharedata"

skynet.start(function()
	skynet.error("start record!!!>>>>>>>>>>>>>>>>>")
	container_launcher.run()

	skynet.exit()
end)