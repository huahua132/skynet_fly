---@diagnostic disable: undefined-field, need-check-nil

---#API
---#content ---
---#content title: 访问对象[远程rpc]
---#content date: 2024-06-29 22:00:00
---#content categories: ["skynet_fly API 文档","可热更服务模块"]
---#content category_bar: true
---#content tags: [skynet_fly_api]
---#content ---
---#content [frpc_client](https://github.com/huahua132/skynet_fly/blob/master/lualib/skynet-fly/client/frpc_client.lua)

local skynet = require "skynet"
local container_client = require "skynet-fly.client.container_client"
local FRPC_PACK_ID = require "skynet-fly.enum.FRPC_PACK_ID"
local watch_syn = require "skynet-fly.watch.watch_syn"
local watch_interface = require "skynet-fly.watch.interface.container_watch_interface"
local frpcpack = require "frpcpack.core"
local log = require "skynet-fly.log"
local crypt = require "skynet.crypt"
local FRPC_ERRCODE = require "skynet-fly.enum.FRPC_ERRCODE"
local FRPC_MODE = require "skynet-fly.enum.FRPC_MODE"

local setmetatable = setmetatable
local assert = assert
local type = type
local pairs = pairs
local tinsert = table.insert
local spack = skynet.pack
local x_pcall = x_pcall
local debug_getinfo = debug.getinfo
local tostring = tostring

container_client:register("frpc_client_m")

local M = {}
local meta = {__index = M}
local g_frpc_client = nil
local g_watch_client = nil

local g_active_map = {}						--活跃列表
local g_handler_map = {}
local g_all_handler_map = {}
local g_switch_handler_map = {}
local SELF_ADDRESS = skynet.self()

M.ERRCODE = FRPC_ERRCODE
M.FRPC_MODE = FRPC_MODE

local G_MODE_SEND_CMD = {
	[FRPC_MODE.one] = "send_one",
	[FRPC_MODE.byid] = "send_byid",
	[FRPC_MODE.all] = "send_all",
}

local G_MODE_CALL_CMD = {
	[FRPC_MODE.one] = "call_one",
	[FRPC_MODE.byid] = "call_byid",
	[FRPC_MODE.all] = "call_all",
}

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
					local handler_map = g_handler_map[svr_name]
					if handler_map then
						for _, handler in pairs(handler_map) do
							skynet.fork(handler, svr_name, svr_id)
						end
					end

					for _, handler in pairs(g_all_handler_map) do
						skynet.fork(handler, svr_name, svr_id)
					end
				end
			end
		end
		g_active_map = new_active_map
	end
end

---#desc 判断节点是否活跃(连接是否存在)
---@return boolean
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

---#desc 获取指定svr_name活跃的svr_id
---@param svr_name string 结点名称
---@return table
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

---#desc 监听节点上线事件
---@param svr_name string 结点名称
---@param handler function 回调函数
---@param handle_name? string 回调绑定名称 不填默认代码路径
function M:watch_up(svr_name, handler, handle_name)
	assert(type(svr_name) == 'string', "svr_name type err:" .. tostring(svr_name))
	assert(type(handler) == 'function', "handler type err:" .. tostring(handler))
	if not g_handler_map[svr_name] then
		g_handler_map[svr_name] = {}
	end
	handle_name = handle_name or debug_getinfo(2,"S").short_src
	g_handler_map[svr_name][handle_name] = handler
end

---#desc 监听所有节点上线事件
---@param handle_name? string 回调绑定名称 不填默认代码路径
---@param handler function 回调函数
function M:watch_all_up(handle_name, handler)
	assert(type(handler) == 'function', "handler type err:" .. tostring(handler))
	handle_name = handle_name or debug_getinfo(2,"S").short_src
	g_all_handler_map[handle_name] = handler
end

---#desc 监听 frpc_client_m 切换
---@param handle_name string 处理绑定名称
---@param handler function 处理函数
function M:watch_frpc_client_switch(handle_name, handler)
	assert(type(handler) == 'function')
	g_switch_handler_map[handle_name] = handler
end

--#desc 取消监听 frpc_client_m切换
---@param handle_name string 处理绑定名称
function M:unwatch_frpc_client_switch(handle_name)
	g_switch_handler_map[handle_name] = nil
end

---#desc 创建远程rpc调用对象
---@param mode FRPC_MODE 调用模式
---@param svr_name string 结点名称
---@param module_name string 可热更模块名
---@param instance_name? string 实例名称
---@return table obj
function M:new(mode, svr_name, module_name, instance_name)
	assert(svr_name,"not svr_name")
	assert(module_name,"not module_name")
	local t = {
		mode = mode,
		svr_name = svr_name,
		module_name = module_name,
		instance_name = instance_name,
	}

	if not g_frpc_client then
		g_frpc_client = container_client:new("frpc_client_m"):set_switch_call_back(function()
			for handle_name, handler in pairs(g_switch_handler_map) do
				local isok, err = x_pcall(handler)
				if not isok then
					log.error("switch_call_back exec err ", handle_name, err)
				end
			end
		end)
	end

	setmetatable(t,meta)

	return t
end

local function mode_check(self)
	if self.mode == FRPC_MODE.byid then
		assert(self.svr_id, "byid not set svr_id")
	end
end

container_client:add_queryed_cb("frpc_client_m", function()
	g_watch_client = watch_syn.new_client(watch_interface:new("frpc_client_m"))
	skynet.fork(syn_active_map)
end)

---#desc 使用常驻实例
---@param mode FRPC_MODE 调用模式
---@param svr_name string 结点名称
---@param module_name string 可热更模块名
---@param instance_name string 实例名称
---@return table obj
function M:instance(mode, svr_name, module_name, instance_name)
	assert(svr_name,"not svr_name")
	assert(module_name,"not module_name")

	if not g_instance_map[mode] then
		g_instance_map[mode] = {}
	end

	if not g_instance_map[mode][svr_name] then
		g_instance_map[mode][svr_name] = {}
	end

	if not g_instance_map[mode][svr_name][module_name] then
		g_instance_map[mode][svr_name][module_name] = {
			name_map = {},
			obj = nil
		}
	end

	if instance_name then
		if not g_instance_map[mode][svr_name][module_name].name_map[instance_name] then
			g_instance_map[mode][svr_name][module_name].name_map[instance_name] = M:new(mode, svr_name, module_name, instance_name)
		end
		return g_instance_map[mode][svr_name][module_name].name_map[instance_name]
	else
		if not g_instance_map[mode][svr_name][module_name].obj then
			g_instance_map[mode][svr_name][module_name].obj = M:new(mode, svr_name, module_name, instance_name)
		end
		return g_instance_map[mode][svr_name][module_name].obj
	end
end

---#desc 指定mod映射数 设置mod映射访问的数字 如果没有设置，mod消息时默认使用 自身服务id % 服务数量
---@param num number 
---@return table obj
function M:set_mod_num(num)
	assert(type(num) == 'number')
	self.mod_num = num
	return self
end

---#desc 指定访问实例名
---@param name string 实例名 
---@return table obj
function M:set_instance_name(name)
	self.instance_name = name
	return self
end

---#desc 指定服务id
---@param name string 实例名 
---@return table obj
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

local MODE_RESULT_HANDLE = {}

MODE_RESULT_HANDLE[FRPC_MODE.one] = function(cluster_name, rsp, secret, cluster_name2, is_cast)
	if not cluster_name then 
		--nil, errcode, errmsg, cluster_name
		return nil, rsp, secret, cluster_name2
	end
	local upack = is_cast and unpack_broadcast or unpack_rsp
	return {
		cluster_name = cluster_name,
		result = {upack(rsp, secret)}
	}
end

MODE_RESULT_HANDLE[FRPC_MODE.byid] = MODE_RESULT_HANDLE[FRPC_MODE.one]

MODE_RESULT_HANDLE[FRPC_MODE.all] = function(cluster_name, cluster_rsp_map, secret_map, arg3, is_cast)
	if not cluster_name then
		-- nil, errcode, errmsg
		return nil, secret_map, arg3
	end

	local upack = is_cast and unpack_broadcast or unpack_rsp
	local ret_list = {}
	local err_list = {}
	for cluster_name, rsp in pairs(cluster_rsp_map) do
		if type(rsp) == 'string' then
			local secret = secret_map[cluster_name]
			tinsert(ret_list, {
				cluster_name = cluster_name,
				result = {upack(rsp, secret)}
			})
		else
			--rsp[errcode, errmsg, cluster_name]
			tinsert(err_list, rsp)
		end
	end
	return ret_list, err_list
end

local function handle_return_result(mode, cluster_name, cluster_rsp_map, secret_map, cluster_name2, is_cast)
	local handle_func = MODE_RESULT_HANDLE[mode]
	return handle_func(cluster_name, cluster_rsp_map, secret_map, cluster_name2, is_cast)
end

---#desc 给对端节点的module_name模板用balance_send的方式发送消息
---@param ... any[] cmd, arg1, arg2, arg3, ...
function M:balance_send(...)
	local cmd = G_MODE_SEND_CMD[self.mode]
	assert(cmd, "not exists mode = " .. tostring(self.mode))
	mode_check(self)
	g_frpc_client:balance_send(cmd, self.svr_name, self.svr_id, self.module_name, self.instance_name, FRPC_PACK_ID.balance_send, nil, spack(...))
end

---#desc 给对端节点的module_name模板用balance_call的方式发送消息
---@param ... any[] cmd, arg1, arg2, arg3, ...
function M:balance_call(...)
	local mode = self.mode
	local cmd = G_MODE_CALL_CMD[mode]
	assert(cmd, "not exists mode = " .. tostring(mode))
	mode_check(self)
	local cluster_name, rsp, secret, cluster_name2 = g_frpc_client:balance_call(
		cmd, self.svr_name, self.svr_id, self.module_name, self.instance_name, FRPC_PACK_ID.balance_call, nil, spack(...)
	)
	
	return handle_return_result(mode, cluster_name, rsp, secret, cluster_name2)
end

---#desc 给对端结点的module_name模板用mod_send的方式发送消息
---@param ... any[] cmd, arg1, arg2, arg3, ...
function M:mod_send(...)
	local cmd = G_MODE_SEND_CMD[self.mode]
	assert(cmd, "not exists mode = " .. tostring(self.mode))
	mode_check(self)
	g_frpc_client:balance_send(
		cmd, self.svr_name, self.svr_id, self.module_name, self.instance_name, FRPC_PACK_ID.mod_send, self.mod_num or SELF_ADDRESS, spack(...)
	)
end

---#desc 给对端结点的module_name模板用mod_call的方式发送消息
---@param ... any[] cmd, arg1, arg2, arg3, ...
function M:mod_call(...)
	local mode = self.mode
	local cmd = G_MODE_CALL_CMD[mode]
	assert(cmd, "not exists mode = " .. tostring(mode))
	mode_check(self)
	local cluster_name, rsp, secret, cluster_name2 = g_frpc_client:balance_call(
		cmd, self.svr_name, self.svr_id, self.module_name, self.instance_name, FRPC_PACK_ID.mod_call, self.mod_num or SELF_ADDRESS, spack(...)
	)

	return handle_return_result(mode, cluster_name, rsp, secret, cluster_name2)
end

---#desc 给对端结点的module_name模板用broadcast的方式发送消息
---@param ... any[] cmd, arg1, arg2, arg3, ...
function M:broadcast(...)
	local cmd = G_MODE_SEND_CMD[self.mode]
	assert(cmd, "not exists mode = " .. tostring(self.mode))
	mode_check(self)
	g_frpc_client:balance_send(cmd, self.svr_name, self.svr_id, self.module_name, self.instance_name, FRPC_PACK_ID.broadcast, nil, spack(...))
end

---#desc 给对端结点的module_name模板用broadcast_call的方式发送消息
---@param ... any[] cmd, arg1, arg2, arg3, ...
---@return table|nil, errcode, errmsg, cluster_name
function M:broadcast_call(...)
	local mode = self.mode
	local cmd = G_MODE_CALL_CMD[mode]
	assert(cmd, "not exists mode = " .. tostring(mode))
	mode_check(self)
	local cluster_name, rsp, secret, cluster_name2 = g_frpc_client:balance_call(
		cmd, self.svr_name, self.svr_id, self.module_name, self.instance_name, FRPC_PACK_ID.broadcast_call, nil, spack(...)
	)

	return handle_return_result(mode, cluster_name, rsp, secret, cluster_name2, true)
end

---#desc 给对端结点的别名服务send消息(module_name填入别名)
---@param ... any[] cmd, arg1, arg2, arg3, ...
function M:send_by_alias(...)
	local cmd = G_MODE_SEND_CMD[self.mode]
	assert(cmd, "not exists mode = " .. tostring(self.mode))
	mode_check(self)
	g_frpc_client:balance_send(cmd, self.svr_name, self.svr_id, self.module_name, "", FRPC_PACK_ID.send_by_alias, nil, spack(...))
end

---#desc 给对端结点的别名服务call消息(module_name填入别名)
---@param ... any[] cmd, arg1, arg2, arg3, ...
---@return table|nil, errcode, errmsg, cluster_name
function M:call_by_alias(...)
	local mode = self.mode
	local cmd = G_MODE_CALL_CMD[mode]
	assert(cmd, "not exists mode = " .. tostring(mode))
	mode_check(self)
	local cluster_name, rsp, secret, cluster_name2 = g_frpc_client:balance_call(
		cmd, self.svr_name, self.svr_id, self.module_name, "", FRPC_PACK_ID.call_by_alias, nil, spack(...)
	)
	
	return handle_return_result(mode, cluster_name, rsp, secret, cluster_name2)
end

---#desc 给对端结点的module_name模板用balance_send_by_name的方式发送消息
---@param ... any[] cmd, arg1, arg2, arg3, ...
function M:balance_send_by_name(...)
	assert(self.instance_name,"not instance_name")
	local cmd = G_MODE_SEND_CMD[self.mode]
	assert(cmd, "not exists mode = " .. tostring(self.mode))
	mode_check(self)
	g_frpc_client:balance_send(
		cmd, self.svr_name, self.svr_id, self.module_name, self.instance_name, FRPC_PACK_ID.balance_send_by_name, nil, spack(...)
	)
end

---#desc 给单个结点的module_name模板用balance_call_by_name的方式发送消息
---@param ... any[] cmd, arg1, arg2, arg3, ...
---@return table|nil, errcode, errmsg, cluster_name
function M:balance_call_by_name(...)
	assert(self.instance_name,"not instance_name")
	local mode = self.mode
	local cmd = G_MODE_CALL_CMD[mode]
	assert(cmd, "not exists mode = " .. tostring(mode))
	mode_check(self)
	local cluster_name, rsp, secret, cluster_name2 = g_frpc_client:balance_call(
		cmd, self.svr_name, self.svr_id, self.module_name, self.instance_name, FRPC_PACK_ID.balance_call_by_name, nil, spack(...)
	)

	return handle_return_result(mode, cluster_name, rsp, secret, cluster_name2)
end

---#desc 给对端结点的module_name模板用mod_send_by_name的方式发送消息
---@param ... any[] cmd, arg1, arg2, arg3, ...
function M:mod_send_by_name(...)
	assert(self.instance_name,"not instance_name")
	local cmd = G_MODE_SEND_CMD[self.mode]
	assert(cmd, "not exists mode = " .. tostring(self.mode))
	mode_check(self)
	g_frpc_client:balance_send(
		cmd, self.svr_name, self.svr_id, self.module_name, self.instance_name, FRPC_PACK_ID.mod_send_by_name, self.mod_num or SELF_ADDRESS, spack(...)
	)
end

---#desc 给对端结点的module_name模板用mod_call_by_name的方式发送消息
---@param ... any[] cmd, arg1, arg2, arg3, ...
---@return table|nil, errcode, errmsg, cluster_name
function M:mod_call_by_name(...)
	assert(self.instance_name,"not instance_name")
	local mode = self.mode
	local cmd = G_MODE_CALL_CMD[mode]
	assert(cmd, "not exists mode = " .. tostring(mode))
	mode_check(self)
	local cluster_name, rsp, secret, cluster_name2 = g_frpc_client:balance_call(
		cmd, self.svr_name, self.svr_id, self.module_name, self.instance_name, FRPC_PACK_ID.mod_call_by_name, self.mod_num or SELF_ADDRESS,spack(...)
	)

	return handle_return_result(mode, cluster_name, rsp, secret, cluster_name2)
end

---#desc 给对端结点的module_name模板用broadcast_by_name的方式发送消息
---@param ... any[] cmd, arg1, arg2, arg3, ...
function M:broadcast_by_name(...)
	assert(self.instance_name,"not instance_name")
	local cmd = G_MODE_SEND_CMD[self.mode]
	assert(cmd, "not exists mode = " .. tostring(self.mode))
	mode_check(self)
	g_frpc_client:balance_send(
		cmd, self.svr_name, self.svr_id, self.module_name, self.instance_name, FRPC_PACK_ID.broadcast_by_name, nil, spack(...)
	)
end

---#desc 给单个结点的module_name模板用broadcast_call_by_name的方式发送消息
---@param ... any[] cmd, arg1, arg2, arg3, ...
---@return table|nil, errcode, errmsg, cluster_name
function M:broadcast_call_by_name(...)
	assert(self.instance_name,"not instance_name")
	local mode = self.mode
	local cmd = G_MODE_CALL_CMD[mode]
	assert(cmd, "not exists mode = " .. tostring(mode))
	mode_check(self)
	local cluster_name, rsp, secret, cluster_name2 = g_frpc_client:balance_call(
		cmd, self.svr_name, self.svr_id, self.module_name, self.instance_name, FRPC_PACK_ID.broadcast_call_by_name, nil, spack(...)
	)

	return handle_return_result(mode, cluster_name, rsp, secret, cluster_name2, true)
end

--订阅相关命令请不要自己调用，请使用rpc/watch_client|rpc/watch_syn_client

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
	return g_frpc_client:balance_call("subsyn", self.svr_name, self.svr_id, SELF_ADDRESS, channel_name, version)
end

--unsubsyn 取消订阅同步
function M:unsubsyn(channel_name)
	assert(channel_name, "not channel_name")
	return g_frpc_client:balance_send("unsubsyn", self.svr_name, self.svr_id, SELF_ADDRESS, channel_name)
end

--psubsyn 批订阅同步
function M:psubsyn(pchannel_name, version)
	assert(pchannel_name, "not pchannel_name")
	return g_frpc_client:balance_call("psubsyn", self.svr_name, self.svr_id, SELF_ADDRESS, pchannel_name, version)
end

--unpsubsyn 批取消订阅同步
function M:unpsubsyn(pchannel_name)
	assert(pchannel_name, "not pchannel_name")
	return g_frpc_client:balance_send("unpsubsyn", self.svr_name, self.svr_id, SELF_ADDRESS, pchannel_name)
end

return M