local skynet = require "skynet"
local log = require "skynet-fly.log"
local timer = require "skynet-fly.timer"
local timer_point = require "skynet-fly.time_extend.timer_point"
local time_util = require "skynet-fly.utils.time_util"

local CMD = {}

local function time_out(...)
	log.info("time_out",os.date("%H:%M:%S"),...)
end

function CMD.start(config)
	-- local ti = timer:new(100,5,time_out,"test 1")

	-- local ti_2 = timer:new(100,5,time_out,"test 2")
	-- ti_2:cancel()

	-- local ti_3 = timer:new(100,0,time_out,"test 3")
	-- skynet.sleep(310)
	-- ti_3:cancel()

	-- local ti_4 = timer:new(timer.minute * 2,1,time_out,"test 4")
	-- skynet.sleep(100)
	-- ti_4:cancel()

	-- local ti_5 = timer:new(timer.minute * 2,2,time_out,"test 5")

	-- log.info("test 6 start ",os.date("%H:%M:%S"))
	-- local ti_6 = timer:new(timer.second * 5,2,time_out,"test 6")
	-- skynet.sleep(400)
	-- log.info("extend",ti_6:extend(timer.second * 5))

	-- log.info("test 7 start ",os.date("%H:%M:%S"))
	-- local ti_7 = timer:new(timer.second * 1,2,time_out,"test 7")
	-- skynet.sleep(600)
	-- log.info("extend",ti_7:extend(timer.second * 5))

	-- log.info("test 8 start ",os.date("%H:%M:%S"))
	-- local ti_8 = timer:new(timer.minute * 2,2,time_out,"test 8")
	-- skynet.sleep(600)
	-- log.info("extend",ti_8:extend(timer.second * 5))

	-- log.info("test 9 start ",os.date("%H:%M:%S"))
	-- local ti_9 = timer:new(timer.second * 2,2,time_out,"test 9")
	-- skynet.sleep(600)
	-- log.info("extend",ti_9:extend(timer.second * 5))

	-- log.info("test 10 start ",os.date("%H:%M:%S"))
	-- local ti_10 = timer:new(timer.second * 10,2,function(test_name)
	-- 	time_out(test_name)
	-- 	skynet.sleep(timer.second * 3)
	-- end, "test 10")
	-- skynet.sleep(22)
	-- log.info("test 11 start ",os.date("%H:%M:%S"))
	-- local ti_11 = timer:new(timer.second * 10,2,function(test_name)
	-- 	time_out(test_name)
	-- 	skynet.sleep(timer.second * 3)
	-- end, "test 11")

	--ti_11:after_next()

	local ti_12 = timer_point:new(timer_point.EVERY_MINUTE):set_sec(10):builder(function()
		log.error("每分钟:",os.date("%Y%m%d-%H:%M:%S",time_util.time()))
	end)

	local ti_13 = timer_point:new(timer_point.EVERY_HOUR):set_min(5):set_sec(20):builder(function()
		log.error("每小时:",os.date("%Y%m%d-%H:%M:%S",time_util.time()))
	end)

	local ti_14 = timer_point:new(timer_point.EVERY_DAY):set_hour(6):set_min(5):set_sec(20):builder(function()
		log.error("每天:",os.date("%Y%m%d-%H:%M:%S",time_util.time()))
	end)

	local ti_15 = timer_point:new(timer_point.EVERY_WEEK):set_wday(1):set_hour(6):set_min(5):set_sec(20):builder(function()
		log.error("每周:",os.date("%Y%m%d-%H:%M:%S",time_util.time()))
	end)

	local ti_16 = timer_point:new(timer_point.EVERY_MOUTH):set_day(1):set_hour(6):set_min(5):set_sec(20):builder(function()
		log.error("每月:",os.date("%Y%m%d-%H:%M:%S",time_util.time()))
	end)

	local ti_17 = timer_point:new(timer_point.EVERY_YEAR):set_month(1):set_day(1):set_hour(6):set_min(5):set_sec(20):builder(function()
		log.error("每年:",os.date("%Y%m%d-%H:%M:%S",time_util.time()))
	end)

	local ti_18 = timer_point:new(timer_point.EVERY_YEAR_DAY):set_yday(1):set_hour(6):set_min(5):set_sec(20):builder(function()
		log.error("每年第几天:",os.date("%Y%m%d-%H:%M:%S",time_util.time()))
	end)

	log.info("string_to_date:",time_util.string_to_date("2023:10:27 0:0:0"))

	return true
end

function CMD.exit()
	return true
end

return CMD