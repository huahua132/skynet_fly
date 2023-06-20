local skynet = require "skynet"
local contriner_client = require "contriner_client"

skynet.start(function()
	skynet.error("start hot_module5!!!>>>>>>>>>>>>>>>>>")
	local cmgr = skynet.uniqueservice('contriner_mgr')

	skynet.call(cmgr,'lua','load_module',"server_m",1)
	skynet.call(cmgr,'lua','load_module',"agent_m",1)

	contriner_client:new("agent_m",function()
		return false
	end)
	for i = 10001,10002 do
		local player = {
			player_id = i,
			nickname = "player_" .. i
		}
		contriner_client:mod_call("enter",player)
	end
end)