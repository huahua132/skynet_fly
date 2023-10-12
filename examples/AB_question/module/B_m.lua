local log = require "log"
local contriner_client = require "contriner_client"

contriner_client:register("A_m")

local CMD = {}

function CMD.start()
    return true
end

function CMD.before_exit()
    log.error("即将退出")
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

-- function CMD.hello()
--     return "HEELO AAA"
-- end

return CMD