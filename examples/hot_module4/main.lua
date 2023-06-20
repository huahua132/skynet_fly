local skynet = require "skynet"
local contriner_client = require "contriner_client"
skynet.start(function()
	skynet.error("start hot_module4!!!>>>>>>>>>>>>>>>>>")
	local cmgr = skynet.uniqueservice('contriner_mgr')

	skynet.call(cmgr,'lua','load_module',"server_m",1)

	skynet.fork(function()
		local cnt = 1
		local client = contriner_client:new("server_m",function()
			return cnt > 8
		end)
		while cnt <= 10 do
			cnt = cnt + 1
			skynet.error("ping:",client:mod_call('ping',skynet.self()))
			skynet.sleep(100)
		end
		skynet.exit()
	end)

	skynet.sleep(500)
	skynet.error("update service>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>")
	skynet.call(cmgr,'lua','load_module',"server_m",1)
	skynet.error("over !!!")
end)