---#API
---#content ---
---#content title: skynet_util skynet相关
---#content date: 2024-06-29 22:00:00
---#content categories: ["skynet_fly API 文档","工具函数"]
---#content category_bar: true
---#content tags: [skynet_fly_api]
---#content ---
---#content [skynet_util](https://github.com/huahua132/skynet_fly/blob/master/lualib/skynet-fly/utils/skynet_util.lua)
local skynet = require "skynet"
local module_info = require "skynet-fly.etc.module_info"
local log = require "skynet-fly.log"
local table_util = require "skynet-fly.utils.table_util"
local json = require "cjson"

local debug_getinfo = debug.getinfo
local tonumber = tonumber
local assert = assert
local table = table
local type = type
local next = next

local retpack = skynet.retpack
local NOT_RET = {}

local g_is_regiter = false

local g_CMD = nil

local M = {
    NOT_RET = NOT_RET
}

local function rsp_retpack(arg1, ...)
    if arg1 == M.NOT_RET then return end
    retpack(arg1, ...)
end

---#desc 注册lua消息处理函数
---@param cmd_func table 函数表
function M.lua_dispatch(cmd_func) 
    assert(not g_is_regiter, "repeat lua_dispatch")
    
    g_is_regiter = true
    assert(cmd_func)
    
    skynet.dispatch('lua',function(session,source,cmd,...)
        local f = cmd_func[cmd]
        assert(f,'cmd no found :'..cmd .. ' from : ' .. skynet.address(source))

        if session == 0 then
            f(...)
        else
            rsp_retpack(f(...))
        end
    end)
end

---#desc 注册lua消息处理函数(带source)
---@param cmd_func table 函数表
function M.lua_src_dispatch(cmd_func)
    assert(not g_is_regiter, "repeat lua_src_dispatch")
    g_is_regiter = true

    assert(cmd_func)
    
    skynet.dispatch('lua',function(session,source,cmd,...)
        local f = cmd_func[cmd]
        assert(f,'cmd no found :'..cmd .. ' from : ' .. source)
        
        if session == 0 then
            f(source, ...)
        else
            rsp_retpack(f(source, ...))
        end
    end)
end

---#desc 用于转换成number的服务地址 比如 :00000001 转成 1
---@param name string 名称
function M.number_address(name)
	local t = type(name)
	if t == "number" then
		return name
	elseif t == "string" then
		local hex = name:match "^:(%x+)"
		if hex then
			return tonumber(hex, 16)
		end
	end
end

local g_info_func_map = {}

local old_skynet_info_func = skynet.info_func
skynet.info_func = function(func)
    local info = debug_getinfo(2,"S")
    local key = info.short_src
    g_info_func_map[key] = func
end

old_skynet_info_func(function()
    local info = {}
    for name,func in table_util.sort_ipairs_byk(g_info_func_map) do
        info[name] = func()
    end

    return json.encode(info)
end)

---#desc 注册info_name信息的生成函数
---@param info_name string 名称
---@param info_func function 生成函数
function M.register_info_func(info_name,info_func)
    assert(type(info_func) == 'function', "not is function")
    assert(type(info_name) == 'string',"not is string")
    assert(not g_info_func_map[info_name], " exists " .. info_name)

    g_info_func_map[info_name] = info_func
end

---#desc 设置服务的CMD表
---@param CMD table 表
function M.set_cmd_table(CMD)
    g_CMD = CMD
end

---#desc 扩展CMD函数
---@param cmd_name string 命令名称
---@param func function 对应函数
function M.extend_cmd_func(cmd_name, func)
    assert(g_CMD, "please set_cmd_table")
    assert(not g_CMD[cmd_name], "exists cmd_name " .. tostring(cmd_name))
    g_CMD[cmd_name] = func
end

---#desc 是否可热更服务
---@return boolean 结果
function M.is_hot_container_server()
    local base_info = module_info.get_base_info()
    if base_info.index then                         --是可热更服务
        return true
    else
        return false
    end
end

local g_shutdown_func_map = {}

---#desc 注册关服处理函数
---@param func function 函数
---@param sort_weight? number|nil 排序权重
function M.reg_shutdown_func(func, sort_weight)
    sort_weight = sort_weight or 0
    assert(type(func) == 'function', "not function")
    assert(type(sort_weight) == 'number', "not number")
    local info = debug_getinfo(2,"S")
    local key = info.short_src

    g_shutdown_func_map[key] = {func = func, weight = sort_weight}
end

--执行关服处理函数
function M.execute_shutdown()
    for src, info in table_util.sort_ipairs(g_shutdown_func_map, function(a, b) return a.weight > b.weight end) do
        local isok, err = x_pcall(info.func)
        if not isok then
            log.error("execute_shutdown err ", err)
        end
    end
end

return M