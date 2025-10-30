local skynet = require "skynet"
local log = require "skynet-fly.log"
local frpc_client = require "skynet-fly.client.frpc_client"
local watch_client = require "skynet-fly.rpc.watch_client"
local watch_syn_client = require "skynet-fly.rpc.watch_syn_client"
local timer = require "skynet-fly.timer"
local service = require "skynet.service"
local orm_frpc_client = require "skynet-fly.client.orm_frpc_client"
local CMD = {}

-- 测试基础消息
local function test_base_msg()
	local function test_mode(mode)
		local cli = frpc_client:new(mode, "frpc_s", "test_m") --用简单轮询的方式访问frpc_s的test_m模板
		if mode == frpc_client.FRPC_MODE.byid then
			cli:set_svr_id(1)
		end
		cli:balance_send("hello", "balance_send:" .. mode)
		cli:mod_send("hello","mod_send:" .. mode)
		for i = 1,3 do
			log.info("balance ping ", mode, i, cli:balance_call("ping", i))
		end
		for i = 1,3 do
			log.info("mod ping ", mode, i, cli:mod_call("ping", i))
		end

		cli:broadcast("hello", "broadcast:" .. mode)
		log.info("broadcast_call:", mode, cli:broadcast_call("ping", "broadcast_call:" .. mode))

		cli:set_instance_name("test_one")
		cli:set_svr_id(2)
		cli:balance_send_by_name("hello","balance_send_by_name:" .. mode)
		cli:mod_send_by_name("hello","mod_send_by_name" .. mode)
		for i = 1,3 do
			log.info("balance_call_by_name ping ", mode, i, cli:balance_call_by_name("ping", i))
		end
		for i = 1,3 do
			log.info("mod_call_by_name ping ", mode, i, cli:mod_call_by_name("ping", i))
		end

		cli:broadcast_by_name("hello","broadcast_by_name:" .. mode)
		log.info("broadcast_call_by_name:", mode, cli:broadcast_call_by_name("ping", "broadcast_call_by_name:" .. mode))

		cli = frpc_client:new(mode, "frpc_s", ".testserver_1") --用简单轮询的方式访问frpc_s的.testserver_1别名服务
		if mode == frpc_client.FRPC_MODE.byid then
			cli:set_svr_id(1)
		end
		cli:send_by_alias("hello", "send_by_alias:" .. mode)
		log.info("call_by_alias:", cli:call_by_alias("ping", "call_by_alias:" .. mode))
	end

	test_mode(frpc_client.FRPC_MODE.one)
	test_mode(frpc_client.FRPC_MODE.byid)
	test_mode(frpc_client.FRPC_MODE.all)
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
		for sid, r in pairs(ret.result[1]) do
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

	local function test_large(mode)
		local print_one = print_one_ret
		local print_broad = print_broad_cast_ret
		if mode == frpc_client.FRPC_MODE.all then
			print_one = print_all_one_ret
			print_broad = print_all_broad_cast_ret
		end
		local cli = frpc_client:new(mode, "frpc_s","test_m") --访问frpc_s的test_m模板
		if mode == frpc_client.FRPC_MODE.byid then
			cli:set_svr_id(1)
		end
		cli:balance_send("large_msg", req_list)
		local ret = cli:balance_call("large_msg", req_list)
		print_one("balance_call:" .. mode, ret)
		cli:mod_send("large_msg", req_list)
		local ret = cli:mod_call("large_msg", req_list)
		print_one("mod_call:" .. mode, ret)
		cli:broadcast("large_msg", req_list)
		local ret = cli:broadcast_call("large_msg", req_list)
		print_broad("broadcast_call:" .. mode, ret)
		cli:set_instance_name("test_one")
		cli:balance_send_by_name("large_msg", req_list)
		local ret = cli:balance_call_by_name("large_msg", req_list)
		print_one("balance_call_by_name:" .. mode, ret)
		cli:mod_send_by_name("large_msg", req_list)
		local ret = cli:mod_call_by_name("large_msg", req_list)
		print_one("mod_call_by_name:"..mode, ret)
		cli:broadcast_by_name("large_msg", req_list)
		local ret = cli:broadcast_call_by_name("large_msg", req_list)
		print_broad("broadcast_call_by_name:" .. mode, ret)
	end
	test_large(frpc_client.FRPC_MODE.one)
	test_large(frpc_client.FRPC_MODE.byid)
	test_large(frpc_client.FRPC_MODE.all)
end

--服务掉线测试
local function test_disconnect()
	local cli = frpc_client:new(frpc_client.FRPC_MODE.one,"frpc_s","test_m") --访问frpc_s的test_m模板
	while true do
		log.info("balance ping ", cli:balance_call("ping"))
		skynet.sleep(100)
	end
end

--压测 
local function test_benchmark()
	local cli = frpc_client:new(frpc_client.FRPC_MODE.byid,"frpc_s","test_m") --访问frpc_s的test_m模板
	local max_count = 10000

	local msgsz = 1024
	local msg = ""
	for i = 1, msgsz do
		msg = msg .. math.random(1,9)
	end
	cli:set_svr_id(1)
	local pre_time = skynet.time()
	local co = coroutine.running
	local over_cnt = 0
	for i = 1, max_count do
		skynet.fork(function()
			cli:mod_call("ping", msg)
			over_cnt = over_cnt + 1
			if over_cnt == max_count then
				skynet.wakeup(co)
			end
		end)
	end
	skynet.wait(co)

	log.info("tps:", max_count / (skynet.time() - pre_time))
end

--测试watch_syn活跃同步
local function test_watch_syn()
	local cli = frpc_client:new(frpc_client.FRPC_MODE.one,"frpc_s","test_m") --访问frpc_s的test_m模板
	while true do
		skynet.sleep(100)
		if frpc_client:is_active("frpc_s") then
			log.info("balance ping ", cli:balance_call("ping"))
		else
			log.info("not active")
		end
	end
end

--测试错误处理
local function test_errorcode()
	local cli = frpc_client:new(frpc_client.FRPC_MODE.byid, "frpc_s", "test_m")
	--等待连接超时
	cli:set_svr_id(3)--设置不存在的连接 3
	log.info("test_errorcode 1 >>> ", cli:balance_call("ping", "test_errorcode 1"))

	--对端出错
	cli:set_svr_id(2)
	log.info("test_errorcode 2 >>> ", cli:balance_call("call_error_test"))

	cli = frpc_client:new(frpc_client.FRPC_MODE.all, "frpc_s", "test_m")
	--部分对端出错
	local ret_list, err_list = cli:balance_call("call_same_error_test")
	log.info("test_errorcode 3 >>> ", ret_list, err_list)
end

--测试orm_frpc_client
local function test_orm_frpc_client()
	local cli = orm_frpc_client:new("frpc_s", 1, "player")
	local item_cli = orm_frpc_client:new("frpc_s", 1, "item")
	local function add_cb(one_data)
		log.info("add_cb >>> ", one_data)
	end
	local function del_cb(one_data)
		log.info("del_cb >>> ", one_data)
	end
	local function change_cb(one_data, change_data)
		log.info("change_cb >>> ", one_data, change_data)
	end
	local ret = cli:watch(10001, add_cb, change_cb, del_cb)
	local ret = item_cli:watch(10001, add_cb, change_cb, del_cb)

	skynet.fork(function()
		while true do
			skynet.sleep(200)
			log.info("test_orm_frpc_client get_table player >>>", cli:get_data(10001))
			log.info("test_orm_frpc_client get_table item >>> ", item_cli:get_data(10001))
		end
	end)

	skynet.fork(function()
		skynet.sleep(300)
		log.info("test_orm_frpc_client >>> ", ret)
		local entry = cli:call_orm("create_one_entry", {
			player_id = 10001,
			nickname = 100,
			sex = 1,
			email = "xxx.com"
		})
		log.info("create_one_entry ret >>> ", entry)
		skynet.sleep(300)

		local ret = cli:call_orm("change_save_one_entry", {player_id = 10001, email = "111.com"})
		log.info("change_save_one_entry ret >>> ", ret)
		skynet.sleep(300)

		local ret = cli:call_orm("change_save_one_entry", {player_id = 10001, email = "222.com", nickname = 200})
		log.info("change_save_one_entry ret >>> ", ret)

		skynet.sleep(300)

		local ret = cli:call_orm("delete_entry", 10001)
		log.info("delete_entry >>> ", ret)

		skynet.sleep(300)
		item_cli:call_orm("create_entry", {
			{player_id = 10001, item_id = 1001, count = 1},
			{player_id = 10001, item_id = 1002, count = 1},
			{player_id = 10001, item_id = 1003, count = 1},
		})

		skynet.sleep(300)
		item_cli:call_orm("change_save_entry", {
			{player_id = 10001, item_id = 1001, count = 2},
			{player_id = 10001, item_id = 1002, count = 3},
			{player_id = 10001, item_id = 1003, count = 4},
		})

		skynet.sleep(300)
		item_cli:call_orm("delete_entry", 10001, 1002)
	end)

	skynet.fork(function ()
		skynet.sleep(6000)
		cli:unwatch(10001)
		item_cli:unwatch(10001)
	end)
end

function CMD.start()
	skynet.fork(function()
		--test_base_msg()
		--test_large_msg()
		--test_disconnect()
		--test_benchmark()
		--test_watch_syn()
		--test_errorcode()
		test_orm_frpc_client()
	end)

	-- timer:new(timer.second * 5, 1, function()
	-- 	watch_client.watch("frpc_s", "test_pub", "handle_name2", function(...)
	-- 		log.info("watch msg handle_name2 >>>> ", ...)
	-- 	end)

	-- 	watch_client.unwatch_byid("frpc_s", 1, "test_pub", "handle_name1")

	-- 	watch_client.watch_byid("frpc_s", 1, "test_pub", "handle_name2", function(...)
	-- 		log.info("watch_byid msg handle_name2 >>>> ", ...)
	-- 	end)
		
	-- 	timer:new(timer.second * 5, 1, function()
	-- 		watch_client.unwatch("frpc_s", "test_pub", "handle_name2")
	-- 		watch_client.unwatch("frpc_s", "test_pub", "handle_name1")
			
	-- 		timer:new(timer.second * 5, 1, function()
	-- 			watch_client.unwatch_byid("frpc_s", 1, "test_pub", "handle_name2")
	-- 		end)
	-- 	end)
	-- end)

	-- timer:new(timer.second * 5, 1, function()
	-- 	watch_syn_client.watch("frpc_s", "test_syn", "handle_name2", function(...)
	-- 		log.info("watch msg handle_name2 >>>> ", ...)
	-- 	end)

	-- 	watch_syn_client.unwatch_byid("frpc_s", 1, "test_syn", "handle_name1")

	-- 	watch_syn_client.watch_byid("frpc_s", 1, "test_syn", "handle_name2", function(...)
	-- 		log.info("watch_byid msg handle_name2 >>>> ", ...)
	-- 	end)
		
	-- 	timer:new(timer.second * 5, 1, function()
	-- 		watch_syn_client.unwatch("frpc_s", "test_syn", "handle_name2")
	-- 		watch_syn_client.unwatch("frpc_s", "test_syn", "handle_name1")
			
	-- 		timer:new(timer.second * 5, 1, function()
	-- 			watch_syn_client.unwatch_byid("frpc_s", 1, "test_syn", "handle_name2")
	-- 		end)
	-- 	end)
	-- end)

	-- skynet.fork(function()
	-- 	service.new("test server", function()
	-- 		local CMD = {}
	
	-- 		local skynet = require "skynet"
	-- 		local log = require "skynet-fly.log"
	-- 		local watch_syn_client = require "skynet-fly.rpc.watch_syn_client"
	-- 		local skynet_util = require "skynet-fly.utils.skynet_util"
	
	-- 		-- local watch_client = require "skynet-fly.rpc.watch_client"
	
	-- 		-- watch_syn_client.watch("frpc_s", "test_syn", "handle_name2", function(...)
	-- 		-- 	log.info("watch syn test_syn handle_name2 >>> ", ...)
	-- 		-- end)
	
	-- 		-- watch_client.watch("frpc_s", "test_pub", "handle_name1", function(...)
	-- 		-- 	log.info("watch msg handle_name1 >>>> ", ...)
	-- 		-- end)
	-- 		watch_syn_client.pwatch("frpc_s", "*:age:address", "test server handle-*:age:address", function(cluter_name, ...)
	-- 			log.info("test server handle-*:age:address >>> ", cluter_name, ...)
	-- 		end)

	-- 		watch_syn_client.pwatch_byid("frpc_s", 1, "*:age:address", "test server handle-*:age:address", function(cluter_name, ...)
	-- 			log.info("test server pwatch handle-*:age:address >>> ", cluter_name, ...)
	-- 		end)

	-- 		skynet.sleep(500)
	-- 		watch_syn_client.unpwatch("frpc_s", "*:age:address", "test server handle-*:age:address")
	-- 		watch_syn_client.unpwatch_byid("frpc_s", 1, "*:age:address", "test server handle-*:age:address")

	-- 		skynet_util.lua_dispatch(CMD)
	-- 	end)
	-- end)
	-- timer:new(timer.second * 5, 1, function()
	-- 	watch_syn_client.unpwatch("frpc_s", "*:age:address", "handle-*:age:address")
	-- 	watch_syn_client.unpwatch_byid("frpc_s", 1, "*:age:address", "handle-*:age:address")
	-- end)

	-- timer:new(timer.second * 2, 1, function()
	-- 	watch_syn_client.watch("frpc_s", "name1:age:address", "name1:age:address", function(cluter_name, ...)
	-- 		log.info("watch handle-name1:age:address >>> ", cluter_name, ...)
	-- 	end)

	-- 	watch_syn_client.watch_byid("frpc_s", 1, "name2:age:address", "name2:age:address", function(cluter_name, ...)
	-- 		log.info("watch_byid handle-name2:age:address >>> ", cluter_name, ...)
	-- 	end)
	-- end)

	return true
end

function CMD.exit()
	return true
end

-- watch_client.watch("frpc_s", "test_pub", "handle_name1", function(...)
-- 	log.info("watch msg handle_name1 >>>> ", ...)
-- end)

-- watch_client.watch_byid("frpc_s", 1, "test_pub", "handle_name1", function(...)
-- 	log.info("watch_byid msg handle_name1 >>>> ", ...)
-- end)

-- watch_client.watch_byid("frpc_s", 1, "test_pub_large", "xxxx", function(...)
-- 	log.info("watch_byid test_pub_large ")
-- end)

-- watch_syn_client.watch("frpc_s", "test_syn", "handle_name1", function(...)
-- 	log.info("watch syn test_syn handle_name1 >>> ", ...)
-- end)

-- watch_syn_client.watch("frpc_s", "test_syn", "handle_name3", function(...)
-- 	log.info("watch syn test_syn handle_name3 >>> ", ...)
-- end)

-- watch_client.watch_byid("frpc_s", 1, "test_syn", "handle_name1", function(...)
-- 	log.info("watch_byid msg handle_name1 >>>> ", ...)
-- end)

-- watch_syn_client.pwatch("frpc_s", "*:age:address", "handle-*:age:address", function(cluter_name, ...)
-- 	log.info("pwatch handle-*:age:address >>> ", cluter_name, ...)
-- end)

-- watch_syn_client.pwatch_byid("frpc_s", 1, "*:age:address", "handle-*:age:address", function(cluter_name, ...)
-- 	log.info("pwatch_byid handle-*:age:address >>> ", cluter_name, ...)
-- end)

-- watch_syn_client.pwatch("frpc_s", "name:*:address", "name:*:address", function(cluter_name, ...)
-- 	log.info("pwatch handle-name:*:address >>> ", cluter_name, ...)
-- end)

-- watch_syn_client.pwatch_byid("frpc_s", 1, "name:*:*", "name:*:*", function(cluter_name, ...)
-- 	log.info("pwatch_byid handle-name:*:* >>> ", cluter_name, ...)
-- end)

-- watch_syn_client.pwatch("frpc_s", "*:age:*", "*:age:*", function(cluter_name, ...)
-- 	log.info("pwatch handle-name:*:age:* >>> ", cluter_name, ...)
-- end)

-- watch_syn_client.pwatch_byid("frpc_s", 1, "*:*:address", "*:*:address", function(cluter_name, ...)
-- 	log.info("pwatch_byid handle-*:*:address >>> ", cluter_name, ...)
-- end)

return CMD