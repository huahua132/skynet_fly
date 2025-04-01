---#API
---#content ---
---#content title: guid_util guid相关
---#content date: 2025-04-01 22:00:00
---#content categories: ["skynet_fly API 文档","工具函数"]
---#content category_bar: true
---#content tags: [skynet_fly_api]
---#content ---
---#content [guid_util](https://github.com/huahua132/skynet_fly/blob/master/lualib/skynet-fly/utils/guid_util.lua)

local skynet = require "skynet"
local env_util = require "skynet-fly.utils.env_util"
local math_util = require "skynet-fly.utils.math_util"

local sformat = string.format
local ostime = os.time
local assert = assert

local UINT24MAX = (1 << 24) - 1

local g_svr_type = env_util.get_svr_type()
local g_svr_id = env_util.get_svr_id()
local g_self_address = sformat('%08x', skynet.self())
local g_incr_val = 0
local g_pre_time = 0
local function get_time_inval()
    local cur_time = ostime()
    if g_pre_time ~= cur_time then
        g_pre_time = cur_time
        g_incr_val = 0
    end
    
    g_incr_val = g_incr_val + 1
    assert(g_incr_val <= UINT24MAX)
    return cur_time, g_incr_val
end

local M = {}
---#desc fly风格GUID
---@return string 最长32字节的guid
function M.fly_guid()
    return sformat('%02x-%04x-%s-%08x-%06x', g_svr_type, g_svr_id, g_self_address, get_time_inval())
end

return M