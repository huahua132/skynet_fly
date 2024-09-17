--整点报时
local skynet = require "skynet"
local timer = require "skynet-fly.timer"
local time_util = require "skynet-fly.utils.time_util"

local tostring = tostring
local assert = assert
local pairs = pairs
local setmetatable = setmetatable
local rawget = rawget
local rawset = rawset

local M = {
    --每分钟
    EVERY_MINUTE = 1,
    --每小时
    EVERY_HOUR = 2,
    --每天
    EVERY_DAY = 3,
    --每周
    EVERY_WEEK = 4,
    --每月 超过适配到最后一天
    EVERY_MOUTH = 5,
    --每年几月几日几时几分几秒 超过适配到最后一天
    EVERY_YEAR = 6,
    --每年的第几天 超过适配到最后一天
    EVERY_YEAR_DAY = 7,
}

local g_type_map = {}
do 
    for _,type in pairs(M) do
        g_type_map[type] = true
    end
end

local TYPE_REMAIN_TIME_FUNC = {
    [M.EVERY_MINUTE] = function(month,day,hour,min,sec,wday,yday)
        local cur_time = time_util.time()
        local next_time = time_util.every_min(sec)
        return next_time - cur_time
    end,
    [M.EVERY_HOUR] = function(month,day,hour,min,sec,wday,yday)
        local cur_time = time_util.time()
        local next_time = time_util.every_hour(min,sec)
        return next_time - cur_time
    end,
    [M.EVERY_DAY] = function(month,day,hour,min,sec,wday,yday)
        local cur_time = time_util.time()
        local next_time = time_util.every_day(hour,min,sec)
        return next_time - cur_time
    end,
    [M.EVERY_WEEK] = function(month,day,hour,min,sec,wday,yday)
        local cur_time = time_util.time()
        local next_time = time_util.every_week(wday,hour,min,sec)
        return next_time - cur_time
    end,
    [M.EVERY_MOUTH] = function(month,day,hour,min,sec,wday,yday)
        local cur_time = time_util.time()
        local next_time = time_util.every_month(day,hour,min,sec)
        return next_time - cur_time
    end,
    [M.EVERY_YEAR] = function(month,day,hour,min,sec,wday,yday)
        local cur_time = time_util.time()
        local next_time = time_util.every_year(month,day,hour,min,sec)
        return next_time - cur_time
    end,
    [M.EVERY_YEAR_DAY] = function(month,day,hour,min,sec,wday,yday)
        local cur_time = time_util.time()
        local next_time = time_util.every_year_day(yday,hour,min,sec)
        return next_time - cur_time
    end
}

local mata = {
    __index = function(tb, k)
        local v = rawget(M,k)
        if v then
            return v
        end
        return tb.time_obj[k]
    end,
    __newindex = function (tb,k,v)
        local s = rawget(tb,k)
        if s then
            rawset(tb,k,v)
        else
            tb.time_obj[k] = v
        end
    end
}

local adapter_loop
adapter_loop = function(point_obj,call_back,...)
    skynet.fork(call_back,...)
    local remain_time = TYPE_REMAIN_TIME_FUNC[point_obj.type](point_obj.month,point_obj.day,point_obj.hour,point_obj.min,point_obj.sec,point_obj.wday,point_obj.yday)
    point_obj.time_obj = timer:new(remain_time * timer.second,1,adapter_loop,point_obj,call_back,...)
end
--[[
    函数作用域：M 对象的成员函数
	函数名称：extend
	描述:  创建整点报时对象
	参数:
		- type (number): 时间刻度类型
]]
function M:new(type)
    assert(g_type_map[type], "unknown type ".. tostring(type))
    local t = {
        type = type,
        month = 1,
        day = 1,
        hour = 0,
        min = 0,
        sec = 0,
        wday = 1,
        yday = 1,
        time_obj = {},
    }
    setmetatable(t,mata)
    return t
end
--[[
    函数作用域：M:new 对象的成员函数
	函数名称：set_month
	描述:  指定几月
	参数:
		- month (number): 月份 1-12
    
]]
function M:set_month(month)
    assert(month >= 1 and month <= 12)
    self.month = month
    return self
end
--[[
    函数作用域：M:new 对象的成员函数
	函数名称：set_day
	描述:  每月第几天,超过适配到最后一天
	参数:
		- day (number): 天数 1-31
]]
function M:set_day(day)
    assert(day >= 1 and day <= 31)
    self.day = day
    return self
end
--[[
    函数作用域：M:new 对象的成员函数
	函数名称：set_hour
	描述:  几时
	参数:
		- hour (number): 几时 0-23
]]
function M:set_hour(hour)
    assert(hour >= 0 and hour <= 23)
    self.hour = hour
    return self
end
--[[
    函数作用域：M:new 对象的成员函数
	函数名称：set_min
	描述:  几分
	参数:
		- min (number): 几分 0-59
]]
function M:set_min(min)
    assert(min >= 0 and min <= 59)
    self.min = min
    return self
end
--[[
    函数作用域：M:new 对象的成员函数
	函数名称：set_sec
	描述:  几秒
	参数:
		- sec (number): 几秒 0-59
]]
function M:set_sec(sec)
    assert(sec >= 0 and sec <= 59)
    self.sec = sec
    return self
end

--[[
    函数作用域：M:new 对象的成员函数
	函数名称：set_wday
	描述:  周几（仅仅设置每周有效）
	参数:
		- wday (number): 周几 1-7 星期天为 1
]]
function M:set_wday(wday)
    assert(wday >= 1 and wday <= 7)
    self.wday = wday
    return self
end

--[[
    函数作用域：M:new 对象的成员函数
	函数名称：set_yday
	描述:  一年第几天（仅仅设置每年第几天有效）
	参数:
		- yday (number): 第几天 1-366 超过适配到最后一天。
]]
function M:set_yday(yday)
    assert(yday >= 1 and yday <= 366)
    self.yday = yday
    return self
end
--[[
    函数作用域：M:new 对象的成员函数
	函数名称：builder
	描述:  构建。
	参数:
		- callback (function): 回调函数。
        - ... (any): 回调参数。
]]
function M:builder(call_back, ...)
    local remain_time = TYPE_REMAIN_TIME_FUNC[self.type](self.month,self.day,self.hour,self.min,self.sec,self.wday,self.yday)
    self.time_obj = timer:new(remain_time * timer.second,1,adapter_loop,self,call_back,...)
    return self
end

return M