local log = require "skynet-fly.log"
local skynet = require "skynet"
local watch_syn = require "skynet-fly.watch.watch_syn"
require "skynet.manager"

local watch_server = nil

local CMD = {}

--测试同步值
local function test_syn()
    for i = 1, 5 do
        log.info("sleep 1秒", i)
        skynet.sleep(100)
        log.info("publish test_syn:", i)
        watch_server:publish("test_syn_data", 'test_syn_data: ' .. i)
    end
end

--取消监听
local function test_unwatch()
    for i = 1, 10 do
        log.info("sleep 1秒", i)
        skynet.sleep(100)
        log.info("publish unwatch_data:", i)
        watch_server:publish("unwatch_data", 'unwatch_data: ' .. i)
    end
end

--测试热更失败
local function test_reloaderr()
    local count = 0
    while true do
        log.info("sleep 1秒 " .. count)
        skynet.sleep(100)
        log.info("publish test_reloaderr:" .. count)
        watch_server:publish("test_reloaderr_data", 'test_reloaderr_data: ' .. count)
        count = count + 1
    end
end

function CMD.start()
    watch_server:register("test_syn_data")
    watch_server:register("unwatch_data","unwatch_data init value")
    watch_server:register("test_reloaderr_data")

    skynet.fork(function()
        log.info("start test_syn")
        test_syn()
        log.info("start test_unwatch")
        test_unwatch()
        log.info("start test_reloaderr")
        test_reloaderr()
    end)
    skynet.register(".watch_server_test_m")
    --return false      --测试热更失败 手动调用 script/check_reload.sh
    return true
end

function CMD.exit()
    return true
end

function CMD.fix_exit()

end

watch_server = watch_syn.new_server(CMD)

return CMD 