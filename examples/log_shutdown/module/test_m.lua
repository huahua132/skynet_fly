local log = require "skynet-fly.log"
local skynet = require "skynet"
local timer = require "skynet-fly.timer"

local CMD = {}

--shutdown_mode:
--  on      开启 fatal 自动关服, 打 fatal 触发关服
--  on_off  开启后又关闭, 打 fatal 不触发
--  off     不开启(默认), 打 fatal 不触发
local function test_mode(shutdown_mode)
	log.info("test_m shutdown_mode = ", shutdown_mode)

	if shutdown_mode == "on" then
		log.set_shutdown_when_fatal(true)
		log.info("已开启 fatal 自动关服, 3 秒后打印 fatal 日志触发强制关服 ...")
	elseif shutdown_mode == "on_off" then
		log.set_shutdown_when_fatal(true)
		log.info("已开启 fatal 自动关服, 2 秒后关闭开关再打 fatal ...")
		timer:once(2 * timer.second, function()
			log.set_shutdown_when_fatal(false)
			log.info("已关闭 fatal 自动关服开关")
		end)
	else
		log.info("未开启 fatal 自动关服(默认), 3 秒后打印 fatal 日志, 不应触发关服 ...")
	end

	timer:once(3 * timer.second, function()
		log.fatal("测试 fatal 日志, 若开启开关应触发强制关服!!!")
	end)

	return true
end

function CMD.start(args)
	log.info("test_m start!!!")
	local shutdown_mode = (args and args.shutdown_mode) or "off"
	test_mode(shutdown_mode)
	return true
end

function CMD.exit()
	log.info("test_m exit!!!")
	return true
end

return CMD
