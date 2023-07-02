local skynet = require "skynet"
local contriner_client = require "contriner_client"
local log = require "log"

local CMD = {}

local IS_CLOSE = false

function CMD.start()
    skynet.fork(function()
        log.info("redis_test_m start !!!")
        local redis_cli = contriner_client:new("redis_m")
    
        log.info(redis_cli:mod_call("redis_cmd","set","test","hello skynetfly"))
    
        log.info(redis_cli:mod_call("redis_cmd","get","test"))
    
        while not IS_CLOSE do
            redis_cli:mod_call("redis_cmd","set","test","hello skynetfly")
        end
    end)
end

function CMD.exit()
    IS_CLOSE = true
end

return CMD