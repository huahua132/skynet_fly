---#API
---#content ---
---#content title: 整点报时
---#content date: 2024-06-29 22:00:00
---#content categories: ["skynet_fly API 文档","定时器相关"]
---#content category_bar: true
---#content tags: [skynet_fly_api]
---#content ---
---#content [timer_point](https://github.com/huahua132/skynet_fly/blob/master/lualib/skynet-fly/time_extend/timer_point.lua)

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

---方便调用timer的取消函数
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

---#desc 新建整点报时对象
---@param type number 报时类型
---@return table obj
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

---#desc 指定几月
---@param month number 几月[1,12]
---@return table obj
function M:set_month(month)
    assert(month >= 1 and month <= 12, "Must be within this range[1,12] month=" .. tostring(month))
    self.month = month
    return self
end

---#desc 指定月第几天
---@param day number 哪天[1,31]
---@return table obj
function M:set_day(day)
    assert(day >= 1 and day <= 31, "Must be within this range[1,31] day=" .. tostring(day))
    self.day = day
    return self
end

---#desc 几时
---@param hour number 几时[0,23]
---@return table obj
function M:set_hour(hour)
    assert(hour >= 0 and hour <= 23, "Must be within this range[0,23] hour=" .. tostring(hour))
    self.hour = hour
    return self
end

---#desc 几分
---@param min number 几分[0,59]
---@return table obj
function M:set_min(min)
    assert(min >= 0 and min <= 59, "Must be within this range[0,59] min=" .. tostring(min))
    self.min = min
    return self
end

---#desc 几秒
---@param sec number 几分[0,59]
---@return table obj
function M:set_sec(sec)
    assert(sec >= 0 and sec <= 59, "Must be within this range[0,59] sec=" .. tostring(sec))
    self.sec = sec
    return self
end

---#desc 周几（仅仅设置每周有效）
---@param wday number 周几[1,7]
---@return table 对象
function M:set_wday(wday)
    assert(wday >= 1 and wday <= 7, "Must be within this range[1,7] sec=" .. tostring(wday))
    self.wday = wday
    return self
end

---#desc 一年第几天（仅仅设置每年第几天有效）
---@param yday number 周几[1,366]
---@return table 对象
function M:set_yday(yday)
    assert(yday >= 1 and yday <= 366, "Must be within this range[1,366] sec=" .. tostring(yday))
    self.yday = yday
    return self
end

---#desc 构建
---@param call_back function 回调函数
---@return table 对象
function M:builder(call_back, ...)
    local remain_time = TYPE_REMAIN_TIME_FUNC[self.type](self.month,self.day,self.hour,self.min,self.sec,self.wday,self.yday)
    self.time_obj = timer:new(remain_time * timer.second,1,adapter_loop,self,call_back,...)
    return self
end

return M