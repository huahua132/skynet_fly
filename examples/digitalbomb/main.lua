local skynet = require "skynet"
local contriner_launcher = require "skynet-fly.contriner.contriner_launcher"

skynet.start(function()
	skynet.error("start digitalbomb!!!>>>>>>>>>>>>>>>>>")
	local delay_run = contriner_launcher.run()

	skynet.uniqueservice("room_game_login")

	delay_run()
	skynet.exit()
end)