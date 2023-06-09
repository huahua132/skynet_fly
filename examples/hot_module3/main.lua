local skynet = require "contriner_client_2"
skynet.start(function()
	--id 重用测试
	skynet.error("start hot_module3!!!>>>>>>>>>>>>>>>>>")
	local cmgr = skynet.uniqueservice('contriner_mgr_2')

	local id_list,server_1_version = skynet.call(cmgr,'lua','load_module',"server_m",1)
	local server_1_id = id_list[1]
	skynet.error("server_1_id:",server_1_id)

	skynet.error(skynet.contriner_mod_call('server_m','ping',skynet.self()))  --发一次消息，查询并缓存了地址
	skynet.call(cmgr,'lua','load_module',"server_m",1)   --server_m更新

	skynet.error("test>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>")
	--注释掉hot_container_2 module名和版本号验证，消息会发到server2_m中处理，本来客户端是想给server_m发的，不符合预期
	for i = 1,50 do
		local tmp_id_list = skynet.call(cmgr,'lua','load_module',"server2_m",1)
		if tmp_id_list[1] == server_1_id then
			skynet.error("server2 重用了server1 之前的id")
			break
		end
		skynet.error(tmp_id_list[1],server_1_id)
		skynet.sleep(100)
	end

	skynet.error(skynet.contriner_mod_call('server_m','ping',skynet.self()))  --过了一段时间又想联系server_m
end)