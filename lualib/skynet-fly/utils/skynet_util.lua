local skynet = require "skynet"
local module_info = require "skynet-fly.etc.module_info"

local tonumber = tonumber
local assert = assert
local table = table
local type = type
local next = next
local pairs = pairs
local retpack = skynet.retpack
local tunpack = table.unpack
local NOT_RET = {}

local g_is_regiter = false

local g_CMD = nil

local M = {
    NOT_RET = NOT_RET
}

--常用的lua消息处理函数
--[[
    cmd_func 函数表
]]
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
            local ret = {f(...)}
            local r1 = ret[1]
            if r1 ~= M.NOT_RET then
                retpack(tunpack(ret))
            end
        end
    end)
end

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
            local ret = {f(source, ...)}
            local r1 = ret[1]
            if r1 ~= M.NOT_RET then
                retpack(tunpack(ret))
            end
        end
    end)
end

--用于转换成number的服务地址 比如 :00000001 转成 1
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
skynet.info_func = nil

old_skynet_info_func(function()
    local info = {}
    for name,func in pairs(g_info_func_map) do
        info[name] = func()
    end

    return info
end)

--注册info_name信息的生成函数
function M.register_info_func(info_name,info_func)
    assert(type(info_func) == 'function', "not is function")
    assert(type(info_name) == 'string',"not is string")
    assert(not g_info_func_map[info_name], " exists " .. info_name)

    g_info_func_map[info_name] = info_func
end

--设置服务的CMD表
function M.set_cmd_table(CMD)
    g_CMD = CMD
end

--扩展CMD函数
function M.extend_cmd_func(cmd_name, func)
    assert(g_CMD, "please set_cmd_table")
    assert(not g_CMD[cmd_name], "exists cmd_name " .. tostring(cmd_name))
    g_CMD[cmd_name] = func
end

--是否可热更服务
function M.is_hot_container_server()
    local base_info = module_info.get_base_info()
    if base_info.index then                         --是可热更服务
        return true
    else
        return false
    end
end

return M