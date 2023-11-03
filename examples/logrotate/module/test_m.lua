local log = require "log"
local timer = require "timer"
local skynet = require "skynet"
local time_util = require "time_util"

local os = os

local CMD = {}

function CMD.start(config)
    timer:new(timer.second,timer.loop,function() 
        log.info("test log ",os.date("%Y%m%d",time_util.time()))
    end)
    return true
end

function CMD.exit()
    return true
end

return CMD 