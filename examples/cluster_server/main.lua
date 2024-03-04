local skynet = require "skynet"
local contriner_launcher = require "skynet-fly.contriner.contriner_launcher"

skynet.start(function()
	skynet.error("start cluster_server!!!>>>>>>>>>>>>>>>>>")
	contriner_launcher.run()

	skynet.uniqueservice("cluster_server")
	skynet.exit()
end)