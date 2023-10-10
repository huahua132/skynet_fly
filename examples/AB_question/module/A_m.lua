local contriner_client = require "contriner_client"
local timer = require "timer"
local log = require "log"
local CMD = {}
function CMD.start()
    timer:new(timer.second * 5,0,CMD.send_msg_to_b)
    return true
end

function CMD.exit()

end

function CMD.send_msg_to_b()
    -- local b_client = contriner_client:new("B_m")      --用于访问B服务
    -- local ret = b_client:mod_call("hello")
    -- log.info("send_msg_to_b:",ret)
end

return CMD