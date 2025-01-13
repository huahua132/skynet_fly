---@diagnostic disable: undefined-field, need-check-nil

local skynet = require "skynet"
local contriner_client = require "skynet-fly.client.contriner_client"
local FRPC_PACK_ID = require "skynet-fly.enum.FRPC_PACK_ID"
local watch_syn = require "skynet-fly.watch.watch_syn"
local watch_interface = require "skynet-fly.watch.interface.contriner_watch_interface"
local frpcpack = require "frpcpack.core"
local log = require "skynet-fly.log"
local crypt = require "skynet.crypt"

local setmetatable = setmetatable
local assert = assert
local type = type
local pairs = pairs
local tinsert = table.insert
local spack = skynet.pack

contriner_client:register("frpc_client_m")

local M = {}
local meta = {__index = M}
local g_frpc_client = nil
local g_watch_client = nil

local g_active_map = {}						--活跃列表
local g_handler_map = {}
local SELF_ADDRESS = skynet.self()

local g_instance_map = {}

--同步活跃列表数据
local function syn_active_map()
	g_watch_client:watch("active")
	while g_watch_client:is_watch("active") do
		local new_active_map = g_watch_client:await_update("active")
		for svr_name, map in pairs(new_active_map) do
			for svr_id, id in pairs(map) do
				local old_id = nil
				if g_active_map[svr_name] and g_active_map[svr_name][svr_id] then
					old_id = g_active_map[svr_name][svr_id]
				end

				if old_id ~= id then
					local handlers = g_handler_map[svr_name]
					if handlers then
						for i = 1, #handlers do
							local handler = handlers[i]
							skynet.fork(handler, svr_name, svr_id)
						end
					end
				end
			end
		end
		g_active_map = new_active_map
	end
end

--判断是否活跃
function M:is_active(svr_name, svr_id)
	if not g_active_map[svr_name] then
		return false
	end

	if not svr_id then return true end

	if not g_active_map[svr_name][svr_id] then
		return false
	end

	return true
end

--获取指定svr_name活跃的svr_id
function M:get_active_svr_ids(svr_name)
	local list = {}
	local map = g_active_map[svr_name]
	if map then
		for svr_id in pairs(map) do
			tinsert(list, svr_id)
		end
	end

	return list
end

--监听上线
function M:watch_up(svr_name, handler)
	if not g_handler_map[svr_name] then
		g_handler_map[svr_name] = {}
	end
	tinsert(g_handler_map[svr_name], handler)
end

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

	if not g_frpc_client then
		g_frpc_client = contriner_client:new("frpc_client_m")
	end

	setmetatable(t,meta)

	return t
end

contriner_client:add_queryed_cb("frpc_client_m", function()
	g_watch_client = watch_syn.new_client(watch_interface:new("frpc_client_m"))
	skynet.fork(syn_active_map)
end)

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

local function unpack_rsp(rsp, secret)
	if type(rsp) == 'table' then
		local msg, sz = frpcpack.concat(rsp)
		if not msg then
			log.error("concat rsp err ", #rsp)
			return
		end

		rsp = skynet.tostring(msg, sz)
		skynet.trash(msg, sz)
	end

	if secret then
		rsp = crypt.desdecode(secret, rsp)
	end
	return skynet.unpack(rsp)
end

local function unpack_broadcast(rsp, secret)
	local ret_map = unpack_rsp(rsp, secret)
---@diagnostic disable-next-line: param-type-mismatch
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
	g_frpc_client:balance_send(
		"balance_send", self.svr_name, self.module_name, self.instance_name, FRPC_PACK_ID.balance_send, nil, spack(...)
	)
end

--用简单轮询负载均衡给单个结点的module_name模板用balance_call的方式发送消息
function M:one_balance_call(...)
	local cluster_name, rsp, secret = g_frpc_client:balance_call(
		"balance_call", self.svr_name, self.module_name, self.instance_name, FRPC_PACK_ID.balance_call, nil, spack(...)
	)

	if not cluster_name then return end
	
	return {
		cluster_name = cluster_name,
		result = {unpack_rsp(rsp, secret)}
	}
end

--用简单轮询负载均衡给单个结点的module_name模板用mod_send的方式发送消息
function M:one_mod_send(...)
	g_frpc_client:balance_send(
		"balance_send", self.svr_name, self.module_name, self.instance_name, FRPC_PACK_ID.mod_send, self.mod_num or SELF_ADDRESS, spack(...)
	)
end

--用简单轮询负载均衡给单个结点的module_name模板用mod_call的方式发送消息
function M:one_mod_call(...)
	local cluster_name, rsp, secret = g_frpc_client:balance_call(
		"balance_call", self.svr_name, self.module_name, self.instance_name, FRPC_PACK_ID.mod_call, self.mod_num or SELF_ADDRESS, spack(...)
	)

	if not cluster_name then return end

	return {
		cluster_name = cluster_name,
		result = {unpack_rsp(rsp, secret)}
	}
end

--用简单轮询负载均衡给单个结点的module_name模板用broadcast的方式发送消息
function M:one_broadcast(...)
	g_frpc_client:balance_send(
		"balance_send", self.svr_name, self.module_name, self.instance_name, FRPC_PACK_ID.broadcast, nil, spack(...)
	)
end

--用简单轮询负载均衡给单个结点的module_name模板用broadcast_call的方式发送消息
function M:one_broadcast_call(...)
	local cluster_name, rsp, secret = g_frpc_client:balance_call(
		"balance_call", self.svr_name, self.module_name, self.instance_name, FRPC_PACK_ID.broadcast_call, nil, spack(...)
	)

	if not cluster_name then return end

	return {
		cluster_name = cluster_name,
		result = unpack_broadcast(rsp, secret)
	}
end

--用简单轮询负载均衡给单个结点的别名服务send消息
function M:one_send_by_name(...)
	g_frpc_client:balance_send(
		"balance_send", self.svr_name, self.module_name, "", FRPC_PACK_ID.send_by_name, nil, spack(...)
	)
end

--用简单轮询负载均衡给单个结点的别名服务call消息
function M:one_call_by_name(...)
	local cluster_name, rsp, secret = g_frpc_client:balance_call(
		"balance_call", self.svr_name, self.module_name, "", FRPC_PACK_ID.call_by_name, nil, spack(...)
	)

	if not cluster_name then return end
	
	return {
		cluster_name = cluster_name,
		result = {unpack_rsp(rsp, secret)}
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
	g_frpc_client:balance_send(
		"send_by_id", self.svr_name, self.svr_id, self.module_name, self.instance_name, FRPC_PACK_ID.balance_send, nil, spack(...)
	)
end

--用svr_id映射的方式给单个结点的module_name模板用balance_call的方式发送消息
function M:byid_balance_call(...)
	assert(self.svr_id, "not svr_id")
	local cluster_name, rsp, secret = g_frpc_client:balance_call(
		"call_by_id", self.svr_name, self.svr_id, self.module_name, self.instance_name, FRPC_PACK_ID.balance_call, nil, spack(...)
	)

	if not cluster_name then return end

	return {
		cluster_name = cluster_name,
		result = {unpack_rsp(rsp, secret)}
	}
end

--用svr_id映射的方式给单个结点的module_name模板用mod_send的方式发送消息
function M:byid_mod_send(...)
	assert(self.svr_id, "not svr_id")
	g_frpc_client:balance_send(
		"send_by_id", self.svr_name, self.svr_id, self.module_name, self.instance_name, FRPC_PACK_ID.mod_send, self.mod_num or SELF_ADDRESS, spack(...)
	)
end

--用svr_id映射的方式给单个结点的module_name模板用mod_call的方式发送消息
function M:byid_mod_call(...)
	assert(self.svr_id, "not svr_id")
	local cluster_name, rsp, secret = g_frpc_client:balance_call(
		"call_by_id", self.svr_name, self.svr_id, self.module_name, self.instance_name, FRPC_PACK_ID.mod_call,self.mod_num or SELF_ADDRESS, spack(...)
	)

	if not cluster_name then return end

	return {
		cluster_name = cluster_name,
		result = {unpack_rsp(rsp, secret)}
	}
end

--用svr_id映射的方式给单个结点的module_name模板用broadcast的方式发送消息
function M:byid_broadcast(...)
	assert(self.svr_id, "not svr_id")
	g_frpc_client:balance_send(
		"send_by_id", self.svr_name, self.svr_id, self.module_name, self.instance_name, FRPC_PACK_ID.broadcast, nil, spack(...)
	)
end

--用svr_id映射的方式给单个结点的module_name模板用broadcast_call的方式发送消息
function M:byid_broadcast_call(...)
	assert(self.svr_id, "not svr_id")
	local cluster_name, rsp, secret = g_frpc_client:balance_call(
		"call_by_id", self.svr_name, self.svr_id, self.module_name, self.instance_name, FRPC_PACK_ID.broadcast_call, nil, spack(...)
	)
	if not cluster_name then return end

	return {
		cluster_name = cluster_name,
		result = unpack_broadcast(rsp, secret),
	}
end

--用svr_id映射的方式给单个结点的指定别名服务用balance_send的方式发送消息
function M:byid_send_by_name(...)
	assert(self.svr_id, "not svr_id")
	g_frpc_client:balance_send(
		"send_by_id", self.svr_name, self.svr_id, self.module_name, "", FRPC_PACK_ID.send_by_name, nil, spack(...)
	)
end

--用svr_id映射的方式给单个结点的指定别名服务用balance_call的方式发送消息
function M:byid_call_by_name(...)
	assert(self.svr_id, "not svr_id")
	local cluster_name, rsp, secret = g_frpc_client:balance_call(
		"call_by_id", self.svr_name, self.svr_id, self.module_name, "", FRPC_PACK_ID.call_by_name, nil, spack(...)
	)

	if not cluster_name then return end

	return {
		cluster_name = cluster_name,
		result = {unpack_rsp(rsp, secret)}
	}
end
--------------------------------------------------------------------------------
--all
--------------------------------------------------------------------------------

--给所有结点的module_name模板用balance_send的方式发送消息
function M:all_balance_send(...)
	g_frpc_client:balance_send(
		"send_all", self.svr_name, self.module_name, self.instance_name, FRPC_PACK_ID.balance_send, nil, spack(...)
	)
end

--给所有结点的module_name模板用balance_call的方式发送消息
function M:all_balance_call(...)
	local cluster_rsp_map, secret_map = g_frpc_client:balance_call(
		"call_all", self.svr_name, self.module_name, self.instance_name, FRPC_PACK_ID.balance_call, nil, spack(...)
	)

	if not cluster_rsp_map then return end

	local ret_list = {}
	for cluster_name, rsp in pairs(cluster_rsp_map) do
		local secret = secret_map[cluster_name]
		tinsert(ret_list, {
			cluster_name = cluster_name,
			result = {unpack_rsp(rsp, secret)}
		})
	end
	return ret_list
end

--给所有结点的module_name模板用mod_send的方式发送消息
function M:all_mod_send(...)
	g_frpc_client:balance_send(
		"send_all", self.svr_name, self.module_name, self.instance_name, FRPC_PACK_ID.mod_send, self.mod_num or SELF_ADDRESS, spack(...)
	)
end

--给所有结点的module_name模板用mod_call的方式发送消息
function M:all_mod_call(...)
	local cluster_rsp_map, secret_map = g_frpc_client:balance_call(
		"call_all", self.svr_name, self.module_name, self.instance_name, FRPC_PACK_ID.mod_call, self.mod_num or SELF_ADDRESS, spack(...)
	)

	if not cluster_rsp_map then return end

	local ret_list = {}
	for cluster_name, rsp in pairs(cluster_rsp_map) do
		local secret = secret_map[cluster_name]
		tinsert(ret_list, {
			cluster_name = cluster_name,
			result = {unpack_rsp(rsp, secret)}
		})
	end
	return ret_list
end

--给所有结点的module_name模板用broadcast的方式发送消息
function M:all_broadcast(...)
	g_frpc_client:balance_send(
		"send_all", self.svr_name, self.module_name, self.instance_name, FRPC_PACK_ID.broadcast, nil, spack(...)
	)
end

--给所有结点的module_name模板用broadcast_call的方式发送消息
function M:all_broadcast_call(...)
	local cluster_rsp_map, secret_map = g_frpc_client:balance_call(
		"call_all", self.svr_name, self.module_name, self.instance_name, FRPC_PACK_ID.broadcast_call, nil, spack(...)
	)

	if not cluster_rsp_map then return end

	local ret_list = {}
	for cluster_name, rsp in pairs(cluster_rsp_map) do
		local secret = secret_map[cluster_name]
		tinsert(ret_list, {
			cluster_name = cluster_name,
			result = unpack_broadcast(rsp, secret)
		})
	end
	return ret_list
end

--给所有结点的指定别名服务用balance_send的方式发送消息
function M:all_send_by_name(...)
	g_frpc_client:balance_send(
		"send_all", self.svr_name, self.module_name, "", FRPC_PACK_ID.send_by_name, nil, spack(...)
	)
end

--给所有结点的指定别名服务用balance_call的方式发送消息
function M:all_call_by_name(...)
	local cluster_rsp_map, secret_map = g_frpc_client:balance_call(
		"call_all", self.svr_name, self.module_name, "", FRPC_PACK_ID.call_by_name, nil, spack(...)
	)

	if not cluster_rsp_map then return end

	local ret_list = {}
	for cluster_name, rsp in pairs(cluster_rsp_map) do
		local secret = secret_map[cluster_name]
		tinsert(ret_list, {
			cluster_name = cluster_name,
			result = {unpack_rsp(rsp, secret)}
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
	g_frpc_client:balance_send(
		"balance_send", self.svr_name, self.module_name, self.instance_name, FRPC_PACK_ID.balance_send_by_name, nil, spack(...)
	)
end

--用简单轮询负载均衡给单个结点的module_name模板用balance_call_by_name的方式发送消息
function M:one_balance_call_by_name(...)
	assert(self.instance_name,"not instance_name")
	local cluster_name, rsp, secret = g_frpc_client:balance_call(
		"balance_call", self.svr_name, self.module_name, self.instance_name, FRPC_PACK_ID.balance_call_by_name, nil, spack(...)
	)

	if not cluster_name then return end

	return {
		cluster_name = cluster_name,
		result = {unpack_rsp(rsp, secret)}
	}
end

--用简单轮询负载均衡给单个结点的module_name模板用mod_send_by_name的方式发送消息
function M:one_mod_send_by_name(...)
	assert(self.instance_name,"not instance_name")
	g_frpc_client:balance_send(
		"balance_send",self.svr_name, self.module_name, self.instance_name, FRPC_PACK_ID.mod_send_by_name, self.mod_num or SELF_ADDRESS, spack(...)
	)
end

--用简单轮询负载均衡给单个结点的module_name模板用mod_call_by_name的方式发送消息
function M:one_mod_call_by_name(...)
	assert(self.instance_name,"not instance_name")
	local cluster_name, rsp, secret = g_frpc_client:balance_call(
		"balance_call", self.svr_name, self.module_name, self.instance_name, FRPC_PACK_ID.mod_call_by_name, self.mod_num or SELF_ADDRESS,spack(...)
	)

	if not cluster_name then return end

	return {
		cluster_name = cluster_name,
		result = {unpack_rsp(rsp, secret)}
	}
end

--用简单轮询负载均衡给单个结点的module_name模板用broadcast_by_name的方式发送消息
function M:one_broadcast_by_name(...)
	assert(self.instance_name,"not instance_name")
	g_frpc_client:balance_send(
		"balance_send", self.svr_name, self.module_name, self.instance_name, FRPC_PACK_ID.broadcast_by_name, nil, spack(...)
	)
end


--用简单轮询负载均衡给单个结点的module_name模板用broadcast_call_by_name的方式发送消息
function M:one_broadcast_call_by_name(...)
	assert(self.instance_name,"not instance_name")
	local cluster_name, rsp, secret = g_frpc_client:balance_call(
		"balance_call", self.svr_name, self.module_name, self.instance_name, FRPC_PACK_ID.broadcast_call_by_name, nil, spack(...)
	)

	if not cluster_name then return end

	return {
		cluster_name = cluster_name,
		result = unpack_broadcast(rsp, secret)
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
	g_frpc_client:balance_send(
		"send_by_id",self.svr_name, self.svr_id, self.module_name, self.instance_name, FRPC_PACK_ID.balance_send_by_name, nil, spack(...)
	)
end

--用svr_id映射的方式给单个结点的module_name模板用balance_call_by_name的方式发送消息
function M:byid_balance_call_by_name(...)
	assert(self.instance_name,"not instance_name")
	assert(self.svr_id,"not svr_id")
	local cluster_name, rsp, secret = g_frpc_client:balance_call(
		"call_by_id", self.svr_name, self.svr_id, self.module_name, self.instance_name, FRPC_PACK_ID.balance_call_by_name, nil, spack(...)
	)

	if not cluster_name then return end

	return {
		cluster_name = cluster_name,
		result = {unpack_rsp(rsp, secret)}
	}
end

--用svr_id映射的方式给单个结点的module_name模板用mod_send_by_name的方式发送消息
function M:byid_mod_send_by_name(...)
	assert(self.instance_name,"not instance_name")
	assert(self.svr_id,"not svr_id")
	g_frpc_client:balance_send(
		"send_by_id", self.svr_name, self.svr_id, self.module_name, self.instance_name, FRPC_PACK_ID.mod_send_by_name, self.mod_num or SELF_ADDRESS, spack(...)
	)
end

--用svr_id映射的方式给单个结点的module_name模板用mod_call_by_name的方式发送消息
function M:byid_mod_call_by_name(...)
	assert(self.instance_name,"not instance_name")
	assert(self.svr_id,"not svr_id")
	local cluster_name, rsp, secret = g_frpc_client:balance_call(
		"call_by_id", self.svr_name, self.svr_id, self.module_name, self.instance_name, FRPC_PACK_ID.mod_call_by_name, self.mod_num or SELF_ADDRESS,spack(...)
	)

	if not cluster_name then return end

	return {
		cluster_name = cluster_name,
		result = {unpack_rsp(rsp, secret)}
	}
end

--用svr_id映射的方式给单个结点的module_name模板用broadcast_by_name的方式发送消息
function M:byid_broadcast_by_name(...)
	assert(self.instance_name,"not instance_name")
	assert(self.svr_id,"not svr_id")
	g_frpc_client:balance_send(
		"send_by_id", self.svr_name, self.svr_id, self.module_name, self.instance_name, FRPC_PACK_ID.broadcast_by_name, nil, spack(...)
	)
end

--用svr_id映射的方式给单个结点的module_name模板用broadcast_call_by_name的方式发送消息
function M:byid_broadcast_call_by_name(...)
	assert(self.instance_name,"not instance_name")
	assert(self.svr_id,"not svr_id")
	local cluster_name, rsp, secret = g_frpc_client:balance_call(
		"call_by_id", self.svr_name, self.svr_id, self.module_name, self.instance_name, FRPC_PACK_ID.broadcast_call_by_name, nil, spack(...)
	)

	if not cluster_name then return end

	return {
		cluster_name = cluster_name,
		result = unpack_broadcast(rsp, secret)
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
	g_frpc_client:balance_send(
		"send_all", self.svr_name, self.module_name, self.instance_name, FRPC_PACK_ID.balance_send_by_name, nil, spack(...)
	)
end

--给所有结点的module_name模板用balance_call_by_name的方式发送消息
function M:all_balance_call_by_name(...)
	assert(self.instance_name,"not instance_name")
	local cluster_rsp_map, secret_map = g_frpc_client:balance_call(
		"call_all", self.svr_name, self.module_name, self.instance_name, FRPC_PACK_ID.balance_call_by_name, nil, spack(...)
	)

	if not cluster_rsp_map then return end

	local ret_list = {}
	for cluster_name, rsp in pairs(cluster_rsp_map) do
		local secret = secret_map[cluster_name]
		tinsert(ret_list, {
			cluster_name = cluster_name,
			result = {unpack_rsp(rsp, secret)}
		})
	end
	return ret_list
end

--给所有结点的module_name模板用mod_send_by_name的方式发送消息
function M:all_mod_send_by_name(...)
	assert(self.instance_name,"not instance_name")
	g_frpc_client:balance_send(
		"send_all", self.svr_name, self.module_name, self.instance_name, FRPC_PACK_ID.mod_send_by_name, self.mod_num or SELF_ADDRESS, spack(...)
	)
end

--给所有结点的module_name模板用mod_call_by_name的方式发送消息
function M:all_mod_call_by_name(...)
	assert(self.instance_name,"not instance_name")
	local cluster_rsp_map, secret_map = g_frpc_client:balance_call(
		"call_all", self.svr_name, self.module_name, self.instance_name, FRPC_PACK_ID.mod_call_by_name, self.mod_num or SELF_ADDRESS, spack(...)
	)

	if not cluster_rsp_map then return end

	local ret_list = {}
	for cluster_name, rsp in pairs(cluster_rsp_map) do
		local secret = secret_map[cluster_name]
		tinsert(ret_list, {
			cluster_name = cluster_name,
			result = {unpack_rsp(rsp, secret)}
		})
	end
	return ret_list
end

--给所有结点的module_name模板用broadcast_by_name的方式发送消息
function M:all_broadcast_by_name(...)
	assert(self.instance_name,"not instance_name")
	g_frpc_client:balance_send(
		"send_all", self.svr_name, self.module_name, self.instance_name, FRPC_PACK_ID.broadcast_by_name, nil, spack(...)
	)
end

--给所有结点的module_name模板用broadcast_call_by_name的方式发送消息
function M:all_broadcast_call_by_name(...)
	assert(self.instance_name,"not instance_name")
	local cluster_rsp_map, secret_map = g_frpc_client:balance_call(
		"call_all", self.svr_name, self.module_name, self.instance_name, FRPC_PACK_ID.broadcast_call_by_name, nil, spack(...)
	)
	
	if not cluster_rsp_map then return end

	local ret_list = {}
	for cluster_name, rsp in pairs(cluster_rsp_map) do
		local secret = secret_map[cluster_name]
		tinsert(ret_list, {
			cluster_name = cluster_name,
			result = unpack_broadcast(rsp, secret)
		})
	end
	return ret_list
end
--------------------------------------------------------------------------------
--all_by_name
--------------------------------------------------------------------------------

--sub 订阅
function M:sub(channel_name, unique_name)
	assert(channel_name, "not channel_name")
	assert(unique_name, "not unique_name")
	return g_frpc_client:balance_call("sub", self.svr_name, self.svr_id, SELF_ADDRESS, channel_name, unique_name)
end

--取消 订阅
function M:unsub(channel_name, unique_name)
	assert(channel_name, "not channel_name")
	assert(unique_name, "not unique_name")
	return g_frpc_client:balance_call("unsub", self.svr_name, self.svr_id, SELF_ADDRESS, channel_name, unique_name)
end

--subsyn 订阅同步
function M:subsyn(channel_name, version)
	assert(channel_name, "not channel_name")
	assert(version, "not version")
	return g_frpc_client:balance_call("subsyn", self.svr_name, self.svr_id, SELF_ADDRESS, channel_name, version)
end

--unsubsyn 取消订阅同步
function M:unsubsyn(channel_name)
	assert(channel_name, "not channel_name")
	return g_frpc_client:balance_call("unsubsyn", self.svr_name, self.svr_id, SELF_ADDRESS, channel_name)
end

return M