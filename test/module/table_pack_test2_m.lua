local contriner_client = require "skynet-fly.client.contriner_client"
local skynet = require "skynet"
local log = require "skynet-fly.log"
contriner_client:register("table_pack_test1_m")
local CMD = {}

function CMD.start()
    skynet.fork(function()
        print("print ping:",contriner_client:new("table_pack_test1_m"):mod_call("ping"))
        log.info("ping:", contriner_client:new("table_pack_test1_m"):mod_call("ping"))
    end)
    return true
end

function CMD.exit()
    return true
end

return CMD