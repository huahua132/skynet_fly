
local skynet = require "skynet"
local contriner_client = require "contriner_client"

local setmetatable = setmetatable
local assert = assert
local type = type
local xx_pcall = xx_pcall

local M = {}
local meta = {__index = M}
local cluster_client = nil

--[[
	函数作用域：M 的成员函数
	函数名称: new
	描述:创建一个skynet远程rpc调用对象
	参数:
		- svr_name (string): 结点名称
		- instance_name (string): 对端模板名称
]]
function M:new(svr_name,module_name,instance_name)
	assert(svr_name,"not svr_name")
	assert(module_name,"not module_name")
	local t = {
		svr_name = svr_name,
		module_name = module_name,
		instance_name = instance_name,
	}

	if not cluster_client then
		cluster_client = contriner_client:new("cluster_client_m")
	end

	setmetatable(t,meta)

	return t
end

function M:set_mod_num(num)
	assert(type(num) == 'number')
	self.mod_num = num
end

function M:set_instance_name(name)
	self.instance_name = name
end
--------------------------------------------------------------------------------
--one
--------------------------------------------------------------------------------
--[[
	函数作用域：M:new 对象的成员函数
	函数名称：one_balance_send
	描述：用简单轮询负载均衡给单个结点的module_name模板用balance_send的方式发送消息
]]
function M:one_balance_send(...)
	cluster_client:balance_send("balance_send",self.svr_name,"balance_send",self.module_name,...)
end

--[[
	函数作用域：M:new 对象的成员函数
	函数名称：one_balance_call
	描述：用简单轮询负载均衡给单个结点的module_name模板用balance_call的方式发送消息
]]
function M:one_balance_call(...)
	return xx_pcall(cluster_client.balance_call,cluster_client,"balance_call",self.svr_name,"balance_call",self.module_name,...)
end

--[[
	函数作用域：M:new 对象的成员函数
	函数名称：one_mod_send
	描述：用简单轮询负载均衡给单个结点的module_name模板用mod_send的方式发送消息
]]
function M:one_mod_send(...)
	cluster_client:balance_send("balance_send",self.svr_name,"mod_send",self.module_name,self.mod_num or skynet.self(), ...)
end

--[[
	函数作用域：M:new 对象的成员函数
	函数名称：one_mod_call
	描述：用简单轮询负载均衡给单个结点的module_name模板用mod_call的方式发送消息
]]
function M:one_mod_call(...)
	return xx_pcall(cluster_client.balance_call,cluster_client,"balance_call",self.svr_name,"mod_call",self.module_name,self.mod_num or skynet.self(),...)
end

--[[
	函数作用域：M:new 对象的成员函数
	函数名称：one_broadcast
	描述：用简单轮询负载均衡给单个结点的module_name模板用broadcast的方式发送消息
]]
function M:one_broadcast(...)
	cluster_client:balance_send("balance_send",self.svr_name,"broadcast",self.module_name,...)
end

--------------------------------------------------------------------------------
--one
--------------------------------------------------------------------------------


--------------------------------------------------------------------------------
--all
--------------------------------------------------------------------------------

--[[
	函数作用域：M:new 对象的成员函数
	函数名称：all_balance_send
	描述：给所有结点的module_name模板用balance_send的方式发送消息
]]
function M:all_balance_send(...)
	cluster_client:balance_send("send_all",self.svr_name,"balance_send",self.module_name,...)
end

--[[
	函数作用域：M:new 对象的成员函数
	函数名称：all_balance_call
	描述：给所有结点的module_name模板用balance_call的方式发送消息
]]
function M:all_balance_call(...)
	return xx_pcall(cluster_client.balance_call,cluster_client,"call_all",self.svr_name,"balance_call",self.module_name,...)
end

--[[
	函数作用域：M:new 对象的成员函数
	函数名称：all_mod_send
	描述：给所有结点的module_name模板用mod_send的方式发送消息
]]
function M:all_mod_send(...)
	cluster_client:balance_send("send_all",self.svr_name,"mod_send",self.module_name,self.mod_num or skynet.self(),...)
end

--[[
	函数作用域：M:new 对象的成员函数
	函数名称：all_mod_call
	描述：给所有结点的module_name模板用mod_call的方式发送消息
]]
function M:all_mod_call(...)
	return xx_pcall(cluster_client.balance_call,cluster_client,"call_all",self.svr_name,"mod_call",self.module_name,self.mod_num or skynet.self(),...)
end

--[[
	函数作用域：M:new 对象的成员函数
	函数名称：all_broadcast
	描述：给所有结点的module_name模板用broadcast的方式发送消息
]]
function M:all_broadcast(...)
	cluster_client:balance_send("send_all",self.svr_name,"broadcast",self.module_name,...)
end
--------------------------------------------------------------------------------
--all
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--one_by_name
--------------------------------------------------------------------------------

--[[
	函数作用域：M:new 对象的成员函数
	函数名称：one_balance_send_by_name
	描述：用简单轮询负载均衡给单个结点的module_name模板用balance_send_by_name的方式发送消息
]]
function M:one_balance_send_by_name(...)
	assert(self.instance_name,"not instance_name")
	cluster_client:balance_send("balance_send",self.svr_name,"balance_send_by_name",self.module_name,self.instance_name,...)
end

--[[
	函数作用域：M:new 对象的成员函数
	函数名称：one_balance_call_by_name
	描述：用简单轮询负载均衡给单个结点的module_name模板用balance_call_by_name的方式发送消息
]]
function M:one_balance_call_by_name(...)
	assert(self.instance_name,"not instance_name")
	return xx_pcall(cluster_client.balance_call,cluster_client,"balance_call",self.svr_name,"balance_call_by_name",self.module_name,self.instance_name,...)
end

--[[
	函数作用域：M:new 对象的成员函数
	函数名称：one_mod_send_by_name
	描述：用简单轮询负载均衡给单个结点的module_name模板用mod_send_by_name的方式发送消息
]]
function M:one_mod_send_by_name(...)
	assert(self.instance_name,"not instance_name")
	cluster_client:balance_send("balance_send",self.svr_name,"mod_send_by_name",self.module_name,self.instance_name,self.mod_num or skynet.self(), ...)
end

--[[
	函数作用域：M:new 对象的成员函数
	函数名称：one_mod_call_by_name
	描述：用简单轮询负载均衡给单个结点的module_name模板用mod_call_by_name的方式发送消息
]]
function M:one_mod_call_by_name(...)
	assert(self.instance_name,"not instance_name")
	return xx_pcall(cluster_client.balance_call,cluster_client,"balance_call",self.svr_name,"mod_call_by_name",self.module_name,self.instance_name,self.mod_num or skynet.self(),...)
end

--[[
	函数作用域：M:new 对象的成员函数
	函数名称：one_broadcast
	描述：用简单轮询负载均衡给单个结点的module_name模板用broadcast_by_name的方式发送消息
]]
function M:one_broadcast_by_name(...)
	assert(self.instance_name,"not instance_name")
	cluster_client:balance_send("balance_send",self.svr_name,"broadcast_by_name",self.module_name,self.instance_name,...)
end


--------------------------------------------------------------------------------
--one_by_name
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--all_by_name
--------------------------------------------------------------------------------
--[[
	函数作用域：M:new 对象的成员函数
	函数名称：all_balance_send_by_name
	描述：给所有结点的module_name模板用balance_send_by_name的方式发送消息
]]
function M:all_balance_send_by_name(...)
	assert(self.instance_name,"not instance_name")
	cluster_client:balance_send("send_all",self.svr_name,"balance_send_by_name",self.module_name,self.instance_name,...)
end

--[[
	函数作用域：M:new 对象的成员函数
	函数名称：all_balance_call_by_name
	描述：给所有结点的module_name模板用balance_call_by_name的方式发送消息
]]
function M:all_balance_call_by_name(...)
	assert(self.instance_name,"not instance_name")
	return xx_pcall(cluster_client.balance_call,cluster_client,"call_all",self.svr_name,"balance_call_by_name",self.module_name,self.instance_name,...)
end

--[[
	函数作用域：M:new 对象的成员函数
	函数名称：all_mod_send_by_name
	描述：给所有结点的module_name模板用mod_send_by_name的方式发送消息
]]
function M:all_mod_send_by_name(...)
	assert(self.instance_name,"not instance_name")
	cluster_client:balance_send("send_all",self.svr_name,"mod_send_by_name",self.module_name,self.instance_name,self.mod_num or skynet.self(), ...)
end

--[[
	函数作用域：M:new 对象的成员函数
	函数名称：all_mod_call_by_name
	描述：给所有结点的module_name模板用mod_call_by_name的方式发送消息
]]
function M:all_mod_call_by_name(...)
	assert(self.instance_name,"not instance_name")
	return xx_pcall(cluster_client.balance_call,cluster_client,"call_all",self.svr_name,"mod_call_by_name",self.module_name,self.instance_name,self.mod_num or skynet.self(),...)
end

--[[
	函数作用域：M:new 对象的成员函数
	函数名称：all_broadcast
	描述：给所有结点的module_name模板用broadcast_by_name的方式发送消息
]]
function M:all_broadcast_by_name(...)
	assert(self.instance_name,"not instance_name")
	cluster_client:balance_send("send_all",self.svr_name,"broadcast_by_name",self.module_name,self.instance_name,...)
end
--------------------------------------------------------------------------------
--all_by_name
--------------------------------------------------------------------------------

return M