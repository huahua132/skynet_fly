local skynet = require "skynet"
local container_launcher = require "skynet-fly.container.container_launcher"

skynet.start(function()
	skynet.error("start AB_question!!!>>>>>>>>>>>>>>>>>")
    container_launcher.run()
	skynet.exit()
end)