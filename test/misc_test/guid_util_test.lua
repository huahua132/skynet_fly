local skynet = require "skynet"
local log = require "skynet-fly.log"
local guid_util = require "skynet-fly.utils.guid_util"
local time_util = require "skynet-fly.utils.time_util"

local assert = assert

local M = {}

function M.start()
    log.info("guid_util_test start ")
    local cur_time = time_util.time()
    local check = {}
    for i = 1, 8000000 do
        local guid = guid_util:fly_guid()
        assert(not check[guid])
        check[guid] = true
    end
    local use_time = time_util.time()
    log.info("guid_util_test end ", use_time - cur_time, 8000000 / (use_time - cur_time))
    guid_util:fly_guid()
    local guid = guid_util:fly_guid()
    log.info(">>> ", guid)
    local svr_type = guid_util.get_svr_type_by_fly_guid(guid)
    local svr_id = guid_util.get_svr_id_by_fly_guid(guid)
    local address = guid_util.get_address_by_fly_guid(guid)
    local time = guid_util.get_time_by_fly_guid(guid)
    local incr = guid_util.get_incr_by_fly_guid(guid)
    log.info_fmt("%s %02x", svr_type, svr_type)
    log.info_fmt("%s %04x", svr_id, svr_id)
    log.info_fmt("%s %08x", address, address)
    log.info_fmt("%s %08x", time, time)
    log.info_fmt("%s %06x", incr, incr)
end

return M