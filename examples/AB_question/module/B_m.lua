local log = require "skynet-fly.log"
local container_client = require "skynet-fly.client.container_client"
local skynet = require "skynet"

container_client:register("A_m")                            --向A注册访问

local CMD = {}

function CMD.start()
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

function CMD.hello()
    return "HEELO A I am is " .. skynet.address(skynet.self())
end

return CMD