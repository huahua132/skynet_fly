local contriner_client = require "skynet-fly.client.contriner_client"
local timer = require "skynet-fly.timer"
local log = require "skynet-fly.log"
local skynet = require "skynet"

contriner_client:register("B_m")
contriner_client:set_week_visitor("B_m")

contriner_client:add_queryed_cb("B_m",function()
    log.info("queryed B_m")
end)

contriner_client:add_updated_cb("B_m",function()
    log.info("updated B_m")
end)

local CMD = {}

function CMD.start()
    timer:new(timer.second * 3,timer.loop,CMD.send_msg_to_b)
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
    local ret = contriner_client:instance("B_m"):balance_call("hello")
    log.info("send_msg_to_b:",ret)
    local ret = contriner_client:instance("B_m","test_one"):mod_call_by_name("hello")
    log.info("send_msg_to_b test_one:",ret)
    local ret = contriner_client:instance("B_m","test_two"):mod_call_by_name("hello")
    log.info("send_msg_to_b test_two:",ret)
end

return CMD