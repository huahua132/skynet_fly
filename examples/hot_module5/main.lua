local skynet = require "skynet"

skynet.start(function()
	skynet.error("start hot_module5!!!>>>>>>>>>>>>>>>>>")
	local cmgr = skynet.uniqueservice('contriner_mgr')

	skynet.call(cmgr,'lua','load_module',"service_m",1,{{player_num = 2,min_num = 1,max_num = 100}})
	skynet.call(cmgr,'lua','load_module',"agent_m",2,{
		{player_id = 10001,nickname = "张三"},
		{player_id = 10002,nickname = "李四"},
	})
	
	skynet.call(cmgr,'lua','load_module',"service_m",1,{{player_num = 2,min_num = 100,max_num = 200}})
end)