local tti = require "skynet-fly.cache.tti"
local log = require "skynet-fly.log"
local skynet = require "skynet"

--基础测试
local function base_test()
    --缓存淘汰
    local function cache_time_out(key, v)
        log.info("cache_time_out: ", key, v)
    end

    local cache_obj = tti:new(100,cache_time_out)

    --测试插入，获取，更新，过期 
    cache_obj:set_cache("a1", 1)
    assert(cache_obj:get_cache("a1") == 1)
    assert(cache_obj:update_cache("a1", 2))
    assert(cache_obj:get_cache("a1") == 2)

    skynet.sleep(200)
    assert(cache_obj:get_cache("a1") == nil)
    assert(cache_obj:update_cache("a1", 3) == false)

    --测试删除
    cache_obj:set_cache("a2", 1)
    assert(cache_obj:del_cache("a2") == true)
    assert(cache_obj:get_cache("a2") == nil)
    assert(cache_obj:del_cache("a2") == false)
    --测试过期后删除
    cache_obj:set_cache("a3", 1)
    skynet.sleep(200)
    assert(cache_obj:del_cache("a3") == false)

    --key为table
    local t1 = {name = "t1"}
    local function tt_time_out(key, v)
        log.info("tt_time_out: ", key, v)
        assert(key == t1)
    end
    local tcache_obj = tti:new(100, tt_time_out)
    tcache_obj:set_cache(t1, 1)
    assert(tcache_obj:get_cache(t1) == 1)
end

--缓存总量限制测试
local function cache_limit_test()
    local function time_out(key, v)
        log.info("time_out:", key, v)
    end
    local cache = tti:new(6000, time_out, 10)

    for i = 1, 20 do
        local t = {name = "t: " .. i}
        skynet.sleep(100)
        cache:set_cache(t, i)
        log.info("cache_limit_test set_cache:", i)
    end
end

local CMD = {}

function CMD.start()
    base_test()
    cache_limit_test()
    return true
end

function CMD.exit()

end

return CMD