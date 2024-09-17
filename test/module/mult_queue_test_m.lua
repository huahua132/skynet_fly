local skynet = require "skynet"
local service = require "skynet.service"
local log = require "skynet-fly.log"
local mult_queue = require "skynet-fly.mult_queue"

local function count_service()
    local skynet_util = require "skynet-fly.utils.skynet_util"
    local skynet = require "skynet"
    local log = require "skynet-fly.log"

    local count_map = {}
    local CMD = {}
    function CMD.add(name, seq, flag)
        log.info("add begin:",name, seq, flag)
        if not count_map[name] then
            count_map[name] = 0
        end
        if flag then
            skynet.sleep(10)                      --先让出
        end
        count_map[name] = count_map[name] + 1
        log.info("add end:",name, seq, flag, count_map[name])
        return count_map[name]
    end

    skynet_util.lua_dispatch(CMD)
end

local function add_count(count, name, seq, flag)
    return skynet.call(count, 'lua', 'add', name, seq, flag)
end

--测试相同的key并发是否正常，相同的key需要排队执行
local function test_same_key_muit(count)
    local name = 'test_same_key_muit'
    local muit_que = mult_queue:new()
    local co = coroutine.running()
    local c = 2
    local function wakeup()
        c = c - 1
        if c == 0 then
            skynet.wakeup(co)
        end
    end

    skynet.fork(function()
        local count = muit_que:multi("key", add_count, count, name, 1, true)
        assert(count == 1)
        wakeup()
    end)

    skynet.fork(function()
        local count = muit_que:multi("key", add_count, count, name, 2)
        assert(count == 2)
        wakeup()
    end)

    skynet.wait(co)
end

--测试不同的key并发是否正常，不同的key不需要排队执行
local function test_not_same_key_muit(count)
    local name = 'test_not_same_key_muit'
    local muit_que = mult_queue:new()

    local co = coroutine.running()
    local c = 2
    local function wakeup()
        c = c - 1
        if c == 0 then
            skynet.wakeup(co)
        end
    end
    
    skynet.fork(function()
        local count = muit_que:multi("key1", add_count, count, name, 1, true)
        assert(count == 2, count)
        wakeup()
    end)

    skynet.fork(function()
        local count = muit_que:multi("key2", add_count, count, name, 2)
        assert(count == 1, count)
        wakeup()
    end)

    skynet.wait(co)
end

--测试unique并发是否正常，需要排队执行
local function test_unique(count)
    local name = 'test_unique'
    local muit_que = mult_queue:new()

    local co = coroutine.running()
    local c = 2
    local function wakeup()
        c = c - 1
        if c == 0 then
            skynet.wakeup(co)
        end
    end
    
    skynet.fork(function()
        local count = muit_que:unique(add_count, count, name, 1, true)
        assert(count == 1)
        wakeup()
    end)

    skynet.fork(function()
        local count = muit_que:unique(add_count, count, name, 2)
        assert(count == 2)
        wakeup()
    end)

    skynet.wait(co)
end

--测试先muit再unique在muit再unique 是否正常排队处理
local function test_muit_unique_muit(count)
    local name = "test_muit_unique_muit"
    local muit_que = mult_queue:new()

    local co = coroutine.running()
    local c = 6
    local function wakeup()
        c = c - 1
        if c == 0 then
            skynet.wakeup(co)
        end
    end

    skynet.fork(function()
        local count = muit_que:multi("key1", add_count, count, name, 1, true)
        assert(count == 1)
        wakeup()
    end)

    skynet.fork(function()
        local count = muit_que:unique(add_count, count, name, 2, true)
        assert(count == 2)
        wakeup()
    end)

    skynet.fork(function()
        local count = muit_que:unique(add_count, count, name, 3)
        assert(count == 3)
        wakeup()
    end)

    skynet.fork(function()
        local count = muit_que:multi("key2", add_count, count, name, 4)
        assert(count == 4, count)
        wakeup()
    end)

    skynet.fork(function()
        local count = muit_que:multi("key2", add_count, count, name, 5, true)
        assert(count == 5)
        wakeup()
    end)

    skynet.fork(function()
        local count = muit_que:unique(add_count, count, name, 6)
        assert(count == 6)
        wakeup()
    end)

    skynet.wait()
end

local function test_unique_muit_unique_muit(count)
    local name = "test_unique_muit_unique_muit"
    local muit_que = mult_queue:new()

    local co = coroutine.running()
    local c = 10
    local function wakeup()
        c = c - 1
        if c == 0 then
            skynet.wakeup(co)
        end
    end

    skynet.fork(function()
        local count = muit_que:unique(add_count, count, name, 1, true)
        assert(count == 1)
        wakeup()
    end)

    skynet.fork(function()
        local count = muit_que:unique(add_count, count, name, 2)
        assert(count == 2)
        wakeup()
    end)

    skynet.fork(function()
        local count = muit_que:multi("key1", add_count, count, name, 3)
        assert(count == 3)
        wakeup()
    end)

    skynet.fork(function()
        local count = muit_que:multi("key2", add_count, count, name, 4, true)
        assert(count == 4)
        wakeup()
    end)

    skynet.fork(function()
        local count = muit_que:multi("key2", add_count, count, name, 5)
        assert(count == 5)
        wakeup()
    end)

    skynet.fork(function()
        local count = muit_que:unique(add_count, count, name, 6, true)
        assert(count == 6, count)
        wakeup()
    end)

    skynet.fork(function()
        local count = muit_que:unique(add_count, count, name, 7)
        assert(count == 7)
        wakeup()
    end)

    skynet.fork(function()
        local count = muit_que:multi("key1", add_count, count, name, 8)
        assert(count == 8, count)
        wakeup()
    end)

    skynet.fork(function()
        local count = muit_que:multi("key2", add_count, count, name, 9, true)
        assert(count == 9, count)
        wakeup()
    end)

    skynet.fork(function()
        local count = muit_que:multi("key2", add_count, count, name, 10)
        assert(count == 10)
        wakeup()
    end)

    skynet.wait()
end

--测试嵌套调用  不能嵌套调用，嵌套调用报错
local function test_loop(count)
    local name = "test_loop"

    local muit_que = mult_queue:new()

    local co = coroutine.running()
    local c = 4
    local function wakeup()
        c = c - 1
        if c == 0 then
            skynet.wakeup(co)
        end
    end

    skynet.fork(function()
        muit_que:multi("key1", function()
            local isok, err = pcall(muit_que.multi, muit_que, "key1", add_count, count, name, 1)
            if not isok then
                log.error(err)
            end
            wakeup()
        end)
    end)

    skynet.fork(function()
        muit_que:unique(function()
            local isok, err = pcall(muit_que.unique, muit_que, add_count, count, name, 2)
            if not isok then
                log.error(err)
            end
            wakeup()
        end)
    end)

    skynet.fork(function()
        muit_que:multi("key1", function()
            local isok, err = pcall(muit_que.unique, muit_que, add_count, count, name, 3)
            if not isok then
                log.error(err)
            end
            wakeup()
        end)
    end)

    skynet.fork(function()
        muit_que:unique(function()
            local isok, err = pcall(muit_que.multi, muit_que, "key1", add_count, count, name, 4)
            if not isok then
                log.error(err)
            end
            wakeup()
        end)
    end)

    skynet.wait()
end

local CMD = {}

function CMD.start()
    log.info("test begin >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>")
    local count = service.new("count", count_service)
  
    test_same_key_muit(count)
    test_not_same_key_muit(count)
    test_unique(count)
    test_muit_unique_muit(count)
    test_unique_muit_unique_muit(count)
    test_loop(count)

    log.info("test end >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>")
    return true
end

function CMD.exit()
    return true
end

return CMD