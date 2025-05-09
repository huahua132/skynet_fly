---#API
---#content ---
---#content title: 雪花算法生成唯一ID
---#content date: 2024-06-29 22:00:00
---#content categories: ["skynet_fly API 文档","唯一ID生成"]
---#content category_bar: true
---#content tags: [skynet_fly_api]
---#content ---
---#content [timer](https://github.com/huahua132/skynet_fly/blob/master/lualib/skynet-fly/timer.lua)
---#content 使用注意，多服架构下，请注意`machine_id`环境参数的配置分配。
local service = require "skynet.service"
local skynet = require "skynet"

    --雪花算法 用于生成唯一ID
local function snowflake_service()
    local log = require "skynet-fly.log"
    local skynet = require "skynet"
    local skynet_util = require "skynet-fly.utils.skynet_util"
    local wait = require "skynet-fly.time_extend.wait":new()

    local assert = assert
    local os = os
    local tostring = tostring

    local MACHINE_ID_BIT = 14             --机器号位数  最大支持配置       16,383
    local TIME_BIT       = 32             --时间位数    最大到时间         21060207 14:28:15
    local INCR_BIT       = 17             --自增序号数  最大同一秒分配     131071

    local MACHINE_ID_BIT_MAX = (1 << MACHINE_ID_BIT) - 1
    local TIME_BIT_MAX = (1 << TIME_BIT) - 1
    local INCR_BIT_MAX = (1 << INCR_BIT) - 1

    local MACHINE_SHIFT = TIME_BIT + INCR_BIT   --机器号偏移量
    local TIME_SHIFT = INCR_BIT                 --时间偏移量

    local MACHINE_ID = nil
    local g_pre_time = 0
    local g_incr_num = 0
    local g_is_wait = false

    local CMD = {}

    function CMD.new_guid()
        if g_is_wait then
            wait:wait("wait")
        end
        local cur_time = os.time()
        assert(cur_time <= TIME_BIT_MAX, "invalid time")
        if g_pre_time == cur_time then
            if g_incr_num >= INCR_BIT_MAX then
                g_is_wait = true
                while cur_time == g_pre_time do
                    skynet.sleep(5)
                    cur_time = os.time()
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

        return MACHINE_ID << MACHINE_SHIFT | g_pre_time << TIME_SHIFT | g_incr_num
    end

    skynet.start(function()
        skynet_util.lua_dispatch(CMD)
        MACHINE_ID = tonumber(skynet.getenv("machine_id"))
        --检查机器ID
        assert(MACHINE_ID and MACHINE_ID <= MACHINE_ID_BIT_MAX, "invalid machine_id = " .. tostring(MACHINE_ID))
        
        local cur_time = os.time()
        --检查时间还有效没
        assert(cur_time <= TIME_BIT_MAX, "invalid time")

        log.info_fmt("snowflake_m cur_time[%s] max_time[%s] max_machine_id[%s] max_incr[%s] cur_matchineid[%s]",
        os.date("%Y%m%d %H:%M:%S", cur_time), os.date("%Y%m%d %H:%M:%S", TIME_BIT_MAX), MACHINE_ID_BIT_MAX, INCR_BIT_MAX, MACHINE_ID)
    end)
end

local TIME_BIT       = 32             --时间位数
local INCR_BIT       = 17             --自增序号数
local MACHINE_SHIFT = TIME_BIT + INCR_BIT   --机器号偏移量
local TIME_SHIFT = INCR_BIT                 --时间偏移量
local MACHINE_MASK = (1 << MACHINE_SHIFT) - 1 --机器号掩码
local MACHINE_TIME_MASK = (1 << TIME_SHIFT) - 1 --机器号time 掩码

local M = {}

local g_snowflake = nil
---#desc 创建全局GUID
---@return number 全局GUID
function M.new_guid()
    local snowflake = g_snowflake or service.new("snowflake", snowflake_service)
    g_snowflake = snowflake
    return skynet.call(snowflake, 'lua', 'new_guid')
end

---#desc 通过GUID获取机器号
---@param guid number 全局GUID
---@return number 机器号
function M.get_machine_id(guid)
    return guid >> MACHINE_SHIFT
end

---#desc 通过GUID获取创建时间
---@param guid number 全局GUID
---@return number 创建时间
function M.get_time(guid)
    return (guid & MACHINE_MASK) >> TIME_SHIFT
end

---#desc 通过GUID获取自增序号
---@param guid number 全局GUID
---@return number 创建时间
function M.get_incr(guid)
    return guid & MACHINE_TIME_MASK
end

return M