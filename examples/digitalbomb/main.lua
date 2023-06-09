local skynet = require "skynet"
local mod_config = require "mod_config"
local util = require "util"

skynet.start(function()
	skynet.error("start digitalbomb!!!>>>>>>>>>>>>>>>>>")
	local cmgr = skynet.uniqueservice('contriner_mgr')

	skynet.newservice("debug_console", skynet.getenv('debug_port'))
	
	for mod_name,mod_cfg in util.sort_ipairs(mod_config,function(a,b)
		return a.launch_seq < b.launch_seq
	end) do
		if mod_name ~= "client_m" then
			skynet.call(cmgr,'lua','load_module',mod_name)
		end
	end
	skynet.uniqueservice("login_service")

	if mod_config['client_m'] then
		skynet.call(cmgr,'lua','load_module','client_m')
	end

	skynet.exit()
end)