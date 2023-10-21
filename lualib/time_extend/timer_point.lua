--整点报时
local skynet = require "skynet"
local timer = require "timer"
local time_util = require "time_util"

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
        local next_time = time_util.next_min(sec)
        return next_time - cur_time
    end,
    [M.EVERY_HOUR] = function(month,day,hour,min,sec,wday,yday)
        local cur_time = time_util.time()
        local next_time = time_util.next_hour(min,sec)
        return next_time - cur_time
    end,
    [M.EVERY_DAY] = function(month,day,hour,min,sec,wday,yday)
        local cur_time = time_util.time()
        local next_time = time_util.next_day(hour,min,sec)
        return next_time - cur_time
    end,
    [M.EVERY_WEEK] = function(month,day,hour,min,sec,wday,yday)
        local cur_time = time_util.time()
        local next_time = time_util.next_week(wday,hour,min,sec)
        return next_time - cur_time
    end,
    [M.EVERY_MOUTH] = function(month,day,hour,min,sec,wday,yday)
        local cur_time = time_util.time()
        local next_time = time_util.next_month(day,hour,min,sec)
        return next_time - cur_time
    end,
    [M.EVERY_YEAR] = function(month,day,hour,min,sec,wday,yday)
        local cur_time = time_util.time()
        local next_time = time_util.next_year(month,day,hour,min,sec)
        return next_time - cur_time
    end,
    [M.EVERY_YEAR_DAY] = function(month,day,hour,min,sec,wday,yday)
        local cur_time = time_util.time()
        local next_time = time_util.next_year_day(yday,hour,min,sec)
        return next_time - cur_time
    end
}

local TYPE_INVAL_TIME_MAP = {
    [M.EVERY_MINUTE] = timer.minute,
    [M.EVERY_HOUR] = timer.hour,
    [M.EVERY_DAY] = timer.day,
    [M.EVERY_WEEK] = timer.day * 7,
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
        local v = rawget(tb,k)
        if v then
            rawset(tb,k,v)
        else
            tb.time_obj[k] = v
        end
    end
}

local function adapter(point_obj,call_back,...)
    skynet.fork(call_back,...)
    local inval_time = TYPE_INVAL_TIME_MAP[point_obj.type]
    point_obj.time_obj = timer:new(inval_time,timer.loop,call_back,...)
end

local adapter_loop
adapter_loop = function(point_obj,call_back,...)
    skynet.fork(call_back,...)
    local remain_time = TYPE_REMAIN_TIME_FUNC[self.type](self.month,self.day,self.hour,self.min,self.sec,self.wday,self.yday)
    self.time_obj = timer:new(remain_time * timer.second,1,adapter_loop,self,call_back,...)
end

function M:new(type)
    assert(g_type_map[type], "unkown type ".. tostring(type))
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

function M:set_month(month)
    assert(month >= 1 and month <= 12)
    self.month = month
    return self
end

function M:set_day(day)
    assert(day >= 1 and day <= 31)
    self.day = day
    return self
end

function M:set_hour(hour)
    assert(hour >= 0 and hour <= 23)
    self.hour = hour
    return self
end

function M:set_min(min)
    assert(min >= 0 and min <= 59)
    self.min = min
    return self
end

function M:set_sec(sec)
    assert(sec >= 0 and sec <= 59)
    self.sec = sec
    return self
end

--星期天为 1
function M:set_wday(wday)
    assert(wday >= 1 and wday <= 7)
    self.wday = wday
    return self
end

--一年的第几天
function M:set_yday(yday)
    assert(yday >= 1 and yday <= 366)
    self.yday = yday
    return self
end

function M:builder(call_back, ...)
    local remain_time = TYPE_REMAIN_TIME_FUNC[self.type](self.month,self.day,self.hour,self.min,self.sec,self.wday,self.yday)
    if not TYPE_INVAL_TIME_MAP[self.type] then
        self.time_obj = timer:new(remain_time * timer.second,1,adapter_loop,self,call_back,...)
    else
        self.time_obj = timer:new(remain_time * timer.second,1,adapter,self,call_back,...)
    end
    return self
end

return M