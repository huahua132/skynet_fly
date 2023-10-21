local skynet = require "skynet"

local math = math
local assert = assert
local os = os

local M = {
	--1分钟 
	MINUTE = 60,
	--1小时
	HOUR = 60 * 60,
	--1天
	DAY = 60 * 60 * 24,
}

local starttime
--整型的skynet_time 
function M.skynet_int_time()
	if not starttime then
		starttime = math.floor(skynet.starttime() * 100)
	end
	return skynet.now() + starttime
end

--秒时间戳
function M.time()
	return math.floor(M.skynet_int_time() / 100)
end

--当前日期
function M.date()
	return os.date("*t",M.time())
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
	local date = os.date("*t",M.time() + sub_day_time)
	date.hour = hour
	date.min = min
	date.sec = sec
	return os.time(date)
end

--下一分钟的时间戳
function M.next_min()
	local cur_date = M.date()
	cur_date.sec = 0
	local pre_time = os.time(cur_date)
	return pre_time + M.MINUTE
end

--下一小时的时间戳
function M.next_hour()
	local cur_date = M.date()
	cur_date.sec = 0
	cur_date.min = 0
	local pre_time = os.time(cur_date)
	return pre_time + M.HOUR
end

--下一天的时间戳
function M.next_day()
	local cur_date = M.date()
	cur_date.sec = 0
	cur_date.min = 0
	cur_date.hour = 0
	local pre_time = os.time(cur_date)
	return pre_time + M.DAY
end

return M