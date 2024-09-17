local skynet = require "skynet"
local contriner_launcher = require "skynet-fly.contriner.contriner_launcher"

skynet.start(function()
	skynet.error("start test!!!")
	contriner_launcher.run()

	skynet.exit()
end)