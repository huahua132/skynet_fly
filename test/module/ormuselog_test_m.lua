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

function CMD.start()
    skynet.fork(function()
        stress_testing()
    end)
    return true
end

function CMD.exit()
    return true
end

return CMD