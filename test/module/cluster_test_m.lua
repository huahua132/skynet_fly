local skynet = require "skynet"
local cluster_client = require "cluster_client"
local log = require "log"

local function test()
    local test_cli = cluster_client:new("test", "cluster_test_m")
    --发消息cluster服务还不存在
    log.info("one_mod_call:", test_cli:one_mod_call("hello"))

    skynet.uniqueservice("cluster_server")
    skynet.sleep(100)

    --给自己发消息
    test_cli:one_balance_send("hello", "test server")

    --call
    log.info("one_balance_call:", test_cli:one_balance_call("hello","test_server"))

    --发消息对方函数不存在
    log.info("one_mod_call:", test_cli:one_mod_call("hellossssss","ddddd"))
end

local CMD = {}

function CMD.hello(msg)
    log.info("hello>>>>>>>>> ", msg)
    return "rsp:" .. msg
end

function CMD.start()
    skynet.fork(test)
    return true
end

function CMD.exit()
    return true
end

return CMD