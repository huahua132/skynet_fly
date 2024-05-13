
local skynet = require "skynet"
local contriner_client = require "skynet-fly.client.contriner_client"
local FRPC_PACK_ID = require "skynet-fly.enum.FRPC_PACK_ID"

local setmetatable = setmetatable
local assert = assert
local type = type
local pairs = pairs
local tinsert = table.insert
local spack = skynet.pack

contriner_client:register("frpc_client_m")

local M = {}
local meta = {__index = M}
local frpc_client_m = nil
local SELF_ADDRESS = skynet.self()

local g_instance_map = {}

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

	if not frpc_client_m then
		frpc_client_m = contriner_client:new("frpc_client_m")
	end

	setmetatable(t,meta)

	return t
end

--有时候并不想创建实例
function M:instance(svr_name,module_name,instance_name)
	assert(svr_name,"not svr_name")
	assert(module_name,"not module_name")

	if not g_instance_map[svr_name] then
		g_instance_map[svr_name] = {}
	end

	if not g_instance_map[svr_name][module_name] then
		g_instance_map[svr_name][module_name] = {
			name_map = {},
			obj = nil
		}
	end

	if instance_name then
		if not g_instance_map[svr_name][module_name].name_map[instance_name] then
			g_instance_map[svr_name][module_name].name_map[instance_name] = M:new(svr_name,module_name,instance_name)
		end
		return g_instance_map[svr_name][module_name].name_map[instance_name]
	else
		if not g_instance_map[svr_name][module_name].obj then
			g_instance_map[svr_name][module_name].obj = M:new(svr_name,module_name,instance_name)
		end
		return g_instance_map[svr_name][module_name].obj
	end
end
--指定mod映射数
function M:set_mod_num(num)
	assert(type(num) == 'number')
	self.mod_num = num
	return self
end
--指定访问实例名
function M:set_instance_name(name)
	self.instance_name = name
	return self
end
--指定服务id
function M:set_svr_id(id)
	self.svr_id = id
	return self
end

local function unpack_broadcast(rsp)
	local ret_map = skynet.unpack(rsp)
	for sid, luastr in pairs(ret_map) do
		ret_map[sid] = {skynet.unpack(luastr)}
	end
	return ret_map
end
--------------------------------------------------------------------------------
--one
--------------------------------------------------------------------------------
--用简单轮询负载均衡给单个结点的module_name模板用balance_send的方式发送消息
function M:one_balance_send(...)
	frpc_client_m:balance_send(
		"balance_send", self.svr_name, self.module_name, self.instance_name, FRPC_PACK_ID.balance_send, nil, spack(...)
	)
end

--用简单轮询负载均衡给单个结点的module_name模板用balance_call的方式发送消息
function M:one_balance_call(...)
	local cluster_name, rsp = frpc_client_m:balance_call(
		"balance_call", self.svr_name, self.module_name, self.instance_name, FRPC_PACK_ID.balance_call, nil, spack(...)
	)
	return {
		cluster_name = cluster_name,
		result = {skynet.unpack(rsp)}
	}
end

--用简单轮询负载均衡给单个结点的module_name模板用mod_send的方式发送消息
function M:one_mod_send(...)
	frpc_client_m:balance_send(
		"balance_send", self.svr_name, self.module_name, self.instance_name, FRPC_PACK_ID.mod_send, self.mod_num or SELF_ADDRESS, spack(...)
	)
end

--用简单轮询负载均衡给单个结点的module_name模板用mod_call的方式发送消息
function M:one_mod_call(...)
	local cluster_name, rsp = frpc_client_m:balance_call(
		"balance_call", self.svr_name, self.module_name, self.instance_name, FRPC_PACK_ID.mod_call, self.mod_num or SELF_ADDRESS, spack(...)
	)
	return {
		cluster_name = cluster_name,
		result = {skynet.unpack(rsp)}
	}
end

--用简单轮询负载均衡给单个结点的module_name模板用broadcast的方式发送消息
function M:one_broadcast(...)
	frpc_client_m:balance_send(
		"balance_send", self.svr_name, self.module_name, self.instance_name, FRPC_PACK_ID.broadcast, nil, spack(...)
	)
end

--用简单轮询负载均衡给单个结点的module_name模板用broadcast_call的方式发送消息
function M:one_broadcast_call(...)
	local cluster_name, rsp = frpc_client_m:balance_call(
		"balance_call", self.svr_name, self.module_name, self.instance_name, FRPC_PACK_ID.broadcast_call, nil, spack(...)
	)
	return {
		cluster_name = cluster_name,
		result = unpack_broadcast(rsp)
	}
end
--------------------------------------------------------------------------------
--one
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--byid
--------------------------------------------------------------------------------
--用svr_id映射的方式给单个结点的module_name模板用balance_send的方式发送消息
function M:byid_balance_send(...)
	assert(self.svr_id, "not svr_id")
	frpc_client_m:balance_send(
		"send_by_id", self.svr_name, self.svr_id, self.module_name, self.instance_name, FRPC_PACK_ID.balance_send, nil, spack(...)
	)
end

--用svr_id映射的方式给单个结点的module_name模板用balance_call的方式发送消息
function M:byid_balance_call(...)
	assert(self.svr_id, "not svr_id")
	local cluster_name, rsp = frpc_client_m:balance_call(
		"call_by_id", self.svr_name, self.svr_id, self.module_name, self.instance_name, FRPC_PACK_ID.balance_call, nil, spack(...)
	)
	return {
		cluster_name = cluster_name,
		result = {skynet.unpack(rsp)}
	}
end

--用svr_id映射的方式给单个结点的module_name模板用mod_send的方式发送消息
function M:byid_mod_send(...)
	assert(self.svr_id, "not svr_id")
	frpc_client_m:balance_send(
		"send_by_id", self.svr_name, self.svr_id, self.module_name, self.instance_name, FRPC_PACK_ID.mod_send, self.mod_num or SELF_ADDRESS, spack(...)
	)
end

--用svr_id映射的方式给单个结点的module_name模板用mod_call的方式发送消息
function M:byid_mod_call(...)
	assert(self.svr_id, "not svr_id")
	local cluster_name, rsp = frpc_client_m:balance_call(
		"call_by_id", self.svr_name, self.svr_id, self.module_name, self.instance_name, FRPC_PACK_ID.mod_call,self.mod_num or SELF_ADDRESS, spack(...)
	)
	return {
		cluster_name = cluster_name,
		result = {skynet.unpack(rsp)}
	}
end

--用svr_id映射的方式给单个结点的module_name模板用broadcast的方式发送消息
function M:byid_broadcast(...)
	assert(self.svr_id, "not svr_id")
	frpc_client_m:balance_send(
		"send_by_id", self.svr_name, self.svr_id, self.module_name, self.instance_name, FRPC_PACK_ID.broadcast, nil, spack(...)
	)
end

--用svr_id映射的方式给单个结点的module_name模板用broadcast_call的方式发送消息
function M:byid_broadcast_call(...)
	assert(self.svr_id, "not svr_id")
	local cluster_name, rsp = frpc_client_m:balance_call(
		"call_by_id", self.svr_name, self.svr_id, self.module_name, self.instance_name, FRPC_PACK_ID.broadcast_call, nil, spack(...)
	)
	return {
		cluster_name = cluster_name,
		result = unpack_broadcast(rsp),
	}
end
--------------------------------------------------------------------------------
--all
--------------------------------------------------------------------------------

--给所有结点的module_name模板用balance_send的方式发送消息
function M:all_balance_send(...)
	frpc_client_m:balance_send(
		"send_all", self.svr_name, self.module_name, self.instance_name, FRPC_PACK_ID.balance_send, nil, spack(...)
	)
end

--给所有结点的module_name模板用balance_call的方式发送消息
function M:all_balance_call(...)
	local cluster_rsp_map = frpc_client_m:balance_call(
		"call_all", self.svr_name, self.module_name, self.instance_name, FRPC_PACK_ID.balance_call, nil, spack(...)
	)
	local ret_list = {}
	for cluster_name, rsp in pairs(cluster_rsp_map) do
		tinsert(ret_list, {
			cluster_name = cluster_name,
			result = {skynet.unpack(rsp)}
		})
	end
	return ret_list
end

--给所有结点的module_name模板用mod_send的方式发送消息
function M:all_mod_send(...)
	frpc_client_m:balance_send(
		"send_all", self.svr_name, self.module_name, self.instance_name, FRPC_PACK_ID.mod_send, self.mod_num or SELF_ADDRESS, spack(...)
	)
end

--给所有结点的module_name模板用mod_call的方式发送消息
function M:all_mod_call(...)
	local cluster_rsp_map = frpc_client_m:balance_call(
		"call_all", self.svr_name, self.module_name, self.instance_name, FRPC_PACK_ID.mod_call, self.mod_num or SELF_ADDRESS, spack(...)
	)
	local ret_list = {}
	for cluster_name, rsp in pairs(cluster_rsp_map) do
		tinsert(ret_list, {
			cluster_name = cluster_name,
			result = {skynet.unpack(rsp)}
		})
	end
	return ret_list
end

--给所有结点的module_name模板用broadcast的方式发送消息
function M:all_broadcast(...)
	frpc_client_m:balance_send(
		"send_all", self.svr_name, self.module_name, self.instance_name, FRPC_PACK_ID.broadcast, nil, spack(...)
	)
end

--给所有结点的module_name模板用broadcast_call的方式发送消息
function M:all_broadcast_call(...)
	local cluster_rsp_map = frpc_client_m:balance_call(
		"call_all", self.svr_name, self.module_name, self.instance_name, FRPC_PACK_ID.broadcast_call, nil, spack(...)
	)
	local ret_list = {}
	for cluster_name, rsp in pairs(cluster_rsp_map) do
		tinsert(ret_list, {
			cluster_name = cluster_name,
			result = unpack_broadcast(rsp)
		})
	end
	return ret_list
end
--------------------------------------------------------------------------------
--all
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--one_by_name
--------------------------------------------------------------------------------

--用简单轮询负载均衡给单个结点的module_name模板用balance_send_by_name的方式发送消息
function M:one_balance_send_by_name(...)
	assert(self.instance_name,"not instance_name")
	frpc_client_m:balance_send(
		"balance_send", self.svr_name, self.module_name, self.instance_name, FRPC_PACK_ID.balance_send_by_name, nil, spack(...)
	)
end

--用简单轮询负载均衡给单个结点的module_name模板用balance_call_by_name的方式发送消息
function M:one_balance_call_by_name(...)
	assert(self.instance_name,"not instance_name")
	local cluster_name, rsp = frpc_client_m:balance_call(
		"balance_call", self.svr_name, self.module_name, self.instance_name, FRPC_PACK_ID.balance_call_by_name, nil, spack(...)
	)
	return {
		cluster_name = cluster_name,
		result = {skynet.unpack(rsp)}
	}
end

--用简单轮询负载均衡给单个结点的module_name模板用mod_send_by_name的方式发送消息
function M:one_mod_send_by_name(...)
	assert(self.instance_name,"not instance_name")
	frpc_client_m:balance_send(
		"balance_send",self.svr_name, self.module_name, self.instance_name, FRPC_PACK_ID.mod_send_by_name, self.mod_num or SELF_ADDRESS, spack(...)
	)
end

--用简单轮询负载均衡给单个结点的module_name模板用mod_call_by_name的方式发送消息
function M:one_mod_call_by_name(...)
	assert(self.instance_name,"not instance_name")
	local cluster_name, rsp = frpc_client_m:balance_call(
		"balance_call", self.svr_name, self.module_name, self.instance_name, FRPC_PACK_ID.mod_call_by_name, self.mod_num or SELF_ADDRESS,spack(...)
	)
	return {
		cluster_name = cluster_name,
		result = {skynet.unpack(rsp)}
	}
end

--用简单轮询负载均衡给单个结点的module_name模板用broadcast_by_name的方式发送消息
function M:one_broadcast_by_name(...)
	assert(self.instance_name,"not instance_name")
	frpc_client_m:balance_send(
		"balance_send", self.svr_name, self.module_name, self.instance_name, FRPC_PACK_ID.broadcast_by_name, nil, spack(...)
	)
end


--用简单轮询负载均衡给单个结点的module_name模板用broadcast_call_by_name的方式发送消息
function M:one_broadcast_call_by_name(...)
	assert(self.instance_name,"not instance_name")
	local cluster_name, rsp = frpc_client_m:balance_call(
		"balance_call", self.svr_name, self.module_name, self.instance_name, FRPC_PACK_ID.broadcast_call_by_name, nil, spack(...)
	)
	return {
		cluster_name = cluster_name,
		result = unpack_broadcast(rsp)
	}
end
--------------------------------------------------------------------------------
--one_by_name
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--byid_by_name
--------------------------------------------------------------------------------

--用svr_id映射的方式给单个结点的module_name模板用balance_send_by_name的方式发送消息
function M:byid_balance_send_by_name(...)
	assert(self.instance_name,"not instance_name")
	assert(self.svr_id,"not svr_id")
	frpc_client_m:balance_send(
		"send_by_id",self.svr_name, self.svr_id, self.module_name, self.instance_name, FRPC_PACK_ID.balance_send_by_name, nil, spack(...)
	)
end

--用svr_id映射的方式给单个结点的module_name模板用balance_call_by_name的方式发送消息
function M:byid_balance_call_by_name(...)
	assert(self.instance_name,"not instance_name")
	assert(self.svr_id,"not svr_id")
	local cluster_name, rsp = frpc_client_m:balance_call(
		"call_by_id", self.svr_name, self.svr_id, self.module_name, self.instance_name, FRPC_PACK_ID.balance_call_by_name, nil, spack(...)
	)
	return {
		cluster_name = cluster_name,
		result = {skynet.unpack(rsp)}
	}
end

--用svr_id映射的方式给单个结点的module_name模板用mod_send_by_name的方式发送消息
function M:byid_mod_send_by_name(...)
	assert(self.instance_name,"not instance_name")
	assert(self.svr_id,"not svr_id")
	frpc_client_m:balance_send(
		"send_by_id", self.svr_name, self.svr_id, self.module_name, self.instance_name, FRPC_PACK_ID.mod_send_by_name, self.mod_num or SELF_ADDRESS, spack(...)
	)
end

--用svr_id映射的方式给单个结点的module_name模板用mod_call_by_name的方式发送消息
function M:byid_mod_call_by_name(...)
	assert(self.instance_name,"not instance_name")
	assert(self.svr_id,"not svr_id")
	local cluster_name, rsp = frpc_client_m:balance_call(
		"call_by_id", self.svr_name, self.svr_id, self.module_name, self.instance_name, FRPC_PACK_ID.mod_call_by_name, self.mod_num or SELF_ADDRESS,spack(...)
	)
	return {
		cluster_name = cluster_name,
		result = {skynet.unpack(rsp)}
	}
end

--用svr_id映射的方式给单个结点的module_name模板用broadcast_by_name的方式发送消息
function M:byid_broadcast_by_name(...)
	assert(self.instance_name,"not instance_name")
	assert(self.svr_id,"not svr_id")
	frpc_client_m:balance_send(
		"send_by_id", self.svr_name, self.svr_id, self.module_name, self.instance_name, FRPC_PACK_ID.broadcast_by_name, nil, spack(...)
	)
end

--用svr_id映射的方式给单个结点的module_name模板用broadcast_call_by_name的方式发送消息
function M:byid_broadcast_call_by_name(...)
	assert(self.instance_name,"not instance_name")
	assert(self.svr_id,"not svr_id")
	local cluster_name, rsp = frpc_client_m:balance_call(
		"call_by_id", self.svr_name, self.svr_id, self.module_name, self.instance_name, FRPC_PACK_ID.broadcast_call_by_name, nil, spack(...)
	)
	return {
		cluster_name = cluster_name,
		result = unpack_broadcast(rsp)
	}
end

--------------------------------------------------------------------------------
--byid_by_name
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
--all_by_name
--------------------------------------------------------------------------------
--给所有结点的module_name模板用balance_send_by_name的方式发送消息
function M:all_balance_send_by_name(...)
	assert(self.instance_name,"not instance_name")
	frpc_client_m:balance_send(
		"send_all", self.svr_name, self.module_name, self.instance_name, FRPC_PACK_ID.balance_send_by_name, nil, spack(...)
	)
end

--给所有结点的module_name模板用balance_call_by_name的方式发送消息
function M:all_balance_call_by_name(...)
	assert(self.instance_name,"not instance_name")
	local cluster_rsp_map = frpc_client_m:balance_call(
		"call_all", self.svr_name, self.module_name, self.instance_name, FRPC_PACK_ID.balance_call_by_name, nil, spack(...)
	)
	local ret_list = {}
	for cluster_name, rsp in pairs(cluster_rsp_map) do
		tinsert(ret_list, {
			cluster_name = cluster_name,
			result = {skynet.unpack(rsp)}
		})
	end
	return ret_list
end

--给所有结点的module_name模板用mod_send_by_name的方式发送消息
function M:all_mod_send_by_name(...)
	assert(self.instance_name,"not instance_name")
	frpc_client_m:balance_send(
		"send_all", self.svr_name, self.module_name, self.instance_name, FRPC_PACK_ID.mod_send_by_name, self.mod_num or SELF_ADDRESS, spack(...)
	)
end

--给所有结点的module_name模板用mod_call_by_name的方式发送消息
function M:all_mod_call_by_name(...)
	assert(self.instance_name,"not instance_name")
	local cluster_rsp_map = frpc_client_m:balance_call(
		"call_all", self.svr_name, self.module_name, self.instance_name, FRPC_PACK_ID.mod_call_by_name, self.mod_num or SELF_ADDRESS, spack(...)
	)
	local ret_list = {}
	for cluster_name, rsp in pairs(cluster_rsp_map) do
		tinsert(ret_list, {
			cluster_name = cluster_name,
			result = {skynet.unpack(rsp)}
		})
	end
	return ret_list
end

--给所有结点的module_name模板用broadcast_by_name的方式发送消息
function M:all_broadcast_by_name(...)
	assert(self.instance_name,"not instance_name")
	frpc_client_m:balance_send(
		"send_all", self.svr_name, self.module_name, self.instance_name, FRPC_PACK_ID.broadcast_by_name, nil, spack(...)
	)
end

--给所有结点的module_name模板用broadcast_call_by_name的方式发送消息
function M:all_broadcast_call_by_name(...)
	assert(self.instance_name,"not instance_name")
	local cluster_rsp_map = frpc_client_m:balance_call(
		"call_all", self.svr_name, self.module_name, self.instance_name, FRPC_PACK_ID.broadcast_call_by_name, nil, spack(...)
	)
	local ret_list = {}
	for cluster_name, rsp in pairs(cluster_rsp_map) do
		tinsert(ret_list, {
			cluster_name = cluster_name,
			result = unpack_broadcast(rsp)
		})
	end
	return ret_list
end
--------------------------------------------------------------------------------
--all_by_name
--------------------------------------------------------------------------------

return M