local skynet = require "skynet"
local mod_config = require "mod_config"
local table_util = require "table_util"
local env_util = require "env_util"

skynet.start(function()
	skynet.error("start pre_after_load!!!>>>>>>>>>>>>>>>>>")
	env_util.add_pre_load("./pre_load.lua")                --增加服务加载之前调用
	env_util.add_pre_load("./pre_load_2.lua")                --增加服务加载之前调用
	env_util.add_after_load("./after_load.lua")            --增加服务加载之后调用
	env_util.add_after_load("./after_load_2.lua")            --增加服务加载之后调用

	local cmgr = skynet.uniqueservice('contriner_mgr')

	skynet.newservice("debug_console", skynet.getenv('debug_port'))

	for mod_name,mod_cfg in table_util.sort_ipairs(mod_config,function(a,b)
		return a.launch_seq < b.launch_seq
	end) do
		skynet.call(cmgr,'lua','load_module',mod_name)
	end

	skynet.newservice("test_service")
	skynet.exit()
end)