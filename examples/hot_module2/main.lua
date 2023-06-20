local skynet = require "skynet"
skynet.start(function()
	skynet.error("start hot_module2!!!>>>>>>>>>>>>>>>>>")
	local cmgr = skynet.uniqueservice('contriner_mgr')

	skynet.call(cmgr,'lua','load_module',"server_m",1)
	skynet.call(cmgr,'lua','load_module',"client_m",1)

	skynet.sleep(1000)
	skynet.error("update service>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>")
	skynet.call(cmgr,'lua','load_module',"server_m",1)
end)