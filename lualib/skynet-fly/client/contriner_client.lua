local skynet = require "skynet"
local module_info = require "skynet-fly.etc.module_info"
local skynet_util = require "skynet-fly.utils.skynet_util"
local wait = require "skynet-fly.time_extend.wait"
local setmetatable = setmetatable
local assert = assert
local pairs = pairs
local ipairs = ipairs
local type = type
local tostring = tostring
local tinsert = table.insert
local collectgarbage = collectgarbage

local M = {}
local meta = {__index = M}
local default_can_switch = function() return true end 

local skynet_exit = skynet.exit

local SELF_ADDRESS = skynet.self()
local IS_CLOSE = false
local is_close_swtich = false	--是否关闭服务切换
local is_ready = true   		--是否准备好了
local is_monitor_all = false

local g_mod_svr_version_map = {}
local g_name_id_list_map = {}
local g_is_watch_map = {}
local g_register_map = {}     --注册表
local g_week_visitor_map = {} --弱访问者
local g_instance_map = {}     --常驻实例
local g_queryed_map = {}      --查询到地址的回调列表
local g_querycbed_map = {}	  --查询到地址已执行回调列表
local g_updated_map = {}      --更新地址的回调列表
local g_always_swtich_map = {}--总能切换的modulename服务，不受is_close_swtich限制
local g_pre_gc_time = 0	 	  --上次调用gc的时间
local g_wait = wait:new()

local SERVICE_NAME = SERVICE_NAME
if MODULE_NAME then
	g_week_visitor_map[MODULE_NAME] = true		--自己标记为弱访问者
end
--弱引用原表
local g_week_meta = {__mode = "kv"}
local g_id_list_map = {}          --记录id_list的弱引用，用与其他服务查询该服务是否还需要访问自己
local g_mod_svr_ids_map

local g_contriner_mgr = nil

local function get_contriner_mgr_addr()
    if g_contriner_mgr then
        return g_contriner_mgr
    end
	
    g_contriner_mgr = skynet.queryservice('contriner_mgr')
    return g_contriner_mgr
end

local function add_id_list_week(module_name,id_list)
	if not g_id_list_map[module_name] then
		g_id_list_map[module_name] = setmetatable({}, g_week_meta)
	end
	tinsert(g_id_list_map[module_name],id_list)
end

local function register_visitor(id_list)
	local module_base = module_info.get_base_info()
	for _,id in ipairs(id_list) do
		if id ~= SELF_ADDRESS then
			skynet.call(id,'lua','register_visitor',SELF_ADDRESS,module_base.module_name,SERVICE_NAME)
		end
	end
end

local function switch_svr(t)
	if is_close_swtich and not g_always_swtich_map[t.module_name] then return end

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

--切换常驻实例的地址引用
local function switch_all_intance()
	for _,v in pairs(g_instance_map) do
		if v.obj then
			switch_svr(v.obj)
		end

		for _,vv in pairs(v.name_map) do
			switch_svr(vv)
		end
	end
end

local function call_back_updated(updated)
	for _,func in ipairs(updated) do
		skynet.fork(func)
	end
end

local function monitor(t,key)
	while not IS_CLOSE do
		local old_version = g_mod_svr_version_map[key]
		local id_list,name_id_list,version = skynet.call(get_contriner_mgr_addr(), 'lua', 'watch', SELF_ADDRESS, key, old_version)
		if not is_close_swtich or g_always_swtich_map[key] then
			add_id_list_week(key,id_list)
			register_visitor(id_list)
			t[key] = id_list
			g_mod_svr_version_map[key] = version
			g_name_id_list_map[key] = name_id_list
			switch_all_intance()
			local updated = g_updated_map[key]
			if updated then
				skynet.fork(call_back_updated, updated)
			end
		else
			--等待开放swtich
			g_wait:wait("open_swtich")
		end
	end
end

local function call_back_queryed(queryed)
	for _,func in ipairs(queryed) do
		skynet.fork(func)
	end
end

g_mod_svr_ids_map = setmetatable({},{__index = function(t,key)
	t[key],g_name_id_list_map[key],g_mod_svr_version_map[key] = skynet.call(get_contriner_mgr_addr(), 'lua', 'query', SELF_ADDRESS, key)
	assert(t[key],"query err " .. key)
	if not g_is_watch_map[key] then
		g_is_watch_map[key] = true
		skynet.fork(monitor,t,key)
	end
	add_id_list_week(key,t[key])
	register_visitor(t[key])
	local queryed = g_queryed_map[key]
	if queryed and not g_querycbed_map[key] then
		g_querycbed_map[key] = true
		skynet.fork(call_back_queryed, queryed)
	end
	return t[key],g_mod_svr_version_map[key]
end})

local function monitor_all()
	if is_monitor_all then return end
	is_monitor_all = true
	skynet.fork(function()
		local mod_version_map = nil
		while not IS_CLOSE do
			mod_version_map = skynet.call(get_contriner_mgr_addr(),'lua', 'monitor_new', SELF_ADDRESS, mod_version_map)
			for mod_name,_ in pairs(mod_version_map) do
				g_register_map[mod_name] = true
				local _ = g_mod_svr_ids_map[mod_name]
			end
		end
	end)
end

skynet.exit = function()
	IS_CLOSE = true
	for mod_name in pairs(g_mod_svr_ids_map) do
		skynet.send(get_contriner_mgr_addr(),'lua','unwatch',SELF_ADDRESS, mod_name)
	end
	if is_monitor_all then
		skynet.call(get_contriner_mgr_addr(),'lua', 'unmonitor_new', SELF_ADDRESS)
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

--关闭服务切换
function M:close_switch()
	is_close_swtich = true
end


--开启服务切换
function M:open_switch()
	is_close_swtich = false
	g_wait:wakeup("open_switch")
end

skynet.init(function()
	local module_base = module_info.get_base_info()
	if not module_base.module_name then                     --不是热更模块，监听所有地址
		monitor_all()
	end
end)

--模块必须全部启动好了才能查询访问其他服务
function M:open_ready()
	skynet.fork(function()
		for mod_name,_ in pairs(g_register_map) do
			local _ = g_mod_svr_ids_map[mod_name]
		end
	end)
	is_ready = true
end

function M:close_ready()
	is_ready = false
end

--注册
function M:register(...)
	local module_base = module_info.get_base_info()
	local mod_name_list = {...}
	for _,mod_name in ipairs(mod_name_list) do
		if not g_register_map[mod_name] then
			if module_base.module_name then                     --是热更模块才有这个限制
				assert(not is_ready, "ready after can`t register:" .. mod_name)
			end
			g_register_map[mod_name] = true
		end
	end
end

--设置弱访问者
function M:set_week_visitor(...)
	local mod_name_list = {...}
	for _,mod_name in ipairs(mod_name_list) do
		g_week_visitor_map[mod_name] = true
	end
end

--设置总能切换到新服务
function M:set_always_swtich(...)
	local mod_name_list = {...}
	for _,mod_name in ipairs(mod_name_list) do
		g_always_swtich_map[mod_name] = true
	end
end

--是否弱访问者
function M:is_week_visitor(module_name)
	return g_week_visitor_map[module_name]
end

--弱访问者
function M:get_week_visitor_map()
	return g_week_visitor_map
end
--是否不再需要访问
function M:is_not_need_visitor(module_name, source)
	local cur_time = skynet.now()
	--大于10分钟调用一次gc，避免因本服务长时间不gc，弱引用没释放，导致其他旧服务也长时间不退出
	if cur_time - g_pre_gc_time > 60000 then
		g_pre_gc_time = cur_time
		collectgarbage("collect")
	end

	if not g_id_list_map[module_name] then
		return true
	end
	
	local list = g_id_list_map[module_name]
	for _,one_id_list in pairs(list) do
		for _,id in ipairs(one_id_list) do
			if id == source then
				return false
			end
		end
	end

	return true
end

--访问列表
function M:get_need_visitor_map()
	return g_id_list_map
end

-- 添加查询到某服务地址的回调
function M:add_queryed_cb(module_name, func)
	assert(type(func) == 'function', "not is func")
	if not g_queryed_map[module_name] then
		g_queryed_map[module_name] = {}
	end

	tinsert(g_queryed_map[module_name], func)
end

--添加更新某服务地址的回调
function M:add_updated_cb(module_name, func)
	assert(type(func) == 'function', "not is func")
	if not g_updated_map[module_name] then
		g_updated_map[module_name] = {}
	end
	tinsert(g_updated_map[module_name], func)
end

--监听所有服务地址
function M:monitor_all()
	assert(not is_monitor_all,"repeat monitor_all")
	assert(not is_ready, "ready can`t monitor_all")
	monitor_all()
end

--扩展CMD
function M:CMD(cmd)
	--是否不再需要访问
	assert(not cmd['is_not_need_visitor'], "repeat cmd is_not_need_visitor")
	function cmd.is_not_need_visitor(source,module_name)
		return self:is_not_need_visitor(module_name, source)
	end
end

--是否是访问旧的服务
function M:is_visitor_old()
	if self.cur_id_list ~= g_mod_svr_ids_map[self.module_name] then
		return true
	end

	return false
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
	assert(g_register_map[module_name],tostring(module_name) .. " not register")
	assert(is_ready,"not is ready")
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

		send = skynet.send,
		call = skynet.call,
    }

    setmetatable(t,meta)
    return t
end

--[[
	函数作用域：M 的成员函数
	函数名称: new_raw
	描述:创建一个skynet内部rpc调用对象， send,call 使用 rawsend rawcall
	参数:
		- module_name (string): 模块名称，需要send或者call通信的模块名称
		- instance_name (string): 实例名称，它是模块的二级分类
		- can_switch_func (function): 是否可以切服，当连接的模块服务地址更新后，是否要切换到新服务，每次发消息的时候都会检测是否切服
]]
function M:new_raw(module_name,instance_name,can_switch_func)
	local t = M:new(module_name,instance_name,can_switch_func)
	t.send = skynet.rawsend
	t.call = skynet.rawcall

	return t
end

--有时候不想创建实例
function M:instance(module_name,instance_name)
	assert(module_name)
	if not g_instance_map[module_name] then
		g_instance_map[module_name] = {
			name_map = {},
			obj = nil
		}
	end

	if instance_name then
		if not g_instance_map[module_name].name_map[instance_name] then
			g_instance_map[module_name].name_map[instance_name] = M:new(module_name,instance_name)
		end
		return g_instance_map[module_name].name_map[instance_name]
	else
		if not g_instance_map[module_name].obj then
			g_instance_map[module_name].obj = M:new(module_name,instance_name)
		end
		return g_instance_map[module_name].obj
	end
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
	return self
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
	local cur_name_id_list = self.cur_name_id_list
	assert(cur_name_id_list[name],"not svr " .. name)
	self.instance_name = name
	return self
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
	self.send(get_mod(self),'lua',...)
end

--[[
	函数作用域：M:new 对象的成员函数
	函数名称：mod_call
	描述: mod hash在module_name列表中映射一个服务id，并call skynet lua消息
]]
function M:mod_call(...)
	switch_svr(self)
	return self.call(get_mod(self),'lua',...)
end

--[[
	函数作用域：M:new 对象的成员函数
	函数名称：balance_send
	描述:  balance简单负载均衡 skynet send lua消息
]]
function M:balance_send(...)
	switch_svr(self)
	return self.send(get_balance(self),'lua',...)
end

--[[
	函数作用域：M:new 对象的成员函数
	函数名称：balance_call
	描述:  balance简单负载均衡 skynet call lua消息
]]
function M:balance_call(...)
	switch_svr(self)
	return self.call(get_balance(self),'lua',...)
end

--[[
	函数作用域：M:new 对象的成员函数
	函数名称：mod_send_by_name
	描述:  mod hash在instance_name服务列表中映射一个服务id skynet send lua消息
]]
function M:mod_send_by_name(...)
	switch_svr(self)
	self.send(get_name_mod(self),'lua',...)
end

--[[
	函数作用域：M:new 对象的成员函数
	函数名称：mod_call_by_name
	描述:  mod hash在instance_name服务列表中映射一个服务id skynet call lua消息
]]
function M:mod_call_by_name(...)
	switch_svr(self)
	return self.call(get_name_mod(self),'lua',...)
end

--[[
	函数作用域：M:new 对象的成员函数
	函数名称：balance_send_by_name
	描述:  简单负载均衡在instance_name服务列表中轮询服务id skynet send lua消息
]]
function M:balance_send_by_name(...)
	switch_svr(self)
	self.send(get_name_balance(self),'lua',...)
end

--[[
	函数作用域：M:new 对象的成员函数
	函数名称：balance_call_by_name
	描述:  简单负载均衡在instance_name服务列表中轮询服务id skynet call lua消息
]]
function M:balance_call_by_name(...)
	switch_svr(self)
	return self.call(get_name_balance(self),'lua',...)
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
		self.send(id,'lua',...)
	end
end

--[[
	函数作用域：M:new 对象的成员函数
	函数名称：broadcast
	描述:  广播在module_name服务列表中的服务id skynet call lua消息
]]

function M:broadcast_call(...)
	switch_svr(self)
	local id_list = self.cur_id_list
	local ret_map = {}
	for _,id in ipairs(id_list) do
		if self.call == skynet.rawcall then
			local msg, sz = self.call(id,'lua',...)
			ret_map[id] = skynet.tostring(msg, sz)
		else
			ret_map[id] = {self.call(id,'lua',...)}
		end
	end

	return ret_map
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
		self.send(id,'lua',...)
	end
end

--[[
	函数作用域：M:new 对象的成员函数
	函数名称：broadcast_by_name
	描述:  广播在instance_name服务列表中的服务id skynet call lua消息
]]

function M:broadcast_call_by_name(...)
	assert(self.instance_name,"not instance_name")
	local cur_name_id_list = self.cur_name_id_list
	assert(cur_name_id_list[self.instance_name],"not svr " .. self.instance_name)
	switch_svr(self)

	local id_list = cur_name_id_list[self.instance_name]
	local ret_map = {}
	for _,id in ipairs(id_list) do
		if self.call == skynet.rawcall then
			local msg, sz = self.call(id,'lua',...)
			ret_map[id] = skynet.tostring(msg, sz)
		else
			ret_map[id] = {self.call(id,'lua',...)}
		end
	end
	
	return ret_map
end

return M