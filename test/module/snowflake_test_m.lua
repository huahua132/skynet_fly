local log = require "skynet-fly.log"
local skynet = require "skynet"
local snowflake = require "skynet-fly.snowflake"

local CMD = {}

function CMD.start()
    skynet.fork(function()
        for i = 1, 10 do
            local guid = snowflake.new_guid()
            local machine_id = snowflake.get_machine_id(guid)
            local time = snowflake.get_time(guid)
            local incr = snowflake.get_incr(guid)
            local data = os.date("%Y%m%d %H:%M:%S", time)
            
            log.info_fmt("guid[%s] machine_id[%s] time[%s] data[%s] incr[%s]", guid, machine_id, time, data, incr)
        end

        local guid = 0
        local pre_time = os.time()
        for i = 1, 300000 do
            guid = snowflake.new_guid()
        end
        local machine_id = snowflake.get_machine_id(guid)
        local time = snowflake.get_time(guid)
        local incr = snowflake.get_incr(guid)
        local data = os.date("%Y%m%d %H:%M:%S", time)
        log.info_fmt("over guid[%s] machine_id[%s] time[%s] data[%s] incr[%s] usetime[%s]", guid, machine_id, time, data, incr, os.time() - pre_time)

        local co = coroutine.running
        local guid_map = {}
        local count = 0
        for i = 1, 100 do
            skynet.fork(function()
                for j = 1, 10000 do
                    local guid = snowflake.new_guid()
                    assert(not guid_map[guid])
                    guid_map[guid] = true
                end
                count = count + 1
                if count == 100 then
                    skynet.wakeup(co)
                end
            end)
        end
        skynet.wait(co)

        log.info("test over")
    end)
    return true
end

function CMD.exit()
    return true
end

return CMD