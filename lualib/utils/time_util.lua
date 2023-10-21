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
	assert(hour >= 0 and hour <= 23,hour)
	assert(min >= 0 and min <= 59,min)
	assert(sec >= 0 and sec <= 59,sec)
  
	local sub_day_time = day * 86400
	local date = os.date("*t",M.time() + sub_day_time)
	date.hour = hour
	date.min = min
	date.sec = sec
	return os.time(date)
end

--下一分钟的第几秒时间戳
function M.next_min(sec)
	assert(sec >= 0 and sec <= 59)
	local cur_date = M.date()
	cur_date.sec = sec
	local pre_time = os.time(cur_date)
	return pre_time + M.MINUTE
end

--下一小时的第几分钟第几秒
function M.next_hour(min,sec)
	assert(sec >= 0 and sec <= 59)
	assert(min >= 0 and min <= 59)
	local cur_date = M.date()
	cur_date.sec = sec
	cur_date.min = min
	local pre_time = os.time(cur_date)
	return pre_time + M.HOUR
end

--下一天的几点几分几秒
function M.next_day(hour,min,sec)
	assert(hour >= 0 and hour <= 23,hour)
	assert(min >= 0 and min <= 59,min)
	assert(sec >= 0 and sec <= 59,sec)
	local cur_date = M.date()
	cur_date.sec = sec
	cur_date.min = min
	cur_date.hour = hour
	local pre_time = os.time(cur_date)
	return pre_time + M.DAY
end

--下一周的周几几点几分几秒
function M.next_week(wday,hour,min,sec)
	assert(wday >= 1 and wday <= 7)
	assert(hour >= 0 and hour <= 23,hour)
	assert(min >= 0 and min <= 59,min)
	assert(sec >= 0 and sec <= 59,sec)
	local cur_date = M.date()
	cur_date.sec = sec
	cur_date.min = min
	cur_date.hour = hour
	cur_date.day = cur_date.day + 1
	os.date("*t",os.time(cur_date))
	for i = 1,6 do
		if cur_date.wday == wday then
			break
		end
		cur_date.day = cur_date.day + 1
		os.date("*t",os.time(cur_date))
	end
	return os.time(cur_date)
end

--下个月的第几天几时几分几秒
--如果单月没有该天，适配到最后一天
function M.next_month(day,hour,min,sec)
	assert(day >= 1 and day <= 31)
	assert(hour >= 0 and hour < 24,hour)
	assert(min >= 0 and min < 60,min)
	assert(sec >= 0 and sec < 60,sec)

	local cur_date = M.date()
	local next_month = cur_date.month + 1  --直接加没事，os.time会适配到下一年
	cur_date.month = next_month
	cur_date.day = day
	cur_date.hour = hour
	cur_date.min = min
	cur_date.sec = sec
	
	os.date("*t",os.time(cur_date))
	while cur_date.day ~= day do
		day = day - 1
		cur_date.month = next_month
		cur_date.day = day
		cur_date.hour = hour
		cur_date.min = min
		cur_date.sec = sec
		os.date("*t",os.time(cur_date))
	end
	return os.time(cur_date)
end

--下一年的第几月第几天几时几分几秒
--如果单月没有该天，适配到最后一天
function M.next_year(month,day,hour,min,sec)
	assert(month >= 1 and month <= 12)
	assert(day >= 1 and day <= 31)
	assert(hour >= 0 and hour < 24,hour)
	assert(min >= 0 and min < 60,min)
	assert(sec >= 0 and sec < 60,sec)

	local cur_date = M.date()
	cur_date.year = cur_date.year + 1
	cur_date.month = month
	cur_date.day = day
	cur_date.hour = hour
	cur_date.min = min
	cur_date.sec = sec
	os.date("*t",os.time(cur_date))
	while cur_date.day ~= day do
		day = day - 1
		cur_date.month = month
		cur_date.day = day
		cur_date.hour = hour
		cur_date.min = min
		cur_date.sec = sec
		os.date("*t",os.time(cur_date))
	end
	return os.time(cur_date)
end

--下一年的第几天几时几分几秒
--如果单月没有该天，适配到最后一天
function M.next_year_day(yday,hour,min,sec)
	assert(yday >= 1 and yday <= 366)
	assert(hour >= 0 and hour < 24,hour)
	assert(min >= 0 and min < 60,min)
	assert(sec >= 0 and sec < 60,sec)

	local cur_date = M.date()
	cur_date.year = cur_date.year + 1
	local next_year = cur_date.year
	cur_date.month = 1
	cur_date.day = 1
	cur_date.hour = hour
	cur_date.min = min
	cur_date.sec = sec
	os.date("*t",os.time(cur_date))
	for i = 1,365 do
		if cur_date.yday == yday then
			break
		end
		cur_date.day = cur_date.day + 1
		os.date("*t",os.time(cur_date))
		if cur_date.year > next_year then
			cur_date.day = cur_date.day - 1
			break
		end
	end
	return os.time(cur_date)
end

return M