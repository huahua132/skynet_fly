local skynet = require "skynet"
local container_launcher = require "skynet-fly.container.container_launcher"

skynet.start(function()
	skynet.error("start frpc_server!!!>>>>>>>>>>>>>>>>>")
	container_launcher.run()

	skynet.uniqueservice("frpc_server")
	skynet.exit()
end)