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
local wait = require "skynet-fly.time_extend.wait":new()

local sformat = string.format
local ostime = os.time
local assert = assert
local tonumber = tonumber
local table = table
local string = string

local INCR_BIT_MAX = (1 << 24) - 1
local TYPE_MAX = math_util.uint8max
local ID_MAX = math_util.uint16max
local TIME_MAX = math_util.uint32max

local g_svr_type = env_util.get_svr_type()
local g_svr_id = env_util.get_svr_id()
local g_self_address = sformat('%08x', skynet.self())
local g_incr_num = 0
local g_pre_time = 0
local g_is_wait = false

local function get_time_incr()
    if g_is_wait then
        wait:wait("wait")
    end
    local cur_time = ostime()
    assert(cur_time <= TIME_MAX, "invalid time")
    if g_pre_time == cur_time then
        if g_incr_num >= INCR_BIT_MAX then
            g_is_wait = true
            while cur_time == g_pre_time do
                skynet.sleep(5)
                cur_time = ostime()
            end
            g_is_wait = false
            g_pre_time = cur_time
            g_incr_num = 0
            wait:wakeup("wait")
        else
            g_incr_num = g_incr_num + 1
        end
    else
        g_pre_time = cur_time
        g_incr_num = 0
    end

    if g_pre_time ~= cur_time then
        g_pre_time = cur_time
        g_incr_num = 0
    end

    return cur_time, g_incr_num
end

local M = {}
---#desc fly风格GUID
---@return string 32字节的guid
function M.fly_guid()
    assert(g_svr_type > 0 and g_svr_type <= TYPE_MAX)
    assert(g_svr_id > 0 and g_svr_id <= ID_MAX)
    return sformat('%02x-%04x-%s-%08x-%06x', g_svr_type, g_svr_id, g_self_address, get_time_incr())
end

---@param fly_guid string
---@return number? svr_type
---@return string? errstr
function M.get_svr_type_by_fly_guid(fly_guid)
    -- 分割 GUID 字符串
    local parts = {}
    for part in string.gmatch(fly_guid, "[^-]+") do
        table.insert(parts, part)
    end
    if #parts ~= 5 then
        return nil, "invalid guid format"
    end

    -- 提取服务类型（第1部分）
    local svr_type_str = parts[1]
    if #svr_type_str ~= 2 then
        return nil, "invalid svr_type length"
    end
    
    local svr_type = tonumber(svr_type_str, 16)
    if not svr_type or svr_type < 1 or svr_type > TYPE_MAX then
        return nil, "svr_type out of range (1-255)"
    end
    return svr_type
end

---@param fly_guid string
---@return number? svr_id
---@return string? errstr
function M.get_svr_id_by_fly_guid(fly_guid)
    local parts = {}
    for part in string.gmatch(fly_guid, "[^-]+") do
        table.insert(parts, part)
    end
    if #parts ~= 5 then
        return nil, "invalid guid format"
    end

    -- 提取服务ID（第2部分）
    local svr_id_str = parts[2]
    if #svr_id_str ~= 4 then
        return nil, "invalid svr_id length"
    end
    
    local svr_id = tonumber(svr_id_str, 16)
    if not svr_id or svr_id < 1 or svr_id > ID_MAX then
        return nil, "svr_id out of range (1-65535)"
    end
    return svr_id
end

---@param fly_guid string
---@return number? address
---@return string? errstr
function M.get_address_by_fly_guid(fly_guid)
    local parts = {}
    for part in string.gmatch(fly_guid, "[^-]+") do
        table.insert(parts, part)
    end
    if #parts ~= 5 then
        return nil, "invalid guid format"
    end

    -- 提取地址（第3部分）
    local address_str = parts[3]
    if #address_str ~= 8 then
        return nil, "invalid address format"
    end
    
    local address = tonumber(address_str, 16)
    if not address or address < 0 or address > math_util.uint32max then
        return nil, "address out of range (0-4294967295)"
    end
    return address
end

---@param fly_guid string
---@return number? time
---@return string? errstr
function M.get_time_by_fly_guid(fly_guid)
    local parts = {}
    for part in string.gmatch(fly_guid, "[^-]+") do
        table.insert(parts, part)
    end
    if #parts ~= 5 then
        return nil, "invalid guid format"
    end

    -- 提取时间戳（第4部分）
    local time_str = parts[4]
    if #time_str ~= 8 then
        return nil, "invalid time length"
    end
    
    local time = tonumber(time_str, 16)
    if not time or time < 0 or time > TIME_MAX then
        return nil, "time out of range (0-4294967295)"
    end
    return time
end

---@param fly_guid string
---@return number? incr
---@return string? errstr
function M.get_incr_by_fly_guid(fly_guid)
    local parts = {}
    for part in string.gmatch(fly_guid, "[^-]+") do
        table.insert(parts, part)
    end
    if #parts ~= 5 then
        return nil, "invalid guid format"
    end

    -- 提取递增数（第5部分）
    local incr_str = parts[5]
    if #incr_str ~= 6 then
        return nil, "invalid incr length"
    end
    
    local incr = tonumber(incr_str, 16)
    if not incr or incr < 0 or incr > INCR_BIT_MAX then
        return nil, "incr out of range (0-16777215)"
    end
    return incr
end

return M