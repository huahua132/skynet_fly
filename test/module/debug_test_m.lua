local timer = require "skynet-fly.timer"
local log = require "skynet-fly.log"
local debug_test = require "common.debug_test"
local container_client = require "skynet-fly.client.container_client"
container_client:register("share_config_m")

local CMD = {}

function CMD.start()
    local aa = 1
    local bb = ""
    local cc = {}
    timer:new(timer.second, 0, function()
        local a = 2
        local b = "sss"
        local c = {
            d = 1
        }
        local dd = debug_test.hello()
        log.info(">>>>>>>>>>>>test ",aa, bb, cc, dd)
        local cli = container_client:new("share_config_m")
        local server_cfg = cli:mod_call("query", "server_cfg")
        log.info("server_cfg >>> ", server_cfg)                 --call调用回来再次打个断点才行
    end)
    return true
end

function CMD.exit()
    return true
end

return CMD