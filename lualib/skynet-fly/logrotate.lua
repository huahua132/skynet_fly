local contriner_client = require "skynet-fly.client.contriner_client"
local skynet_util = require "skynet-fly.utils.skynet_util"
local contriner_interface = require "skynet-fly.contriner.contriner_interface"
local table_util = require "skynet-fly.utils.table_util"
local skynet = require "skynet"

local setmetatable = setmetatable
local assert = assert
local type = type
local pairs = pairs

local g_alloc_id = 1
local function alloc_id()
    local id = g_alloc_id
    g_alloc_id = g_alloc_id + 1
    return id
end

local g_rotate_map = {}

contriner_client:register("logrotate_m")

--logrotate的服务更新之后需要重新发送切割任务
contriner_client:add_updated_cb("logrotate_m", function()
    for id, obj in table_util.sort_ipairs_byk(g_rotate_map) do
        obj.is_builder = false
        obj:builder()
    end
end)

if skynet_util.is_hot_container_server() then
    contriner_interface.hook_fix_exit_after(function()
        contriner_client:instance("logrotate_m"):mod_call("cancel_all", skynet.self())
    end)
end

local M = {}
local mt = {__index = M}

function M:new(filename)
    local t = {
        cfg = {
            filename = filename,
        },
        is_builder = false,
    }
    setmetatable(t, mt)
    return t
end

--重命名文件格式
function M:set_rename_format(rename_format)
    assert(not self.is_builder, "builded can`t use set_rename_format")
    assert(type(rename_format) == 'string', "rename_format not string")
    local cfg = self.cfg
    cfg.rename_format = rename_format
    return self
end

--设置文件路径
function M:set_file_path(file_path)
    assert(not self.is_builder, "builded can`t use set_file_path")
    assert(type(file_path) == 'string', "file_path not string")
    local cfg = self.cfg
    cfg.file_path = file_path
    return self
end

--设置至少多大才会切割
function M:set_limit_size(limit_size)
    assert(not self.is_builder, "builded can`t use set_limit_size")
    assert(type(limit_size) == 'number', "limit_size not number")

    local cfg = self.cfg
    cfg.limit_size = limit_size
    return self
end

--设置最大保留天数
function M:set_max_age(max_age)
    assert(not self.is_builder, "builded can`t use set_max_age")
    assert(type(max_age) == 'number', "max_age not number")

    local cfg = self.cfg
    cfg.max_age = max_age
    return self
end

--设置最大保留文件数
function M:set_max_backups(max_backups)
    assert(not self.is_builder, "builded can`t use set_max_backups")
    assert(type(max_backups) == 'number', "max_backups not number")

    local cfg = self.cfg
    cfg.max_backups = max_backups
    return self
end

--设置轮转时调用系统命令
function M:set_sys_cmd(sys_cmd)
    assert(not self.is_builder, "builded can`t use set_sys_cmd")
    assert(type(sys_cmd == 'string'), "sys_cmd not number")
    local cfg = self.cfg
    cfg.sys_cmd = sys_cmd
    return self
end

--设置整点报时类型
function M:set_point_type(point_type)
    assert(not self.is_builder, "builded can`t use set_point_type")
    assert(type(point_type == 'number'), "point_type not number")
    local cfg = self.cfg
    cfg.point_type = point_type
    return self
end
--[[
    函数作用域：M:new 对象的成员函数
	函数名称：set_month
	描述:  指定几月
	参数:
		- month (number): 月份 1-12
    
]]
function M:set_month(month)
    assert(not self.is_builder, "builded can`t use set_month")
    assert(month >= 1 and month <= 12)
    self.month = month
    return self
end
--[[
    函数作用域：M:new 对象的成员函数
	函数名称：set_day
	描述:  每月第几天,超过适配到最后一天
	参数:
		- day (number): 天数 1-31
]]
function M:set_day(day)
    assert(not self.is_builder, "builded can`t use set_day")
    assert(day >= 1 and day <= 31)
    self.day = day
    return self
end
--[[
    函数作用域：M:new 对象的成员函数
	函数名称：set_hour
	描述:  几时
	参数:
		- hour (number): 几时 0-23
]]
function M:set_hour(hour)
    assert(not self.is_builder, "builded can`t use set_hour")
    assert(hour >= 0 and hour <= 23)
    self.hour = hour
    return self
end
--[[
    函数作用域：M:new 对象的成员函数
	函数名称：set_min
	描述:  几分
	参数:
		- min (number): 几分 0-59
]]
function M:set_min(min)
    assert(not self.is_builder, "builded can`t use set_min")
    assert(min >= 0 and min <= 59)
    self.min = min
    return self
end
--[[
    函数作用域：M:new 对象的成员函数
	函数名称：set_sec
	描述:  几秒
	参数:
		- sec (number): 几秒 0-59
]]
function M:set_sec(sec)
    assert(not self.is_builder, "builded can`t use set_sec")
    assert(sec >= 0 and sec <= 59)
    self.sec = sec
    return self
end

--[[
    函数作用域：M:new 对象的成员函数
	函数名称：set_wday
	描述:  周几（仅仅设置每周有效）
	参数:
		- wday (number): 周几 1-7 星期天为 1
]]
function M:set_wday(wday)
    assert(not self.is_builder, "builded can`t use set_wday")
    assert(wday >= 1 and wday <= 7)
    self.wday = wday
    return self
end

--[[
    函数作用域：M:new 对象的成员函数
	函数名称：set_yday
	描述:  一年第几天（仅仅设置每年第几天有效）
	参数:
		- yday (number): 第几天 1-366 超过适配到最后一天。
]]
function M:set_yday(yday)
    assert(not self.is_builder, "builded can`t use set_yday")
    assert(yday >= 1 and yday <= 366)
    self.yday = yday
    return self
end

--构建轮转
function M:builder()
    assert(not self.is_builder, "builded can`t use builder")
    self.is_builder = true
    local id = alloc_id()
    self.id = id
    contriner_client:instance("logrotate_m"):mod_call("add_rotate", skynet.self(), self.cfg, id)
    g_rotate_map[id] = self
    return self
end

--取消轮转
function M:cancel()
    assert(self.is_builder, "not builder can`t use cancel")
    contriner_client:instance("logrotate_m"):mod_call("cancel", skynet.self(), self.id)
    g_rotate_map[self.id] = nil
    return self
end

return M