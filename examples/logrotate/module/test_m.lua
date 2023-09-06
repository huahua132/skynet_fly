local log = require "log"
local timer = require "timer"
local skynet = require "skynet"

local os = os

local CMD = {}

function CMD.start(config)
    timer:new(timer.second,0,function() 
        log.info("test log ",os.date("%Y%m%d",os.time()))
    end)
    return true
end

function CMD.exit()
    timer:new(timer.minute,1,skynet.exit())
end

return CMD 