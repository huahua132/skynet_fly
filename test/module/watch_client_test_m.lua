local watch_syn = require "skynet-fly.watch.watch_syn"
local skynet = require "skynet"

local container_client = require "skynet-fly.client.container_client"
local container_watch_interface = require "skynet-fly.watch.interface.container_watch_interface"
local service_watch_interface = require "skynet-fly.watch.interface.service_watch_interface"
local log = require "skynet-fly.log"

container_client:register("watch_server_test_m")

local watch_client = nil

local CMD = {}

--同步数据
local function test_syn()
    watch_client:watch("test_syn_data")

    assert(watch_client:await_get("test_syn_data") == nil)
    for i = 1, 5 do
        log.info("test_syn:", i, assert(watch_client:await_update("test_syn_data") == "test_syn_data: " .. i))
    end

    --服务器热更后同步值
    skynet.call('.container_mgr','lua','load_modules', skynet.self(),"watch_server_test_m")

    assert(watch_client:await_update("test_syn_data") == nil)
    for i = 1, 5 do
        log.info("test_syn:", i, assert(watch_client:await_update("test_syn_data") == "test_syn_data: " .. i))
    end
end

--取消监听
local function test_unwatch()
    watch_client:watch("unwatch_data")

    skynet.fork(function()
        skynet.sleep(500)
        log.info("test_unwatch>>>> ")
        watch_client:unwatch("unwatch_data")
    end)

    while watch_client:is_watch("unwatch_data") do
        local v = watch_client:await_update("unwatch_data")
        log.info("test_unwatch:", v)
    end
end

--测试热更失败应还能正常与旧服务工作
local function test_reloaderr()
    watch_client:watch("test_reloaderr_data")
    while watch_client:is_watch("test_reloaderr_data") do
        local v = watch_client:await_update("test_reloaderr_data")
        log.info("test_reloaderr:", v)
    end
end

function CMD.start()
    skynet.fork(function()
        local rpc_interface = container_watch_interface:new("watch_server_test_m")
        --local rpc_interface = service_watch_interface:new('.watch_server_test_m')      --适用于监听不是可热更的服务
        watch_client = watch_syn.new_client(rpc_interface)
        log.info("start test_syn")
        test_syn()
        log.info("start test_unwatch")
        test_unwatch()
        log.info("start test_reloaderr")
        test_reloaderr()
    end)

    return true
end

function CMD.exit()
    return true
end

return CMD