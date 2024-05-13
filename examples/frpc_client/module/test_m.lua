local skynet = require "skynet"
local log = require "skynet-fly.log"
local frpc_client = require "skynet-fly.client.frpc_client"
local CMD = {}

-- 测试基础消息
local function test_base_msg()
	local cli = frpc_client:new("frpc_server","test_m") --访问frpc_server的test_m模板
	cli:one_balance_send("hello","one_balance_send")
	cli:one_mod_send("hello","one_mod_send")
	cli:set_svr_id(1):byid_balance_send("hello","byid_balance_send")
	cli:set_svr_id(1):byid_mod_send("hello","byid_mod_send")
	for i = 1,3 do
		log.info("balance ping ", i, cli:one_balance_call("ping"))
	end
	for i = 1,3 do
		log.info("mod ping ",i,cli:one_mod_call("ping"))
	end
	for i = 1,3 do
		log.info("byid ping ",i,cli:set_svr_id(2):byid_balance_call("ping"))
	end
	for i = 1,3 do
		log.info("byid ping ",i,cli:set_svr_id(1):byid_mod_call("ping"))
	end
	
	cli:all_mod_send("hello","all_mod_send")
	local ret = cli:all_mod_call("ping")
	log.info("all_mod_call: ",ret)

	cli:all_balance_send("hello","all_balance_send")
	local ret = cli:all_balance_call("ping")
	log.info("all_balance_call: ",ret)

	cli:one_broadcast("hello","one_broadcast")
	log.info("one_broadcast_call:", cli:one_broadcast_call("ping"))
	cli:all_broadcast("hello","all_broadcast")
	log.info("all_broadcast_call:", cli:all_broadcast_call("ping"))
	cli:set_svr_id(1):byid_broadcast("hello","byid_broadcast")
	log.info("byid_broadcast_call:", cli:set_svr_id(1):byid_broadcast_call("ping"))

	cli:set_instance_name("test_one")
	cli:set_svr_id(2)
	cli:one_balance_send_by_name("hello","one_balance_send_by_name")
	cli:one_mod_send_by_name("hello","one_mod_send_by_name")
	cli:byid_balance_send_by_name("hello","byid_balance_send_by_name")
	cli:byid_mod_send_by_name("hello","byid_mod_send_by_name")

	for i = 1,3 do
		log.info("one_balance_call_by_name ping ",i,cli:one_balance_call_by_name("ping"))
	end
	for i = 1,3 do
		log.info("one_mod_call_by_name ping ",i,cli:one_mod_call_by_name("ping"))
	end
	for i = 1,3 do
		log.info("byid_balance_call_by_name ping ",i,cli:byid_balance_call_by_name("ping"))
	end
	for i = 1,3 do
		log.info("byid_mod_call_by_name ping ",i,cli:byid_mod_call_by_name("ping"))
	end

	cli:all_mod_send_by_name("hello","all_mod_send_by_name")
	local ret = cli:all_mod_call_by_name("ping")
	log.info("all_mod_call_by_name: ",ret)

	cli:all_balance_send_by_name("hello","all_balance_send_by_name")
	local ret = cli:all_balance_call_by_name("ping")
	log.info("all_balance_call_by_name: ",ret)

	cli:one_broadcast_by_name("hello","one_broadcast_by_name")
	log.info("one_broadcast_call_by_name:", cli:one_broadcast_call_by_name("ping"))
	cli:all_broadcast_by_name("hello","all_broadcast_by_name")
	log.info("all_broadcast_call_by_name:", cli:all_broadcast_call_by_name("ping"))
	cli:byid_broadcast_by_name("hello","byid_broadcast_by_name")
	log.info("byid_broadcast_call_by_name:", cli:byid_broadcast_call_by_name("ping"))
end

--测试大包消息
local function test_large_msg()
	local req_list = {}
	for i = 1,20000 do
		table.insert(req_list, i)
	end

	local function print_one_ret(name, ret)
		log.info(name, ret.cluster_name, #ret.result[1])
	end

	local function print_broad_cast_ret(name, ret)
		for sid, r in pairs(ret.result) do
			log.info(name, ret.cluster_name, sid, #r[1])
		end
	end

	local function print_all_one_ret(name, ret)
		for _,one_ret in ipairs(ret) do
			print_one_ret(name, one_ret)
		end
	end

	local function print_all_broad_cast_ret(name, ret)
		for k,v in pairs(ret) do
			print_broad_cast_ret(name,v)
		end
	end

	req_list = table.concat(req_list, ',')
	local cli = frpc_client:new("frpc_server","test_m") --访问frpc_server的test_m模板
	cli:one_balance_send("large_msg", req_list)
 	local ret = cli:one_balance_call("large_msg", req_list)
	print_one_ret("one_balance_call:", ret)

	cli:one_mod_send("large_msg", req_list)
	local ret = cli:one_mod_call("large_msg", req_list)
	print_one_ret("one_balance_call:", ret)

	cli:one_broadcast("large_msg", req_list)
	local ret = cli:one_broadcast_call("large_msg", req_list)
	print_broad_cast_ret("one_broadcast_call", ret)

	cli:set_svr_id(1)
	cli:byid_balance_send("large_msg", req_list)
	local ret = cli:byid_balance_call("large_msg", req_list)
	print_one_ret("byid_balance_call:", ret)

	cli:byid_mod_send("large_msg", req_list)
	local ret = cli:byid_mod_call("large_msg", req_list)
	print_one_ret("byid_balance_call:", ret)

	cli:byid_broadcast("large_msg", req_list)
	local ret = cli:byid_broadcast_call("large_msg", req_list)
	print_broad_cast_ret("byid_broadcast_call", ret)

	cli:all_balance_send("large_msg", req_list)
	local ret = cli:all_balance_call("large_msg", req_list)
	print_all_one_ret("all_balance_call:", ret)

	cli:all_mod_send("large_msg", req_list)
	local ret = cli:all_mod_call("large_msg", req_list)
	print_all_one_ret("all_mod_call:", ret)

	cli:all_broadcast("large_msg", req_list)
	local ret = cli:all_broadcast_call("large_msg", req_list)
	print_all_broad_cast_ret("all_broadcast_call", ret)

	cli:set_instance_name("test_one")

	cli:one_balance_send_by_name("large_msg", req_list)
	local ret = cli:one_balance_call_by_name("large_msg", req_list)
   print_one_ret("one_balance_call_by_name:", ret)

   cli:one_mod_send_by_name("large_msg", req_list)
   local ret = cli:one_mod_call_by_name("large_msg", req_list)
   print_one_ret("one_mod_call_by_name:", ret)

   cli:one_broadcast_by_name("large_msg", req_list)
   local ret = cli:one_broadcast_call_by_name("large_msg", req_list)
   print_broad_cast_ret("one_broadcast_call_by_name", ret)

   cli:set_svr_id(1)
   cli:byid_balance_send_by_name("large_msg", req_list)
   local ret = cli:byid_balance_call_by_name("large_msg", req_list)
   print_one_ret("byid_balance_call_by_name:", ret)

   cli:byid_mod_send_by_name("large_msg", req_list)
   local ret = cli:byid_mod_call_by_name("large_msg", req_list)
   print_one_ret("byid_mod_call_by_name:", ret)

   cli:byid_broadcast_by_name("large_msg", req_list)
   local ret = cli:byid_broadcast_call_by_name("large_msg", req_list)
   print_broad_cast_ret("byid_broadcast_call_by_name", ret)

   cli:all_balance_send_by_name("large_msg", req_list)
   local ret = cli:all_balance_call_by_name("large_msg", req_list)
   print_all_one_ret("all_balance_call_by_name:", ret)

   cli:all_mod_send_by_name("large_msg", req_list)
   local ret = cli:all_mod_call_by_name("large_msg", req_list)
   print_all_one_ret("all_mod_call_by_name:", ret)

   cli:all_broadcast_by_name("large_msg", req_list)
   local ret = cli:all_broadcast_call_by_name("large_msg", req_list)
   print_all_broad_cast_ret("all_broadcast_call_by_name", ret)
end

--服务掉线测试
local function test_disconnect()
	local cli = frpc_client:new("frpc_server","test_m") --访问frpc_server的test_m模板
	while true do
		log.info("balance ping ", cli:one_balance_call("ping"))
		skynet.sleep(100)
	end
end

function CMD.start()
	skynet.fork(function()
		--test_base_msg()
		--test_large_msg()
		test_disconnect()
	end)

	return true
end

function CMD.exit()
	return true
end

return CMD