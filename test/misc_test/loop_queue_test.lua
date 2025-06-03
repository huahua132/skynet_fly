local skynet = require "skynet"
local skynet_util = require "skynet-fly.utils.skynet_util"
local log = require "skynet-fly.log"
local queue = require "skynet.queue"()

local assert = assert

local M = {}

function M.start()
    local addr = skynet.self()
    skynet.call(addr, 'lua', "loop_queue_start")
end


skynet_util.extend_cmd_func("loop_queue_start", function()
    log.info("loop_queue_start begin")
    queue(function()
        log.info("loop_queue_start queue begin")
        local addr = skynet.self()
        skynet.call(addr, 'lua', "loop_queue_end")
        log.info("loop_queue_start queue end")
    end)
    log.info("loop_queue_start end")
end)

skynet_util.extend_cmd_func("loop_queue_end", function()
    log.info("loop_queue_end begin")
    queue(function()
        log.info("loop_queue_end queue begin")
    end)
    log.info("loop_queue_end end")
end)

return M