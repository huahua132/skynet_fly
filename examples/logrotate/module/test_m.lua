local log = require "log"
local timer = require "timer"
local skynet = require "skynet"

local os = os

local CMD = {}

function CMD.start(config)
    timer:new(timer.second,0,log.info,"test log ",os.date("%Y%m%d",os.time()))
    return true
end

function CMD.exit()
    timer:new(timer.minute,1,skynet.exit())
end

return CMD 