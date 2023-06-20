local skynet = require "skynet"
local contriner_client = require "contriner_client"

skynet.start(function()
	skynet.error("start hot_module5!!!>>>>>>>>>>>>>>>>>")
	local cmgr = skynet.uniqueservice('contriner_mgr')

	skynet.call(cmgr,'lua','load_module',"service_m",1,{{player_num = 2}})
	skynet.call(cmgr,'lua','load_module',"agent_m",1)

	local client = contriner_client:new("agent_m",function() end)
	for i = 10001,10002 do
		local player = {
			player_id = i,
			nickname = "player_" .. i
		}
		client:mod_call("enter",player)
	end
end)