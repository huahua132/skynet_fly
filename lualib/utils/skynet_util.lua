local skynet = require "skynet"

local tonumber = tonumber
local assert = assert
local table = table
local type = type
local next = next
local pairs = pairs
local skynet_ret = skynet.ret
local skynet_pack = skynet.pack
local tunpack = table.unpack

local M = {}

--常用的lua消息处理函数
--[[
    cmd_func 函数表
    not_ret  标记本次不返回结果，一般想异步返回结果时调用。 比如用skynet.response
    is_need_src 是否传递来源服务id
]]
function M.lua_dispatch(cmd_func,not_ret,is_need_src) 
    assert(cmd_func)
    assert(not_ret)
    
    skynet.dispatch('lua',function(session,source,cmd,...)
        local f = cmd_func[cmd]
        assert(f,'cmd no found :'..cmd .. ' from : ' .. source)

        if session == 0 then
            if is_need_src then
                f(source,...)
            else
                f(...)
            end
        else
            local ret = nil
            if is_need_src then
                ret = {f(source,...)}
            else
                ret = {f(...)}
            end
            
            local r1 = ret[1]
            if r1 ~= not_ret then
                skynet_ret(skynet_pack(tunpack(ret)))
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