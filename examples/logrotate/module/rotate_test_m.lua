local log = require "skynet-fly.log"
local logrotate = require "skynet-fly.logrotate"
local timer = require "skynet-fly.timer"
local time_util = require "skynet-fly.utils.time_util"
local file_util = require "skynet-fly.utils.file_util"
local timer_point = require "skynet-fly.time_extend.timer_point"
local skynet = require "skynet"

local CMD = {}

function CMD.start()
    local file_path = "./rotatelogs/"
    file_util.mkdir(file_path)
    local file_name = "rotate.record"
    timer:new(timer.second, timer.loop, function()
        local file_url = file_path .. file_name
        local file = io.open(file_url, 'a+')
        file:write(string.format("test log %s\n", os.date("%Y%m%d %H:%M:%S", time_util.time())))
        file:close()
    end)

    skynet.fork(function()
        local rotate = logrotate:new(file_name)
        :set_rename_format("%Y%m%d-%H%M%S")
        :set_file_path(file_path)
        :set_point_type(timer_point.EVERY_MINUTE)
        :builder()
    
        timer:new(timer.minute * 10, 1, function()
            log.info("cancel rotate >>> ")
            rotate:cancel()
        end)
    end)
   
    return true
end

function CMD.exit()
    return true
end

return CMD