local skynet = require "skynet"
local mod_config = require "mod_config"
local table_util = require "table_util"

skynet.start(function()
	skynet.error("start ws_digitalbomb!!!>>>>>>>>>>>>>>>>>")
	local cmgr = skynet.uniqueservice('contriner_mgr')

	skynet.newservice("debug_console", skynet.getenv('debug_port'))
	
	for mod_name,mod_cfg in table_util.sort_ipairs(mod_config,function(a,b)
		return a.launch_seq < b.launch_seq
	end) do
		if mod_name ~= "client_m" then
			skynet.call(cmgr,'lua','load_module',mod_name)
		end
	end
	skynet.uniqueservice("room_game_login")

	if mod_config['client_m'] then
		skynet.call(cmgr,'lua','load_module','client_m')
	end

	skynet.exit()
end)