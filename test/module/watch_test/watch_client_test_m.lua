local watch_syn = require "watch_syn"
local skynet = require "skynet"
local contriner_watch_interface = require "contriner_watch_interface"
local service_watch_interface = require "service_watch_interface"

local watch_client = nil

local CMD = {}

function CMD.start()
    skynet.fork(function()
        
    end)
    return true
end

function CMD.exit()
    return true
end

return CMD