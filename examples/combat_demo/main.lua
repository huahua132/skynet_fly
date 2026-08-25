-- combat_demo 战斗示例入口
-- 单服务（combat_m）：2 名玩家准备后自动开局，跑一场 AI 对战并打印战斗日志
local skynet = require "skynet"
local container_launcher = require "skynet-fly.container.container_launcher"

skynet.start(function()
	skynet.error("start combat_demo!!!>>>>>>>>>>>>>>>>>")
	container_launcher.run()
	skynet.exit()
end)
