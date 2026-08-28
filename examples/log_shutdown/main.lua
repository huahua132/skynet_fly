local skynet = require "skynet"
local container_launcher = require "skynet-fly.container.container_launcher"

skynet.start(function()
	--开关由 test_m 模块根据 SHUTDOWN_MODE 控制, 见 load_mods.lua
	skynet.error("start log_shutdown!!! fatal 日志自动强制关服测试, 场景由 SHUTDOWN_MODE 决定 >>>>>>>>>>>>>>>>>")
	container_launcher.run()
	skynet.exit()
end)
