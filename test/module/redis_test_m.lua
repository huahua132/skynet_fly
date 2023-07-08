local log = require "log"
local redis = require "redisf"
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

	local client = redis.new_client("game")
	if not client then
		log.error("new_client err")
	else
		client:publish("monitor:login","welcome login")
		client:publish("monitor:logout","player logout")
		client:publish("pmonitor:chat","player chat")
		client:publish("pmonitor:move","player move")
	end

	if cancel then
		cancel()
	end
	log.info("watch_test test over !!!")
end

local function script_test()
	log.info("script_test test start !!!")
	local client = redis.new_client("game")
	if not client then
		log.error("not script_test ",client)
		return
	end

	log.info(redis.script_run(client,[[return ARGV[2] ]],0,"argv 1","argv 2"))

	log.info("script_test test over !!!")
end

function CMD.start()
	log.info("redis_test_m start !!!")
	client_test()
	watch_test()
	script_test()
	return true
end

function CMD.exit()
	timer:new(timer.minute,1,skynet.exit)
end

return CMD