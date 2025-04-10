---#API
---#content ---
---#content title: 日志轮换
---#content date: 2024-06-29 22:00:00
---#content categories: ["skynet_fly API 文档","日志相关"]
---#content category_bar: true
---#content tags: [skynet_fly_api]
---#content ---
---#content [logrotate](https://github.com/huahua132/skynet_fly/blob/master/lualib/skynet-fly/logrotate.lua)
local contriner_client = require "skynet-fly.client.contriner_client"
local skynet_util = require "skynet-fly.utils.skynet_util"
local contriner_interface = require "skynet-fly.contriner.contriner_interface"
local wait = require "skynet-fly.time_extend.wait"
local skynet = require "skynet"
local log = require "skynet-fly.log"

local setmetatable = setmetatable
local assert = assert
local type = type
local pairs = pairs

local g_wait_query = wait:new()

local g_alloc_id = 1
local function alloc_id()
    local id = g_alloc_id
    g_alloc_id = g_alloc_id + 1
    return id
end

local g_rotate_map = {}

contriner_client:register("logrotate_m")

contriner_client:add_queryed_cb("logrotate_m", function()
    g_wait_query:wakeup("query")
end)

--logrotate的服务更新之后需要重新发送切割任务
contriner_client:add_updated_cb("logrotate_m", function()
    for id, obj in pairs(g_rotate_map) do
        contriner_client:instance("logrotate_m"):mod_call("add_rotate", skynet.self(), obj.cfg, id)
    end
end)

if skynet_util.is_hot_container_server() then
    contriner_interface.hook_fix_exit_after(function()
        contriner_client:instance("logrotate_m"):mod_call("cancel_all", skynet.self())
    end)
end

local M = {}
local mt = {__index = M}
---#desc 新建对象
---@param filename string? 文件名
---@return table 对象
function M:new(filename)
    local t = {
        cfg = {
            filename = filename,
        },
        is_builder = false,
    }
    if not contriner_client:is_ready("logrotate_m") then
        log.warn("waiting logrotate_m begin")
        g_wait_query:wait("query")
        log.warn("waiting logrotate_m end")
    end
    setmetatable(t, mt)
    return t
end

---#desc 重命名文件格式
---@param rename_format string
---@return table 对象
function M:set_rename_format(rename_format)
    assert(not self.is_builder, "builded can`t use set_rename_format")
    assert(type(rename_format) == 'string', "rename_format not string")
    local cfg = self.cfg
    cfg.rename_format = rename_format
    return self
end

---#desc 设置文件路径
---@param file_path string 文件路径
---@return table 对象
function M:set_file_path(file_path)
    assert(not self.is_builder, "builded can`t use set_file_path")
    assert(type(file_path) == 'string', "file_path not string")
    local cfg = self.cfg
    cfg.file_path = file_path
    return self
end

---#desc 设置至少多大才会切割
---@param limit_size number 至少多大
---@return table 对象
function M:set_limit_size(limit_size)
    assert(not self.is_builder, "builded can`t use set_limit_size")
    assert(type(limit_size) == 'number', "limit_size not number")

    local cfg = self.cfg
    cfg.limit_size = limit_size
    return self
end

---#desc 设置最大保留天数
---@param max_age number 保留天数
---@return table 对象
function M:set_max_age(max_age)
    assert(not self.is_builder, "builded can`t use set_max_age")
    assert(type(max_age) == 'number', "max_age not number")

    local cfg = self.cfg
    cfg.max_age = max_age
    return self
end

---#desc 设置最大保留文件数
---@param max_backups number 保留文件数
---@return table 对象
function M:set_max_backups(max_backups)
    assert(not self.is_builder, "builded can`t use set_max_backups")
    assert(type(max_backups) == 'number', "max_backups not number")

    local cfg = self.cfg
    cfg.max_backups = max_backups
    return self
end

---#desc 设置轮转时调用系统命令
---@param sys_cmd string 系统命令
---@return table 对象
function M:set_sys_cmd(sys_cmd)
    assert(not self.is_builder, "builded can`t use set_sys_cmd")
    assert(type(sys_cmd == 'string'), "sys_cmd not number")
    local cfg = self.cfg
    cfg.sys_cmd = sys_cmd
    return self
end

---#desc 设置整点报时类型
---@param point_type number 报时类型
---@return table 对象
function M:set_point_type(point_type)
    assert(not self.is_builder, "builded can`t use set_point_type")
    assert(type(point_type == 'number'), "point_type not number")
    local cfg = self.cfg
    cfg.point_type = point_type
    return self
end

---#desc 指定几月
---@param month number 几月[1,12]
---@return table 对象
function M:set_month(month)
    assert(not self.is_builder, "builded can`t use set_month")
    assert(month >= 1 and month <= 12, "Must be within this range[1,12] month=" .. tostring(month))
    local cfg = self.cfg
    cfg.month = month
    return self
end

---#desc 指定月第几天
---@param day number 月第几天[1,31]
---@return table 对象
function M:set_day(day)
    assert(not self.is_builder, "builded can`t use set_day")
    assert(day >= 1 and day <= 31, "Must be within this range[1,31] day=" .. tostring(day))
    local cfg = self.cfg
    cfg.day = day
    return self
end

---#desc 几时
---@param hour number 几时[0,23]
---@return table 对象
function M:set_hour(hour)
    assert(not self.is_builder, "builded can`t use set_hour")
    assert(hour >= 0 and hour <= 23, "Must be within this range[0,23] hour=" .. tostring(hour))
    local cfg = self.cfg
    cfg.hour = hour
    return self
end

---#desc 几分
---@param min number 几分[0,59]
---@return table 对象
function M:set_min(min)
    assert(not self.is_builder, "builded can`t use set_min")
    assert(min >= 0 and min <= 59, "Must be within this range[0,59] min=" .. tostring(min))
    local cfg = self.cfg
    cfg.min = min
    return self
end

---#desc 几秒
---@param sec number 几秒[0,59]
---@return table 对象
function M:set_sec(sec)
    assert(not self.is_builder, "builded can`t use set_sec")
    assert(sec >= 0 and sec <= 59, "Must be within this range[0,59] sec=" .. tostring(sec))
    local cfg = self.cfg
    cfg.sec = sec
    return self
end

---#desc 周几（仅仅设置每周有效）
---@param wday number 周几[1,7]
---@return table 对象
function M:set_wday(wday)
    assert(not self.is_builder, "builded can`t use set_wday")
    assert(wday >= 1 and wday <= 7, "Must be within this range[1,7] sec=" .. tostring(wday))
    local cfg = self.cfg
    cfg.wday = wday
    return self
end

---#desc 一年第几天（仅仅设置每年第几天有效）
---@param yday number 周几[1,366]
---@return table 对象
function M:set_yday(yday)
    assert(not self.is_builder, "builded can`t use set_yday")
    assert(yday >= 1 and yday <= 366, "Must be within this range[1,366] sec=" .. tostring(yday))
    local cfg = self.cfg
    cfg.yday = yday
    return self
end

---#desc 设置保留文件整理匹配表达式
---@param back_pattern string find表达式
---@return table 对象
function M:set_back_pattern(back_pattern)
    assert(not self.is_builder, "builded can`t use set_back_pattern")
    assert(type(back_pattern) == 'string', "back_pattern not string")
    local cfg = self.cfg
    cfg.back_pattern = back_pattern
    return self
end

---#desc 构建轮转
---@return table 对象
function M:builder()
    assert(not self.is_builder, "builded can`t use builder")
    self.is_builder = true
    local id = alloc_id()
    self.id = id
    contriner_client:instance("logrotate_m"):mod_call("add_rotate", skynet.self(), self.cfg, id)
    g_rotate_map[id] = self
    return self
end

---#desc 取消轮转
---@return table 对象
function M:cancel()
    assert(self.is_builder, "not builder can`t use cancel")
    contriner_client:instance("logrotate_m"):mod_call("cancel", skynet.self(), self.id)
    g_rotate_map[self.id] = nil
    return self
end

return M