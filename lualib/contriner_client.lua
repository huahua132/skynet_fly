local skynet = require "skynet"
local setmetatable = setmetatable
local assert = assert
local pairs = pairs
local ipairs = ipairs
local type = type

local M = {}
local meta = {__index = M}
local default_can_switch = function() return true end 

local skynet_exit = skynet.exit

local SELF_ADDRESS = skynet.self()
local IS_CLOSE = false

local g_mod_svr_version_map = {}
local g_name_id_list_map = {}
local g_is_watch_map = {}

local function monitor(t,key)
	while not IS_CLOSE do
		local old_version = g_mod_svr_version_map[key]
		local id_list,name_id_list,version = skynet.call('.contriner_mgr','lua','watch',key,old_version)
		t[key] = id_list
		g_mod_svr_version_map[key] = version
		g_name_id_list_map[key] = name_id_list
	end
end

local g_mod_svr_ids_map = setmetatable({},{__index = function(t,key)
	t[key],g_name_id_list_map[key],g_mod_svr_version_map[key] = skynet.call('.contriner_mgr','lua','query',key)
	skynet.error("query ",t[key],g_name_id_list_map[key],g_mod_svr_version_map[key])
	assert(t[key],"query err " .. key)
	if not g_is_watch_map[key] then
		g_is_watch_map[key] = true
		skynet.fork(monitor,t,key)
	end
	return t[key],g_mod_svr_version_map[key]
end})

skynet.exit = function()
	IS_CLOSE = true
	for mod_name in pairs(g_mod_svr_ids_map) do
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

local function get_name_balance(t)
	assert(t.instance_name,"not instance_name")
	local cur_name_id_list = t.cur_name_id_list
	assert(cur_name_id_list[t.instance_name],"not svr " .. t.instance_name)
	local id_list = cur_name_id_list[t.instance_name]

	local len = #id_list
    local balance = t.name_balance
    t.name_balance = t.name_balance + 1
    if t.name_balance > len then
        t.name_balance = 1
    end
    
    return id_list[balance]
end

local function get_mod(t)
    local id_list = t.cur_id_list
    local len = #id_list
	local mod = t.mod_num or SELF_ADDRESS
	skynet.error("get_name_mod:",mod,t.mod_num,SELF_ADDRESS)
    return id_list[mod % len + 1]
end

local function get_name_mod(t)
	assert(t.instance_name,"not instance_name")
	local cur_name_id_list = t.cur_name_id_list
	assert(cur_name_id_list[t.instance_name],"not svr " .. t.instance_name)

	local mod = t.mod_num or SELF_ADDRESS
	local id_list = cur_name_id_list[t.instance_name]
	local len = #id_list
	return id_list[mod % len + 1]
end

local function switch_svr(t)
	if t.can_switch_func() then
		t.cur_id_list = g_mod_svr_ids_map[t.module_name]
		t.cur_name_id_list = g_name_id_list_map[t.module_name]
		t.balance = 1
		t.name_balance = 1
	end
end

function M:new(module_name,instance_name,can_switch_func)
	assert(module_name)
	if not can_switch_func then
		can_switch_func = default_can_switch
	end
    local t = {
        can_switch_func = can_switch_func, 			 --是否可以切服
        module_name = module_name,         			 --模块名称
		instance_name = instance_name,
        cur_id_list = g_mod_svr_ids_map[module_name],--正在使用的服务id列表
        balance = 1,
		cur_name_id_list = g_name_id_list_map[module_name],
		name_balance = 1,
    }

    setmetatable(t,meta)
    return t
end

--设置mod映射访问的数字 如果没有设置，默认使用 自身服务id % 服务数量
function M:set_mod_num(num)
	assert(type(num) == 'number')
	self.mod_num = num
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

function M:mod_send_by_name(...)
	switch_svr(self)
	skynet.send(get_name_mod(self),'lua',...)
end

function M:mod_call_by_name(...)
	switch_svr(self)
	return skynet.call(get_name_mod(self),'lua',...)
end

function M:balance_send_by_name(...)
	switch_svr(self)
	skynet.send(get_name_balance(self),'lua',...)
end

function M:balance_call_by_name(...)
	switch_svr(self)
	return skynet.call(get_name_balance(self),'lua',...)
end

function M:broadcast(...)
	switch_svr(self)
	local id_list = self.cur_id_list
	for _,id in ipairs(id_list) do
		skynet.send(id,'lua',...)
	end
end

function M:broadcast_by_name(...)
	assert(self.instance_name,"not instance_name")
	local cur_name_id_list = self.cur_name_id_list
	assert(cur_name_id_list[self.instance_name],"not svr " .. self.instance_name)
	switch_svr(self)

	local id_list = cur_name_id_list[self.instance_name]
	for _,id in ipairs(id_list) do
		skynet.send(id,'lua',...)
	end
end

return M