local skynet = require "skynet"
local setmetatable = setmetatable

local M = {}
local SELF_ADDRESS = skynet.self()

local function get_balance(t)
    local id_list = t.cur_id_list
    local len = #id_list
    local balance = t.balance
    t.balance = t.balance + 1
    if t.balance > len then
        t.balance = 1
    end
    
    return balance
end

local function get_mod(t)
    local id_list = t.cur_id_list
    local len = #id_list
    return len % SELF_ADDRESS
end

function M:new(module_name,can_switch_func)
    local t = {
        can_switch_func = can_switch_func, --是否可以切服
        module_name = module_name,         --模块名称
        cur_id_list = {},                  --正在使用的服务id列表
        balance = 1,
    }

    skynet.call()
    setmetatable(t,self)
    return t
end

function M:mod_send()

end

function M:mod_call()

end

function M:balance_send()

end

function M:balance_call()

end

return M