local skynet = require "skynet"
local setmetatable = setmetatable
local assert = assert
local pairs = pairs
local ipairs = ipairs

local M = {}
local meta = {__index = M}

local skynet_exit = skynet.exit

local SELF_ADDRESS = skynet.self()
local IS_CLOSE = false

local g_mod_svr_version_map = {}

local function monitor(t,key)
	while not IS_CLOSE do
		local old_version = g_mod_svr_version_map[key]
		skynet.error("monitor req ",key,old_version)
		local id_list,version = skynet.call('.contriner_mgr','lua','watch',key,old_version)
		t[key] = id_list
		g_mod_svr_version_map[key] = version
		skynet.error("monitor ret ",key,version)
	end

	skynet.error("monitor quit ",key)
end

local g_mod_svr_ids_map = setmetatable({},{__index = function(t,key)
	t[key],g_mod_svr_version_map[key] = skynet.call('.contriner_mgr','lua','query',key)
	assert(t[key],"query err " .. key)

	skynet.fork(monitor,t,key)
	skynet.error(SELF_ADDRESS .. " query " .. key .. " address " .. table.concat(t[key],','))
	return t[key],g_mod_svr_version_map[key]
end})

skynet.exit = function()
	IS_CLOSE = true
	skynet.error("unwatch mod")
	for mod_name in pairs(g_mod_svr_ids_map) do
		skynet.error("unwatch ",mod_name)
		skynet.send('.contriner_mgr','lua','unwatch',mod_name)
	end
	return skynet_exit()
end

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
    return id_list[SELF_ADDRESS % len + 1]
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

function M:broadcast(...)
	switch_svr(self)
	local id_list = self.cur_id_list
	for _,id in ipairs(id_list) do
		skynet.send(id,'lua',...)
	end
end

return M