local skynet = require "skynet"
local container_launcher = require "skynet-fly.container.container_launcher"

skynet.start(function()
	skynet.error("start digitalbomb!!!>>>>>>>>>>>>>>>>>")
	local delay_run = container_launcher.run()

	skynet.uniqueservice("room_game_login")

	delay_run()
	skynet.exit()
end)