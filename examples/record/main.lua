local skynet = require "skynet"
local contriner_launcher = require "skynet-fly.contriner.contriner_launcher"
local sharedata = require "skynet-fly.sharedata"

skynet.start(function()
	skynet.error("start record!!!>>>>>>>>>>>>>>>>>")
	contriner_launcher.run()

	skynet.exit()
end)