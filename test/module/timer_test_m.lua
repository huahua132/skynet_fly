local skynet = require "skynet"
local log = require "log"
local timer = require "timer"

local CMD = {}

local function time_out(...)
	log.info("time_out",os.date("%H:%M:%S"),...)
end

function CMD.start(config)
	local ti = timer:new(100,5,time_out,"test 1")

	local ti_2 = timer:new(100,5,time_out,"test 2")
	ti_2:cancel()

	local ti_3 = timer:new(100,0,time_out,"test 3")
	skynet.sleep(310)
	ti_3:cancel()

	local ti_4 = timer:new(timer.minute * 2,1,time_out,"test 4")
	skynet.sleep(100)
	ti_4:cancel()

	local ti_5 = timer:new(timer.minute * 2,2,time_out,"test 5")

	log.info("test 6 start ",os.date("%H:%M:%S"))
	local ti_6 = timer:new(timer.second * 5,2,time_out,"test 6")
	skynet.sleep(400)
	log.info("extend",ti_6:extend(timer.second * 5))

	log.info("test 7 start ",os.date("%H:%M:%S"))
	local ti_6 = timer:new(timer.second * 1,2,time_out,"test 7")
	skynet.sleep(600)
	log.info("extend",ti_6:extend(timer.second * 5))

	log.info("test 8 start ",os.date("%H:%M:%S"))
	local ti_6 = timer:new(timer.minute * 2,2,time_out,"test 8")
	skynet.sleep(600)
	log.info("extend",ti_6:extend(timer.second * 5))

	log.info("test 9 start ",os.date("%H:%M:%S"))
	local ti_6 = timer:new(timer.second * 2,2,time_out,"test 9")
	skynet.sleep(600)
	log.info("extend",ti_6:extend(timer.second * 5))
	return true
end

function CMD.exit()

end

return CMD