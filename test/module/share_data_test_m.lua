local log = require "skynet-fly.log"
local skynet = require "skynet"
local sharedata = require "skynet-fly.sharedata"
local table_util = require "skynet-fly.utils.table_util"

local CMD = {}

local function testsharedata()
    local cfg2 = sharedata:new("./common/cfgs/test_cfg2.lua", sharedata.enum.sharedata):builder()
    local data_table = cfg2:get_data_table()

    local sub_table = data_table[1]
    
    log.info("wait update 10s >>> ")
    skynet.sleep(1000)  --等待去更新配置

    log.info("testsharedata old", data_table)             --会更新到
    log.info("testsharedata subold", sub_table)           --会更新到
    log.info("testsharedata new", cfg2:get_data_table())  --会更新到
end

local function testsharetable()
    local cfg2 = sharedata:new("./common/cfgs/test_cfg2.lua", sharedata.enum.sharetable):builder()
    local data_table = cfg2:get_data_table()

    local sub_table = data_table[1]
    
    log.info("wait update 10s >>> ")
    skynet.sleep(1000)  --等待去更新配置

    log.info("testsharetable old", data_table)             --更新不到
    log.info("testsharetable subold", sub_table)           --更新不到
    log.info("testsharetable new", cfg2:get_data_table())  --更新到
end

local function test_check_func()
    local _ = sharedata:new("./common/cfgs/test_cfg2.lua", sharedata.enum.sharetable)
    :set_check_field("a", function(v)
        if v > 1 then 
            return false, "can`t > 1"
        end
        return true
    end)
    :set_check_line(function(cfg)
        if not cfg.c then
           return false, "not c" 
        end
        return true
    end)
    :builder()
end

local function test_map_list()
    local cfg2 = sharedata:new("./common/cfgs/test_cfg2.lua", sharedata.enum.sharetable)
    :set_map_list("a_list", "a")
    :builder()

    local old_map_list = cfg2:get_map_list("a_list")
    log.info("wait update 10s >>> ")
    skynet.sleep(1000)  --等待去更新配置

    local new_map_list = cfg2:get_map_list("a_list")
    log.info("old_map_list >>>", old_map_list)
    log.info("new_map_list >>>", new_map_list)
end

local function test_map_map()
    local cfg2 = sharedata:new("./common/cfgs/test_cfg2.lua", sharedata.enum.sharetable)
    :set_map("ab_map", "a", "b")
    :set_map("c_map", "c")
    :builder()

    local old_ab_map = cfg2:get_map("ab_map")
    local old_c_map = cfg2:get_map("c_map")

    log.info("wait update 10s >>> ")
    skynet.sleep(1000)  --等待去更新配置

    local new_ab_map = cfg2:get_map("ab_map")
    local new_c_map = cfg2:get_map("c_map")

    log.info("old_ab_map:", old_ab_map)
    log.info("old_c_map:", old_c_map)
    log.info("new_ab_map:", new_ab_map)
    log.info("new_c_map:", new_c_map)
end

local function test_benchmark_sharedata()
    local cfg = sharedata:new("./common/cfgs/test_cfg.lua", sharedata.enum.sharedata):builder()
    local data_table = cfg:get_data_table()
    local count = #data_table
    local pre_time = skynet.time()
    table_util.dump(data_table)
    local use_time = skynet.time() - pre_time

    log.info("use time:", use_time)
    log.info("tps:", count / use_time)
end

local function test_benchmark_sharetable()
    local cfg = sharedata:new("./common/cfgs/test_cfg.lua", sharedata.enum.sharetable):builder()
    local data_table = cfg:get_data_table()
    local count = #data_table
    local pre_time = skynet.time()
    table_util.dump(data_table)
    local use_time = skynet.time() - pre_time

    log.info("use time:", use_time)
    log.info("tps:", count / use_time)
end

function CMD.start()
    skynet.fork(function()
        --testsharedata()
        testsharetable()
        --test_check_func()
        --test_map_list()
        --test_map_map()
        --test_benchmark_sharedata()
        --test_benchmark_sharetable()
    end)

    return true
end

function CMD.exit()
    return true
end

return CMD
