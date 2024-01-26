local log = require "log"
local skynet = require "skynet"
local watch_syn = require "watch_syn"
require "manager"

local watch_server = nil

local CMD = {}

--测试同步值
local function test_syn()

end

function CMD.start()
    watch_server = watch_syn.new_server()

    skynet.fork(function()
        log.info("start test_syn")
        test_syn()
    end)

    skynet.register(".watch_server_test_m")
    return true
end

function CMD.exit()
    return true
end

return CMD 