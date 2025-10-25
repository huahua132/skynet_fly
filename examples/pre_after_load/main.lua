local skynet = require "skynet"
local container_launcher = require "skynet-fly.container.container_launcher"
local env_util = require "skynet-fly.utils.env_util"

skynet.start(function()
	skynet.error("start pre_after_load!!!>>>>>>>>>>>>>>>>>")
	env_util.add_pre_load("./pre_load.lua")                --增加服务加载之前调用
	env_util.add_pre_load("./pre_load_2.lua")                --增加服务加载之前调用
	env_util.add_after_load("./after_load.lua")            --增加服务加载之后调用
	env_util.add_after_load("./after_load_2.lua")            --增加服务加载之后调用
	container_launcher.run()

	skynet.newservice("test_service")
	skynet.exit()
end)