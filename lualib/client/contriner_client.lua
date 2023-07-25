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
		local old_t = t.cur_id_list
		t.cur_id_list = g_mod_svr_ids_map[t.module_name]
		t.cur_name_id_list = g_name_id_list_map[t.module_name]

		if old_t ~= t.cur_id_list then
			t.balance = 1
			t.name_balance = 1
		end
	end
end

--[[
	函数作用域：M 的成员函数
	函数名称: new
	描述:创建一个skynet内部rpc调用对象
	参数:
		- module_name (string): 模块名称，需要send或者call通信的模块名称
		- instance_name (string): 实例名称，它是模块的二级分类
		- can_switch_func (function): 是否可以切服，当连接的模块服务地址更新后，是否要切换到新服务，每次发消息的时候都会检测是否切服
]]
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

--[[
	函数作用域：M:new 对象的成员函数
	函数名称：set_mod_num
	描述：设置mod映射访问的数字 如果没有设置，mod消息时默认使用 自身服务id % 服务数量
	参数：
		- num (number): 设置所有用mod发消息的模除以模块服务的数量作为下标映射，没有设置的情况下，默认 用自身服务id
]]
function M:set_mod_num(num)
	assert(type(num) == 'number')
	self.mod_num = num
end
--[[
	函数作用域：M:new 对象的成员函数
	函数名称：set_instance_name
	描述：设置二级名称
	参数：
		- name (string): 
]]
function M:set_instance_name(name)
	assert(type(name) == 'string')
	self.instance_name = name
end
--[[
	函数作用域：M:new 对象的成员函数
	函数名称：get_mod_server_id
	描述: 获取通过mod取到的对应服务id
]]
function M:get_mod_server_id()
	return get_mod(self)
end

--[[
	函数作用域：M:new 对象的成员函数
	函数名称：get_balance_server_id
	描述: 获取通过balance取到的对应服务id，balance是简单轮询负载均衡，如果有服务id列表[1,2,3,4]，5次的结果是1,2,3,4,1
]]
function M:get_balance_server_id()
	return get_balance(self)
end

--[[
	函数作用域：M:new 对象的成员函数
	函数名称：get_mod_server_id_by_name
	描述: 在instance_name二级分类中，获取通过mod取到的对应服务id,mod是简单hash映射
	如果有服务id列表[1,2,3,4]，设置mod_num等于3，instance_name等于game，实例名称对应列表(game)[1,2] (hall)[3,4] 每次调用结果都是2
]]
function M:get_mod_server_id_by_name()
	return get_name_mod(self)
end

--[[
	函数作用域：M:new 对象的成员函数
	函数名称：get_balance_server_id_by_name
	描述: 在instance_name二级分类中，获取通过balance取到的对应服务id,balance是简单轮询负载均衡
	如果有服务id列表[1,2,3,4]，设置instance_name等于game，实例名称对应列表(game)[1,2] (hall)[3,4] 5次的结果是1,2,1,2,1
]]
function M:get_balance_server_id_by_name()
	return get_name_balance(self)
end

--[[
	函数作用域：M:new 对象的成员函数
	函数名称：mod_send
	描述: mod hash映射一个服务id，并send skynet lua消息
]]
function M:mod_send(...)
	switch_svr(self)
	skynet.send(get_mod(self),'lua',...)
end

--[[
	函数作用域：M:new 对象的成员函数
	函数名称：mod_call
	描述: mod hash在module_name列表中映射一个服务id，并call skynet lua消息
]]
function M:mod_call(...)
	switch_svr(self)
	return skynet.call(get_mod(self),'lua',...)
end

--[[
	函数作用域：M:new 对象的成员函数
	函数名称：balance_send
	描述:  balance简单负载均衡 skynet send lua消息
]]
function M:balance_send(...)
	switch_svr(self)
	return skynet.send(get_balance(self),'lua',...)
end

--[[
	函数作用域：M:new 对象的成员函数
	函数名称：balance_call
	描述:  balance简单负载均衡 skynet call lua消息
]]
function M:balance_call(...)
	switch_svr(self)
	return skynet.call(get_balance(self),'lua',...)
end

--[[
	函数作用域：M:new 对象的成员函数
	函数名称：mod_send_by_name
	描述:  mod hash在instance_name服务列表中映射一个服务id skynet send lua消息
]]
function M:mod_send_by_name(...)
	switch_svr(self)
	skynet.send(get_name_mod(self),'lua',...)
end

--[[
	函数作用域：M:new 对象的成员函数
	函数名称：mod_call_by_name
	描述:  mod hash在instance_name服务列表中映射一个服务id skynet call lua消息
]]
function M:mod_call_by_name(...)
	switch_svr(self)
	return skynet.call(get_name_mod(self),'lua',...)
end

--[[
	函数作用域：M:new 对象的成员函数
	函数名称：balance_send_by_name
	描述:  简单负载均衡在instance_name服务列表中轮询服务id skynet send lua消息
]]
function M:balance_send_by_name(...)
	switch_svr(self)
	skynet.send(get_name_balance(self),'lua',...)
end

--[[
	函数作用域：M:new 对象的成员函数
	函数名称：balance_call_by_name
	描述:  简单负载均衡在instance_name服务列表中轮询服务id skynet call lua消息
]]
function M:balance_call_by_name(...)
	switch_svr(self)
	return skynet.call(get_name_balance(self),'lua',...)
end

--[[
	函数作用域：M:new 对象的成员函数
	函数名称：broadcast
	描述:  广播在module_name服务列表中的服务id skynet send lua消息
]]
function M:broadcast(...)
	switch_svr(self)
	local id_list = self.cur_id_list
	for _,id in ipairs(id_list) do
		skynet.send(id,'lua',...)
	end
end

--[[
	函数作用域：M:new 对象的成员函数
	函数名称：broadcast_by_name
	描述:  广播在instance_name服务列表中的服务id skynet send lua消息
]]
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