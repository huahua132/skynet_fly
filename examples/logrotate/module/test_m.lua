local log = require "log"
local timer = require "timer"
local skynet = require "skynet"
local time_util = require "time_util"

local os = os

local time_obj = nil

local CMD = {}

function CMD.start(config)
    time_obj = timer:new(timer.second,timer.loop,function() 
        log.info("test log ",os.date("%Y%m%d",time_util.time()))
    end)
    return true
end

function CMD.fix_exit()
    if time_obj then
        time_obj:cancel()
    end
end

function CMD.exit()
    return true
end

return CMD 