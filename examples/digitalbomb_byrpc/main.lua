local skynet = require "skynet"
local container_launcher = require "skynet-fly.container.container_launcher"
local env_util = require "skynet-fly.utils.env_util"

skynet.start(function()
	skynet.error("start digitalbomb!!!>>>>>>>>>>>>>>>>>")
	env_util.setenv("test_proto", "sp")		--设置测试协议

	local delay_run = container_launcher.run()

	skynet.uniqueservice("room_game_login")

	delay_run()
	skynet.exit()
end)