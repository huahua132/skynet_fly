local skynet = require "skynet"
local log = require "skynet-fly.log"
local frpc_client = require "skynet-fly.client.frpc_client"
local CMD = {}

function CMD.start()
	skynet.fork(function()
		local cli = frpc_client:new("frpc_server","test_m") --访问frpc_server的test_m模板

		--cli:one_balance_send("hello","one_balance_send")
		-- cli:one_mod_send("hello","one_mod_send")
		-- cli:set_svr_id(1):byid_balance_send("hello","byid_balance_send")
		-- cli:set_svr_id(1):byid_mod_send("hello","byid_mod_send")
		local pre_time = skynet.time()
		for i = 1,10000 do
			log.info("balance ping ", i, cli:one_balance_call("ping"))
		end
		log.info("use time :",10000 / (skynet.time() - pre_time))
		-- for i = 1,3 do
		-- 	log.info("mod ping ",i,cli:one_mod_call("ping"))
		-- end
		-- for i = 1,3 do
		-- 	log.info("byid ping ",i,cli:set_svr_id(2):byid_balance_call("ping"))
		-- end
		-- for i = 1,3 do
		-- 	log.info("byid ping ",i,cli:set_svr_id(1):byid_mod_call("ping"))
		-- end
		
		-- cli:all_mod_send("hello","all_mod_send")
		-- local ret = cli:all_mod_call("ping")
		-- log.info("all_mod_call: ",ret)

		-- cli:all_balance_send("hello","all_balance_send")
		-- local ret = cli:all_balance_call("ping")
		-- log.info("all_balance_call: ",ret)

		-- cli:one_broadcast("hello","one_broadcast")
		-- log.info("one_broadcast_call:", cli:one_broadcast_call("ping"))
		-- cli:all_broadcast("hello","all_broadcast")
		-- log.info("all_broadcast_call:", cli:all_broadcast_call("ping"))
		-- cli:set_svr_id(1):byid_broadcast("hello","byid_broadcast")
		-- log.info("byid_broadcast_call:", cli:set_svr_id(1):byid_broadcast_call("ping"))

		-- cli:set_instance_name("test_one")
		-- cli:set_svr_id(2)
		-- cli:one_balance_send_by_name("hello","one_balance_send_by_name")
		-- cli:one_mod_send_by_name("hello","one_mod_send_by_name")
		-- cli:byid_balance_send_by_name("hello","byid_balance_send_by_name")
		-- cli:byid_mod_send_by_name("hello","byid_mod_send_by_name")

		-- for i = 1,3 do
		-- 	log.info("one_balance_call_by_name ping ",i,cli:one_balance_call_by_name("ping"))
		-- end
		-- for i = 1,3 do
		-- 	log.info("one_mod_call_by_name ping ",i,cli:one_mod_call_by_name("ping"))
		-- end
		-- for i = 1,3 do
		-- 	log.info("byid_balance_call_by_name ping ",i,cli:byid_balance_call_by_name("ping"))
		-- end
		-- for i = 1,3 do
		-- 	log.info("byid_mod_call_by_name ping ",i,cli:byid_mod_call_by_name("ping"))
		-- end

		-- cli:all_mod_send_by_name("hello","all_mod_send_by_name")
		-- local ret = cli:all_mod_call_by_name("ping")
		-- log.info("all_mod_call_by_name: ",ret)

		-- cli:all_balance_send_by_name("hello","all_balance_send_by_name")
		-- local ret = cli:all_balance_call_by_name("ping")
		-- log.info("all_balance_call_by_name: ",ret)

		-- cli:one_broadcast_by_name("hello","one_broadcast_by_name")
		-- log.info("one_broadcast_call_by_name:", cli:one_broadcast_call_by_name("ping"))
		-- cli:all_broadcast_by_name("hello","all_broadcast_by_name")
		-- log.info("all_broadcast_call_by_name:", cli:all_broadcast_call_by_name("ping"))
		-- cli:byid_broadcast_by_name("hello","byid_broadcast_by_name")
		-- log.info("byid_broadcast_call_by_name:", cli:byid_broadcast_call_by_name("ping"))
	end)

	return true
end

function CMD.exit()
	return true
end

return CMD