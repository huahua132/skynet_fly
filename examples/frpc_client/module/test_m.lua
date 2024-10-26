local skynet = require "skynet"
local log = require "skynet-fly.log"
local frpc_client = require "skynet-fly.client.frpc_client"
local watch_client = require "skynet-fly.rpc.watch_client"
local watch_syn_client = require "skynet-fly.rpc.watch_syn_client"
local timer = require "skynet-fly.timer"
local service = require "skynet.service"
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

	--测试通过别名发送
	local cli = frpc_client:new("frpc_server",".testserver_1")
	cli:one_send_by_name("hello", "one_send_by_name")
	log.info("one_call_by_name:", cli:one_call_by_name("ping"))
	cli:set_svr_id(2)
	cli:byid_send_by_name("hello", "byid_send_by_name")
	log.info("byid_call_by_name:", cli:byid_call_by_name("ping"))
	cli:all_send_by_name("hello", "all_send_by_name")
	log.info("all_send_by_name:", cli:all_call_by_name("ping"))
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

--压测 
local function test_benchmark()
	local cli = frpc_client:new("frpc_server","test_m") --访问frpc_server的test_m模板
	local max_count = 10000

	local msgsz = 1024
	local msg = ""
	for i = 1, msgsz do
		msg = msg .. math.random(1,9)
	end
	
	local pre_time = skynet.time()
	for i = 1, max_count do
		cli:set_svr_id(1):byid_mod_call("ping", msg)
	end

	log.info("tps:", max_count / (skynet.time() - pre_time))
end

--测试watch_syn活跃同步
local function test_watch_syn()
	local cli = frpc_client:new("frpc_server","test_m") --访问frpc_server的test_m模板
	while true do
		skynet.sleep(100)
		if frpc_client:is_active("frpc_server") then
			log.info("balance ping ", cli:one_balance_call("ping"))
		else
			log.info("not active")
		end
	end
end

function CMD.start()
	skynet.fork(function()
		test_base_msg()
		--test_large_msg()
		--test_disconnect()
		--test_benchmark()
		--test_watch_syn()
	end)

	timer:new(timer.second * 5, 1, function()
		watch_client.watch("frpc_server", "test_pub", "handle_name2", function(...)
			log.info("watch msg handle_name2 >>>> ", ...)
		end)

		watch_client.unwatch_byid("frpc_server", 1, "test_pub", "handle_name1")

		watch_client.watch_byid("frpc_server", 1, "test_pub", "handle_name2", function(...)
			log.info("watch_byid msg handle_name2 >>>> ", ...)
		end)
		
		timer:new(timer.second * 5, 1, function()
			watch_client.unwatch("frpc_server", "test_pub", "handle_name2")
			watch_client.unwatch("frpc_server", "test_pub", "handle_name1")
			
			timer:new(timer.second * 5, 1, function()
				watch_client.unwatch_byid("frpc_server", 1, "test_pub", "handle_name2")
			end)
		end)
	end)

	timer:new(timer.second * 5, 1, function()
		watch_syn_client.watch("frpc_server", "test_syn", "handle_name2", function(...)
			log.info("watch msg handle_name2 >>>> ", ...)
		end)

		watch_syn_client.unwatch_byid("frpc_server", 1, "test_syn", "handle_name1")

		watch_syn_client.watch_byid("frpc_server", 1, "test_syn", "handle_name2", function(...)
			log.info("watch_byid msg handle_name2 >>>> ", ...)
		end)
		
		timer:new(timer.second * 5, 1, function()
			watch_syn_client.unwatch("frpc_server", "test_syn", "handle_name2")
			watch_syn_client.unwatch("frpc_server", "test_syn", "handle_name1")
			
			timer:new(timer.second * 5, 1, function()
				watch_syn_client.unwatch_byid("frpc_server", 1, "test_syn", "handle_name2")
			end)
		end)
	end)

	skynet.fork(function()
		service.new("test server", function()
			local CMD = {}
	
			local skynet = require "skynet"
			local log = require "skynet-fly.log"
			local watch_syn_client = require "skynet-fly.rpc.watch_syn_client"
			local skynet_util = require "skynet-fly.utils.skynet_util"
			skynet_util.set_cmd_table(CMD)
	
			local watch_client = require "skynet-fly.rpc.watch_client"
	
			watch_syn_client.watch("frpc_server", "test_syn", "handle_name2", function(...)
				log.info("watch syn test_syn handle_name2 >>> ", ...)
			end)
	
			watch_client.watch("frpc_server", "test_pub", "handle_name1", function(...)
				log.info("watch msg handle_name1 >>>> ", ...)
			end)
			skynet_util.lua_dispatch(CMD)
		end)
	end)

	return true
end

function CMD.exit()
	return true
end

watch_client.watch("frpc_server", "test_pub", "handle_name1", function(...)
	log.info("watch msg handle_name1 >>>> ", ...)
end)

watch_client.watch_byid("frpc_server", 1, "test_pub", "handle_name1", function(...)
	log.info("watch_byid msg handle_name1 >>>> ", ...)
end)

watch_client.watch_byid("frpc_server", 1, "test_pub_large", "xxxx", function(...)
	log.info("watch_byid test_pub_large ")
end)

watch_syn_client.watch("frpc_server", "test_syn", "handle_name1", function(...)
	log.info("watch syn test_syn handle_name1 >>> ", ...)
end)

watch_syn_client.watch("frpc_server", "test_syn", "handle_name3", function(...)
	log.info("watch syn test_syn handle_name3 >>> ", ...)
end)

watch_client.watch_byid("frpc_server", 1, "test_syn", "handle_name1", function(...)
	log.info("watch_byid msg handle_name1 >>>> ", ...)
end)

return CMD