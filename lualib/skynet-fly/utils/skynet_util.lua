local skynet = require "skynet"

local tonumber = tonumber
local assert = assert
local table = table
local type = type
local next = next
local pairs = pairs
local retpack = skynet.retpack
local tunpack = table.unpack
local NOT_RET = {}


local M = {
    NOT_RET = NOT_RET
}

--常用的lua消息处理函数
--[[
    cmd_func 函数表
]]
function M.lua_dispatch(cmd_func) 
    assert(cmd_func)
    
    skynet.dispatch('lua',function(session,source,cmd,...)
        local f = cmd_func[cmd]
        assert(f,'cmd no found :'..cmd .. ' from : ' .. source)

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

return M