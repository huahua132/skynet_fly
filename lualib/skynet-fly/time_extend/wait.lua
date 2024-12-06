--支持超时的wait
local timer = require "skynet-fly.timer"
local skynet = require "skynet"

local setmetatable = setmetatable
local assert = assert
local coroutine = coroutine
local next = next
local tinsert = table.insert
local tremove = table.remove

local M = {}
local mata = {__index = M}

function M:new(time_out)
    local t = {
        map = {},
        list = {},
        time_out = time_out,
    }
    
    setmetatable(t, mata)
    return t
end

function M:wait(k)
    assert(k, "not k")
    local map = self.map
    local list = self.list
    if not map[k] then
        map[k] = {}
        list[k] = {}
    end

    local co = coroutine.running()
    local ti = nil
    if self.time_out then
       ti = timer:new(self.time_out, 1, skynet.wakeup, co)
    end
    map[k][co] = true
    tinsert(list[k], co)
    skynet.wait(co)
    if ti then
        ti:cancel()
    end
    map[k][co] = nil
    local ls = list[k]
    for i = 1,#ls do
        if ls[i] == co then
            tremove(ls, i)
            break
        end
    end

    if not next(map[k]) then
        map[k] = nil
        list[k] = nil
    end
end

function M:wakeup(k)
    assert(k, "not k")
    local list = self.list
    local ls = list[k]
    if not ls then return end

    for i = 1, #ls do
        skynet.wakeup(ls[i])
    end
end

return M