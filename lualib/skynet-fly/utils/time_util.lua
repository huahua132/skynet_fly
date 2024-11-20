local string_util = require "skynet-fly.utils.string_util"
local skynet
local tonumber = tonumber
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
	skynet = skynet or require "skynet"
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
function M.date(time)
	time = time or M.time()
	return os.date("*t",M.time())
end

--string格式的时间转换成date日期table 2023:10:26 19:22:50
function M.string_to_date(str, split1, split2)
	split1 = split1 or " "
	split2 = split2 or ":"
	local datetime = string_util.split(str, split1, split2)
	if #datetime ~= 2 then
		return nil,"err not space"
	end

	if #datetime[1] ~= 3 and #datetime[2] ~= 3 then
		return nil,"err format"
	end

	for i = 1,2 do
		for j = 1,3 do
			datetime[i][j] = tonumber(datetime[i][j])
			if not datetime[i][j] then --说明不是数字
				return nil,"err not number " .. i .. ':' .. j
			end
		end
	end

	local year = datetime[1][1]
	local month = datetime[1][2]
	local day = datetime[1][3]
	local hour = datetime[2][1]
	local min = datetime[2][2]
	local sec = datetime[2][3]

	if year < 1970 then
		return nil,"err year[" .. year .. "]"
	end

	if month < 1 or month > 12 then
		return nil, "err month[" .. month .."]"
	end
	
	if day < 1 or day > 31 then
		return nil, "err day[" .. day .. "]"
	end

	if hour < 0 or hour > 23 then
		return nil, "err hour[" .. hour .. "]"
	end
	
	if min < 0 or min > 59 then
		return nil, "err min[" .. min .. "]"
	end
	
	if sec < 0 or sec > 59 then
		return nil, "err sec[" .. sec .. "]"
	end

	local date = {
		year = year,
		month = month,
		day = day,
		hour = hour,
		min = min,
		sec = sec,
	}

	os.time(date)
	if date.day ~= day then  --这个月没有这一天
		return nil, "not day[" .. day .. "]"
	end

	return date
end

--适配当月最后一天
function M.month_last_day(date, day)
	local year = date.year
	local month = date.month
	date.day = day
	os.time(date)
	while date.day ~= day do
		day = day - 1
		date.day = day
		date.month = month
		date.year = year
		os.time(date)
	end
end

--获取某天某个时间点的时间戳
--比如昨天 8点12分50 参数就是 -1,8,12,50
--明天 0点0分0秒 就是 1，0，0，0
function M.day_time(day,hour,min,sec,curtime)
	assert(day)
	assert(hour >= 0 and hour <= 23,hour)
	assert(min >= 0 and min <= 59,min)
	assert(sec >= 0 and sec <= 59,sec)
  
	local sub_day_time = day * 86400
	curtime = curtime or M.time()
	local date = os.date("*t",curtime + sub_day_time)
	date.hour = hour
	date.min = min
	date.sec = sec
	return os.time(date)
end

--每一分钟的第几秒时间戳
function M.every_min(sec)
	assert(sec >= 0 and sec <= 59)
	local cur_time = M.time()
	local cur_date = M.date(cur_time)
	cur_date.sec = sec
	local next_time = os.time(cur_date)
	if next_time > cur_time then
		--还没过
		return next_time
	else
		--过了
		return next_time + M.MINUTE
	end
end

--每一小时的第几分钟第几秒
function M.every_hour(min,sec)
	assert(sec >= 0 and sec <= 59)
	assert(min >= 0 and min <= 59)
	local cur_time = M.time()
	local cur_date = M.date(cur_time)
	cur_date.sec = sec
	cur_date.min = min
	local next_time = os.time(cur_date)
	if next_time > cur_time then
		return next_time
	else
		return next_time + M.HOUR
	end
end

--每一天的几点几分几秒
function M.every_day(hour,min,sec)
	assert(hour >= 0 and hour <= 23,hour)
	assert(min >= 0 and min <= 59,min)
	assert(sec >= 0 and sec <= 59,sec)
	local cur_time = M.time()
	local cur_date = M.date(cur_time)
	cur_date.sec = sec
	cur_date.min = min
	cur_date.hour = hour
	local next_time = os.time(cur_date)
	if next_time > cur_time then
		return next_time
	else
		return next_time + M.DAY
	end
end

--每一周的周几几点几分几秒
function M.every_week(wday,hour,min,sec)
	assert(wday >= 1 and wday <= 7)
	assert(hour >= 0 and hour <= 23,hour)
	assert(min >= 0 and min <= 59,min)
	assert(sec >= 0 and sec <= 59,sec)
	local cur_time = M.time()
	local cur_date = M.date(cur_time)
	cur_date.sec = sec
	cur_date.min = min
	cur_date.hour = hour

	local next_time = os.time(cur_date)
	for i = 1,7 do
		if cur_date.wday == wday and next_time > cur_time then
			break
		end
		cur_date.day = cur_date.day + 1
		next_time = os.time(cur_date)
	end
	return next_time
end

--每个月的第几天几时几分几秒
--如果单月没有该天，适配到最后一天
function M.every_month(day,hour,min,sec)
	assert(day >= 1 and day <= 31)
	assert(hour >= 0 and hour <= 23,hour)
	assert(min >= 0 and min <= 59,min)
	assert(sec >= 0 and sec <= 59,sec)
	local cur_time = M.time()
	local cur_date = M.date(cur_time)
	cur_date.day = day
	cur_date.hour = hour
	cur_date.min = min
	cur_date.sec = sec
	
	M.month_last_day(cur_date, day)
	local next_time = os.time(cur_date)
	if next_time > cur_time then
		return next_time
	else
		cur_date.month = cur_date.month + 1
		M.month_last_day(cur_date, day)
		return os.time(cur_date)
	end
end

--每一年的第几月第几天几时几分几秒
--如果单月没有该天，适配到最后一天
function M.every_year(month,day,hour,min,sec)
	assert(month >= 1 and month <= 12)
	assert(day >= 1 and day <= 31)
	assert(hour >= 0 and hour <= 23,hour)
	assert(min >= 0 and min <= 59,min)
	assert(sec >= 0 and sec <= 59,sec)
	local cur_time = M.time()
	local cur_date = M.date(cur_time)
	cur_date.month = month
	cur_date.day = day
	cur_date.hour = hour
	cur_date.min = min
	cur_date.sec = sec

	M.month_last_day(cur_date, day)
	local next_time = os.time(cur_date)

	if next_time > cur_time then
		return next_time
	else
		cur_date.year = cur_date.year + 1
		M.month_last_day(cur_date, day)
		return os.time(cur_date)
	end
end

--每一年的第几天几时几分几秒
function M.every_year_day(yday,hour,min,sec)
	assert(yday >= 1 and yday <= 366)
	assert(hour >= 0 and hour <= 23,hour)
	assert(min >= 0 and min <= 59,min)
	assert(sec >= 0 and sec <= 59,sec)
	local cur_time = M.time()
	local cur_date = M.date(cur_time)
	cur_date.hour = hour
	cur_date.min = min
	cur_date.sec = sec
	local next_time = os.time(cur_date)
	for i = cur_date.yday,366 * 2 do
		if cur_date.yday == yday and next_time > cur_time then
			break
		end
		cur_date.day = cur_date.day + 1
		next_time = os.time(cur_date)
	end

	return next_time
end

--是否跨天
function M.is_cross_day(pre_time)
	local next_time = M.day_time(1, 0, 0, 0, pre_time) --传入时间的明天
	local cur_time = M.time()
	if cur_time >= next_time then
		return true
	end
	return false
end

return M