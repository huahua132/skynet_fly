local skynet = require "skynet"
local mod_config = require "mod_config"
local table_util = require "table_util"

skynet.start(function()
	skynet.error("start cluster_server_byredis_1!!!>>>>>>>>>>>>>>>>>")
	local cmgr = skynet.uniqueservice('contriner_mgr')

	skynet.newservice("debug_console", skynet.getenv('debug_port'))
	
	for mod_name,mod_cfg in table_util.sort_ipairs(mod_config,function(a,b)
		return a.launch_seq < b.launch_seq
	end) do
		skynet.call(cmgr,'lua','load_module',mod_name)
	end

	skynet.uniqueservice("cluster_server")
	skynet.exit()
end)