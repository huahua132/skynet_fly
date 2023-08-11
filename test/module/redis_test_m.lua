local log = require "log"
local redis = require "redisf"
require "redisc"
local timer = require "timer"
local skynet = require "skynet"

local CMD = {}

local function client_test()
	log.info("client_test test start !!!")
	local game_cli = redis.new_client("game")
	if game_cli then
		log.info("game set test:",game_cli:set("test",1))
		log.info("game get test:",game_cli:get("test"))
	else
		log.info("game new_client err")
	end

	local hall_cli = redis.new_client("hall")
	if hall_cli then
		log.info("hall get test:",hall_cli:get("test"))
		log.info("hall set test:",hall_cli:set("test",2))
		log.info("hall get test:",hall_cli:get("test"))
	else
		log.info("hall new_client err")
	end
	log.info("client_test test over !!!")
end

local cancel
local function watch_test()
	log.info("watch_test test start !!!")

	local sub_list = {
		"monitor:login",
		"monitor:logout"
	}

	local psub_list = {
		"pmonitor:*"
	}
	
	cancel = redis.new_watch("game",sub_list,psub_list,function(msg,key,pkey)
		log.info("watch:",msg,key,pkey)
	end)

	skynet.sleep(100)
	local client = redis.new_client("game")
	client:publish("monitor:login","welcome login")
	client:publish("monitor:logout","player logout")
	client:publish("pmonitor:chat","player chat")
	client:publish("pmonitor:move","player move")

	skynet.sleep(100)
	if cancel then
		cancel()
	end
	client:publish("pmonitor:move","cancel")
	log.info("watch_test test over !!!")
end

local function script_test()
	log.info("script_test test start !!!")
	local client = redis.new_client("game")

	log.info(client:script_run([[return ARGV[2] ]],0,"argv 1","argv 2"))

	log.info("script_test test over !!!")
end

--过期key监听测试
--需要在redis.conf配置中开启 notify-keyspace-events KA
local function expired_key_watch_test()
	log.info("expired_key_watch_test start !!!")
	local sub_list = {
		"__keyspace@0__:test**"
	}

	local cancel = redis.new_watch("game",{},sub_list,function(msg,key,pkey)
		log.info("expired_key_watch_test:",msg,key,pkey)
	end)

	skynet.sleep(100)
	local gamecli = redis.new_client("game")
	gamecli:set("testkey","testvalue","EX",2)
	gamecli:set("testkeyddd","testvalue","EX",2)
	gamecli:set("tkey","testvalue","EX",2)
end

--断线后执行命令
local function disconnect_test()
	local gamecli = redis.new_client("game")
	skynet.fork(function()
		while true do
			log.info(gamecli:set("test",1))
			--断开后重连还能正常执行
			skynet.sleep(100)
		end
	end)
end

--断线后watch
local function disconnect_watch()
	local sub_list = {
		"testwatch"
	}

	local cli = redis.new_client("game")

	local cancel = redis.new_watch("game",sub_list,{},function(msg,key,pkey)
		log.info("watch:",msg,key,pkey)
	end)

	skynet.fork(function()
		while true do
			cli:publish("testwatch","hello skynet_fly")
			log.error("publish:","testwatch")
			skynet.sleep(100)
		end
	end)
end

--自定义command测试
local function command_test()
	local cli = redis.new_client("game")

	log.info(cli:hmset("testhash",{
		a = 1,
		b = 2,
		c = "s",
	}))

	log.info(cli:hgetall("testhash"))
end

function CMD.start()
	log.info("redis_test_m start !!!")
	--client_test()
	--watch_test()
	--script_test()
	--expired_key_watch_test()
	--disconnect_test()
	--disconnect_watch()
	command_test()
	return true
end

function CMD.exit()
	timer:new(timer.minute,1,skynet.exit)
end

return CMD