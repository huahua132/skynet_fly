local contriner_client = require "contriner_client"
local timer = require "timer"
local log = require "log"
local skynet = require "skynet"

contriner_client:register("B_m")
contriner_client:set_week_visitor("B_m")

local CMD = {}

function CMD.start()
    timer:new(timer.second * 10,timer.loop,CMD.send_msg_to_b)
    return true
end

function CMD.herald_exit()
    log.error("预告退出")
end

function CMD.exit()
    log.error("退出")
    return true
end

function CMD.fix_exit()
    log.error("确认要退出")
end

function CMD.cancel_exit()
    log.error("取消退出")
end

function CMD.check_exit()
    log.error("检查退出")
    return true
end

function CMD.send_msg_to_b()
    local b_client = contriner_client:new("B_m")      --用于访问B服务
    local ret = b_client:mod_call("hello")
    log.info("send_msg_to_b:",ret)
end

return CMD