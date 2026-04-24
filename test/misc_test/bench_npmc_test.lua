local skynet = require "skynet"
local log = require "skynet-fly.log"
local guid_util = require "skynet-fly.utils.guid_util"
local time_util = require "skynet-fly.utils.time_util"

local assert = assert

local M = {}

function M.start()
    log.info("bench_npmc_test start ")
    skynet.newservice("bench_npmc")
end

return M