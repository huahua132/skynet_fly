local skynet = require "skynet"

local math = math
local assert = assert
local os = os

local M = {}

local starttime
--整型的skynet_time 
function M.skynet_int_time()
	if not starttime then
		starttime = math.floor(skynet.starttime() * 100)
	end
	return skynet.now() + starttime
end

--获取某天某个时间点的时间戳
--比如昨天 8点12分50 参数就是 -1,8,12,50
--明天 0点0分0秒 就是 1，0，0，0
function M.day_time(day,hour,min,sec)
	assert(day)
	assert(hour >= 0 and hour <= 24,hour)
	assert(min >= 0 and min <= 60,min)
	assert(sec >= 0 and sec <= 60,sec)
  
	local sub_day_time = day * 86400
	local date = os.date("*t",os.time() + sub_day_time)
	date.hour = hour
	date.min = min
	date.sec = sec
	return os.time(date)
  end

return M