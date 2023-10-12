local skynet = require "skynet"

local assert = assert
local table = table
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

return M