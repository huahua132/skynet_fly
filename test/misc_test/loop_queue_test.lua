local skynet = require "skynet"
local skynet_util = require "skynet-fly.utils.skynet_util"
local log = require "skynet-fly.log"
local queue = require "skynet.queue"()

local assert = assert

local M = {}

function M.start()
    local addr = skynet.self()
    skynet.send(addr, 'lua', "loop_queue_end")
    skynet.send(addr, 'lua', "loop_queue_end")

    skynet.call(addr, 'lua', "loop_queue_start")
end


skynet_util.extend_cmd_func("loop_queue_start", function()
    queue(function()
        queue(function()
            log.info("loop_queue_start queue begin")
            local addr = skynet.self()
            skynet.send(addr, 'lua', "loop_queue_end")
            skynet.send(addr, 'lua', "loop_queue_end")
            skynet.call(addr, "lua", "loop_queue_end")
            log.info("loop_queue_start queue end")
        end)
    end)
end)

skynet_util.extend_cmd_func("loop_queue_end", function()
    queue(function()
        skynet.sleep(100)
        queue(function()
            log.info("loop_queue_end queue begin")
            skynet.sleep(100)
            log.info("loop_queue_end queue end")
        end)
        skynet.sleep(100)
    end)
end)

return M