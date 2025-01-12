--@API
--@content ---
--@content title: time_util 时间相关
--@content date: 2024-06-29 22:00:00
--@content categories: ["skynet_fly API 文档","工具函数"]
--@content category_bar: true
--@content tags: [skynet_fly_api]
--@content ---
--@content [time_util](https://github.com/huahua132/skynet_fly/blob/master/lualib/skynet-fly/utils/time_util.lua)
local string_util = require "skynet-fly.utils.string_util"
local skynet
local tonumber = tonumber
local tostring = tostring
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
--@desc 获取当前时间戳
--@return number 时间戳(秒*100)
function M.skynet_int_time()
	skynet = skynet or require "skynet"
	if not starttime then
		starttime = math.floor(skynet.starttime() * 100)
	end
	return skynet.now() + starttime
end

--@desc 获取当前时间戳
--@return number 时间戳(秒)
function M.time()
	return math.floor(M.skynet_int_time() / 100)
end

--@desc 获取当前日期
--@return table 日期格式的table{year=2025,month=1,day=11,hour=18,min=12,sec=50}
function M.date(time)
	time = time or M.time()
	return os.date("*t",M.time())
end

--@desc string格式的时间转换成date日期table 2023:10:26 19:22:50
--@param string str 被分割的时间格式字符串
--@param string split1 分割符1 默认" "
--@param string split2 分割符2 默认 ":"
--@return table 分割后的内容
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

--适配当月某一天
--@desc 适配当月到某一天，不存在，适配到最后一天，比如2月只有28或者29，当输入30或者31将适配到28或者29天
--@param table date[os.date] 日期
--@param number day[1,31] 当月哪天
function M.month_day(date, day)
	assert(day >= 1 and day <= 31, "Must be within this range[1,31] day=" .. tostring(day))
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

--@desc 获取某天某个时间点的时间戳 比如昨天 8点12分50 参数就是 -1,8,12,50 明天 0点0分0秒 就是 1，0，0，0
--@param number day 相差几天
--@param number hour[0,23] 几时
--@param number min[0,59] 几分
--@param number sec[0,59] 几秒
--@return number 时间戳
function M.day_time(day, hour, min, sec, curtime)
	assert(day, "not day param")
	assert(hour >= 0 and hour <= 23, "Must be within this range[0,23] hour=" .. tostring(hour))
	assert(min >= 0 and min <= 59, "Must be within this range[0,59] min=" .. tostring(min))
	assert(sec >= 0 and sec <= 59, "Must be within this range[0,59] sec=" .. tostring(sec))
  
	local sub_day_time = day * 86400
	curtime = curtime or M.time()
	local date = os.date("*t",curtime + sub_day_time)
	date.hour = hour
	date.min = min
	date.sec = sec
	return os.time(date)
end

--@desc 获取下一个每分的几秒时间戳
--@param number sec[0,59] 几秒
--@return number 时间戳
function M.every_min(sec)
	assert(sec >= 0 and sec <= 59, "Must be within this range[0,59] sec=" .. tostring(sec))
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

--@desc 获取下一个每时的几分几秒时间戳
--@param number min[0,59] 几分
--@param number sec[0,59] 几秒
--@return number 时间戳
function M.every_hour(min, sec)
	assert(min >= 0 and min <= 59, "Must be within this range[0,59] min=" .. tostring(min))
	assert(sec >= 0 and sec <= 59, "Must be within this range[0,59] sec=" .. tostring(sec))
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

--@desc 获取下一个每天的几点几分几秒时间戳
--@param number hour[0,23] 几时
--@param number min[0,59] 几分
--@param number sec[0,59] 几秒
--@return number 时间戳
function M.every_day(hour, min, sec)
	assert(hour >= 0 and hour <= 23, "Must be within this range[0,23] hour=" .. tostring(hour))
	assert(min >= 0 and min <= 59, "Must be within this range[0,59] min=" .. tostring(min))
	assert(sec >= 0 and sec <= 59, "Must be within this range[0,59] sec=" .. tostring(sec))
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

--@desc 获取下一个周几几点几分几秒的时间戳
--@param number wday[1,7] 周几
--@param number hour[0,23] 几时
--@param number min[0,59] 几分
--@param number sec[0,59] 几秒
--@return number 时间戳
function M.every_week(wday, hour, min, sec)
	assert(wday >= 1 and wday <= 7, "Must be within this range[1,7] wday=" .. tostring(wday))
	assert(hour >= 0 and hour <= 23, "Must be within this range[0,23] hour=" .. tostring(hour))
	assert(min >= 0 and min <= 59, "Must be within this range[0,59] min=" .. tostring(min))
	assert(sec >= 0 and sec <= 59, "Must be within this range[0,59] sec=" .. tostring(sec))
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

--@desc 获取下一个每月的第几天几时几分几秒的时间戳，如果单月没有该天，适配到最后一天
--@param number day[1,31] 第几天
--@param number hour[0,23] 几时
--@param number min[0,59] 几分
--@param number sec[0,59] 几秒
--@return number 时间戳
function M.every_month(day, hour, min, sec)
	assert(day >= 1 and day <= 31, "Must be within this range[1,31] day=" .. tostring(day))
	assert(hour >= 0 and hour <= 23, "Must be within this range[0,23] hour=" .. tostring(hour))
	assert(min >= 0 and min <= 59, "Must be within this range[0,59] min=" .. tostring(min))
	assert(sec >= 0 and sec <= 59, "Must be within this range[0,59] sec=" .. tostring(sec))
	local cur_time = M.time()
	local cur_date = M.date(cur_time)
	cur_date.day = day
	cur_date.hour = hour
	cur_date.min = min
	cur_date.sec = sec
	
	M.month_day(cur_date, day)
	local next_time = os.time(cur_date)
	if next_time > cur_time then
		return next_time
	else
		cur_date.month = cur_date.month + 1
		M.month_day(cur_date, day)
		return os.time(cur_date)
	end
end

--@desc 获取下一个每年的第几月第几天几时几分几秒的时间戳，如果单月没有该天，适配到最后一天
--@param number month[1,12] 第几月
--@param number day[1,31] 第几天
--@param number hour[0,23] 几时
--@param number min[0,59] 几分
--@param number sec[0,59] 几秒
--@return number 时间戳
function M.every_year(month, day, hour, min, sec)
	assert(month >= 1 and month <= 12, "Must be within this range[1,12] month=" .. tostring(month))
	assert(day >= 1 and day <= 31, "Must be within this range[1,31] day=" .. tostring(day))
	assert(hour >= 0 and hour <= 23, "Must be within this range[0,23] hour=" .. tostring(hour))
	assert(min >= 0 and min <= 59, "Must be within this range[0,59] min=" .. tostring(min))
	assert(sec >= 0 and sec <= 59, "Must be within this range[0,59] sec=" .. tostring(sec))
	local cur_time = M.time()
	local cur_date = M.date(cur_time)
	cur_date.month = month
	cur_date.day = day
	cur_date.hour = hour
	cur_date.min = min
	cur_date.sec = sec

	M.month_day(cur_date, day)
	local next_time = os.time(cur_date)

	if next_time > cur_time then
		return next_time
	else
		cur_date.year = cur_date.year + 1
		M.month_day(cur_date, day)
		return os.time(cur_date)
	end
end

--@desc 获取下一个每年的第几天几时几分几秒的时间戳
--@param number yday[1,366] 第几天
--@param number hour[0,23] 几时
--@param number min[0,59] 几分
--@param number sec[0,59] 几秒
--@return number 时间戳
function M.every_year_day(yday, hour, min, sec)
	assert(yday >= 1 and yday <= 366, "Must be within this range[1,366] yday=" .. tostring(yday))
	assert(hour >= 0 and hour <= 23, "Must be within this range[0,23] hour=" .. tostring(hour))
	assert(min >= 0 and min <= 59, "Must be within this range[0,59] min=" .. tostring(min))
	assert(sec >= 0 and sec <= 59, "Must be within this range[0,59] sec=" .. tostring(sec))
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

--@desc 是否跨天
--@param number pre_time 之前记录的时间
--@param number cur_time 当前时间(可选 默认当前时间)
--@param number hour[0,23] 几点算一天的开始(可选 默认零点)
--@return bool 是否跨天
function M.is_cross_day(pre_time, cur_time, hour)
	hour = hour or 0
	assert(hour >= 0 and hour <= 23, "Must be within this range[0,23] hour=" .. tostring(hour))
	
	local pre_cross_time = M.day_time(0, hour, 0, 0, pre_time) --之前的跨天时间点
	if pre_cross_time <= pre_time then					       --大于当天跨天点，用下一天跨天点
		pre_cross_time = pre_cross_time + 86400				      
	end
	local cur_time = cur_time or M.time()
	if cur_time >= pre_cross_time then
		return true
	end
	return false
end

--@desc 计算pre_time(更小) cur_time(更大) 相差几天
--@param number pre_time 之前记录的时间
--@param number cur_time 当前时间(可选 默认当前时间)
--@param number hour[0,23] 几点算一天的开始(可选 默认零点)
--@return number 相差几天
function M.diff_day(pre_time, cur_time, hour)
	hour = hour or 0
	assert(hour >= 0 and hour <= 23, "Must be within this range[0,23] hour=" .. tostring(hour))
	local cur_time = cur_time or M.time()
	local pre_cross_time = M.day_time(0, hour, 0, 0, pre_time) --之前的跨天时间点
	if pre_cross_time <= pre_time then					       --大于当天跨天点，用下一天跨天点
		pre_cross_time = pre_cross_time + 86400				      
	end
	local cur_cross_time = M.day_time(0, hour, 0, 0, cur_time) --现在的跨天时间点
	if cur_cross_time <= cur_time then						   --大于当天跨天点，用下一天跨天点
		cur_cross_time = cur_cross_time + 86400
	end
	local sub_day = math.floor((cur_cross_time - pre_cross_time) / 86400)
	return sub_day
end

return M