local skynet = require "skynet"
local ormtable = require "skynet-fly.db.orm.ormtable"
local ormadapter_uselog = require "skynet-fly.db.ormadapter.ormadapter_uselog"
local time_util = require "skynet-fly.utils.time_util"
local log = require "skynet-fly.log"
local guid_util = require "skynet-fly.utils.guid_util"

local CMD = {}

--压测
--stress testing
local function stress_testing()
    local adapter = ormadapter_uselog:new("uselogs", "uselog.log", 100 * 60, 2) --60flush一次，保存2天
    local orm_obj = ormtable:new("item_change")     --道具变化日志
    :string32("guid")
    :int64("player_id")
    :uint32("time")
    :table("item_list")
    :set_keys("guid")
    :builder(adapter)

    local pre_time = skynet.time()
    local count = 1000000
    for i = 1, count do
        orm_obj:create_one_entry({guid = guid_util.fly_guid(), player_id = i, time = time_util.time(), item_list = { ['10001'] = i, ['10002'] = -i}})
    end
    
    local use_time = skynet.time() - pre_time
    log.info("qps:", count / use_time)
end

--测试读写
local function read_write_test()
    local file_path = "uselogs"
    local file_name = 'uselog.log'
    local adapter = ormadapter_uselog:new(file_path, file_name, 100 * 10, 2) --10秒flush一次，保存2天
    local orm_obj = ormtable:new("item_change")     --道具变化日志
    :string32("guid")
    :int64("player_id")
    :uint32("time")
    :table("item_list")
    :set_keys("guid")
    :builder(adapter)

    skynet.fork(function()
        for i = 1, 100 do
            orm_obj:create_one_entry({guid = guid_util.fly_guid(), player_id = i, time = time_util.time(), item_list = { ['10001'] = i, ['10002'] = -i}})
            log.info("write >>> ", i)
            skynet.sleep(100)
        end
    end)

    local offset = 0
    local line_num = 6

    local read_file_name = string.format("%s_%s", os.date('%Y%m%d', os.time()), file_name)
    skynet.fork(function()
        skynet.sleep(100)
        for i = 1, 200 do
            local isok, ret_str, cur_offset = skynet.call('.use_log', 'lua', 'read', file_path, read_file_name, offset, line_num)
            log.info(isok, ret_str, cur_offset)
            if isok then
                offset = cur_offset
            end
            skynet.sleep(100)
        end
    end)
end

function CMD.start()
    skynet.fork(function()
        --stress_testing()
        read_write_test()
    end)
    return true
end

function CMD.exit()
    return true
end

return CMD