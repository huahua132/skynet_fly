--支持超时的wait
local timer = require "skynet-fly.timer"
local skynet = require "skynet"

local setmetatable = setmetatable
local assert = assert
local coroutine = coroutine
local pairs = pairs
local next = next

local M = {}
local mata = {__index = M}

function M:new(time_out)
    assert(time_out > 0, "time_out err")
    local t = {
        map = {},
        time_out = time_out,
    }
    
    setmetatable(t, mata)
    return t
end

function M:wait(k)
    assert(k, "not k")
    local map = self.map
    if not map[k] then
        map[k] = {}
    end

    local co = coroutine.running()
    local ti = timer:new(self.time_out, 1, skynet.wakeup, co)
    map[k][co] = true
    skynet.wait(co)
    ti:cancel()
    map[k][co] = nil

    if not next(map[k]) then
        map[k] = nil
    end
end

function M:wakeup(k)
    assert(k, "not k")
    local map = self.map
    local m = map[k]
    if not m then return end

    for co,_ in pairs(m) do
        skynet.wakeup(co)
    end
end

return M