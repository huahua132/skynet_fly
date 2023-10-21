--整点报时
local skynet = require "skynet"
local timer = require "timer"
local time_util = require "time_util"
local log = require "log"

local tostring = tostring
local assert = assert
local pairs = pairs
local setmetatable = setmetatable

local M = {
    --每分钟
    EVERY_MINUTE = 1,
    --每小时
    EVERY_HOUR = 2,
    --每天
    EVERY_DAY = 3,
}

local g_type_map = {}
do 
    for _,type in pairs(M) do
        g_type_map[type] = true
    end
end

local TYPE_REMAIN_TIME_FUNC = {
    [M.EVERY_MINUTE] = function()
        local cur_time = time_util.time()
        local next_time = time_util.next_min()
        return next_time - cur_time
    end,
    [M.EVERY_HOUR] = function()
        local cur_time = time_util.time()
        local next_time = time_util.next_hour()
        return next_time - cur_time
    end,
    [M.EVERY_DAY] = function()
        local cur_time = time_util.time()
        local next_time = time_util.next_day()
        return next_time - cur_time
    end,
}

local TYPE_INVAL_TIME_MAP = {
    [M.EVERY_MINUTE] = timer.minute,
    [M.EVERY_HOUR] = timer.hour,
    [M.EVERY_DAY] = timer.day,
}

local mata = {
    __index = function(tb, k)
        if M[k] then
            return M[k]
        end
        return tb.time_obj[k]
    end,
    __newindex = function (tb,k,v)
        tb.time_obj[k] = v
    end
}

local function adapter(point_obj,type,call_back,...)
    skynet.fork(call_back,...)
    local inval_time = TYPE_INVAL_TIME_MAP[type]
    point_obj.time_obj = timer:new(inval_time,timer.loop,call_back,...)
end

function M:new(type,call_back,...)
    assert(g_type_map[type], "unkown type ".. tostring(type))
    local remain_time = TYPE_REMAIN_TIME_FUNC[type]()
    local t = {}
    t.time_obj = timer:new(remain_time * timer.second,1,adapter,t,type,call_back,...)
    setmetatable(t,mata)
    return t
end

return M