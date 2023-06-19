local skynet = require "skynet"
local setmetatable = setmetatable
local assert = assert
local pairs = pairs

local M = {}
local meta = {__index = M}

local skynet_exit = skynet.exit

local SELF_ADDRESS = skynet.self()

local g_mod_svr_ids_map = setmetatable({},{__index = function(t,key)
	t[key] = skynet.call('.contriner_mgr_3','lua','watch',key)
	assert(t[key],"watch err " .. key)

	skynet.error(SELF_ADDRESS .. " watch " .. key .. " address " .. table.concat(t[key],','))
	return t[key]
end})             --记录最新的服务id地址

skynet.exit = function()
	skynet.error("unwatch mod")
	for mod_name in pairs(g_mod_svr_ids_map) do
		skynet.send('contriner_mgr_3','lua','unwatch',mod_name)
	end
	return skynet_exit()
end

skynet.dispatch('lua',function(source,session,cmd,...)
	if cmd == 'watchrsp' then
		local args = {...}
		local mod_name = args[1]
		local svr_id_list = args[2]
		g_mod_svr_ids_map[mod_name] = svr_id_list
		skynet.error("watchrsp update address ",mod_name,svr_id_list)
	end
end)

local function get_balance(t)
    local id_list = t.cur_id_list
    local len = #id_list
    local balance = t.balance
    t.balance = t.balance + 1
    if t.balance > len then
        t.balance = 1
    end
    
    return id_list[balance]
end

local function get_mod(t)
    local id_list = t.cur_id_list
    local len = #id_list
    return id_list[len % SELF_ADDRESS]
end

local function switch_svr(t)
	if t.can_switch_func() then
		t.cur_id_list = g_mod_svr_ids_map[t.module_name]
		t.balance = 1
		skynet.error("switch_svr ",t.module_name,table.concat(t.cur_id_list,','))
	end
end

function M:new(module_name,can_switch_func)
    local t = {
        can_switch_func = can_switch_func, 			 --是否可以切服
        module_name = module_name,         			 --模块名称
        cur_id_list = g_mod_svr_ids_map[module_name],--正在使用的服务id列表
        balance = 1,
    }

    setmetatable(t,meta)
    return t
end

function M:mod_send(...)
	switch_svr(self)
	skynet.send(get_mod(self),'lua',...)
end

function M:mod_call(...)
	skynet.error("mod_call begin")
	switch_svr(self)
	return skynet.call(get_mod(self),'lua',...)
end

function M:balance_send(...)
	switch_svr(self)
	return skynet.send(get_balance(self),'lua',...)
end

function M:balance_call(...)
	switch_svr(self)
	return skynet.call(get_balance(self),'lua',...)
end

return M