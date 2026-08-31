---#API
---#content ---
---#content title: 监听连接进来的frpc节点上下线
---#content date: 2026-08-31 00:00:00
---#content categories: ["skynet_fly API 文档","订阅发布，订阅同步"]
---#content category_bar: true
---#content tags: [skynet_fly_api]
---#content ---
---#content [frpc_server](https://github.com/huahua132/skynet_fly/blob/master/lualib/skynet-fly/rpc/frpc_server.lua)
---@diagnostic disable: undefined-field, need-check-nil

local skynet = require "skynet"
local log = require "skynet-fly.log"
local watch_syn = require "skynet-fly.watch.watch_syn"
local service_watch_interface = require "skynet-fly.watch.interface.service_watch_interface"

local pairs = pairs
local assert = assert
local type = type
local tinsert = table.insert
local debug_getinfo = debug.getinfo
local tostring = tostring

local M = {}

local g_active_map = {}              --活跃列表 {svr_name={svr_id=true}}
local g_handler_map = {}             --监听指定svr_name节点上线
local g_all_handler_map = {}         --监听所有节点上线
local g_down_handler_map = {}        --监听指定svr_name节点下线
local g_all_down_handler_map = {}    --监听所有节点下线

local g_watch_client = nil
local g_is_start_watch = false

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

		--监听节点下线，旧活跃列表中不存在于新活跃列表的节点视为下线
		for svr_name, map in pairs(g_active_map) do
			local new_map = new_active_map[svr_name]
			for svr_id in pairs(map) do
				if not new_map or not new_map[svr_id] then
					local handler_map = g_down_handler_map[svr_name]
					if handler_map then
						for _, handler in pairs(handler_map) do
							skynet.fork(handler, svr_name, svr_id)
						end
					end

					for _, handler in pairs(g_all_down_handler_map) do
						skynet.fork(handler, svr_name, svr_id)
					end
				end
			end
		end

		g_active_map = new_active_map
	end
end

--惰性建立订阅（hot module 中 skynet.init 已过，改为首次使用时启动）
local function ensure_watch()
	if g_watch_client then return end
	if g_is_start_watch then return end
	g_is_start_watch = true
	skynet.fork(function()
		local frpc_server_addr = skynet.queryservice('frpc_server')
		g_watch_client = watch_syn.new_client(service_watch_interface:new(frpc_server_addr))
		skynet.fork(syn_active_map)
	end)
end

---#desc 判断节点是否活跃(连接是否存在)
---@param svr_name string 结点名称
---@param svr_id? number 结点id
---@return boolean
function M:is_active(svr_name, svr_id)
	ensure_watch()
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
	ensure_watch()
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
	ensure_watch()
end

---#desc 监听所有节点上线事件
---@param handle_name? string 回调绑定名称 不填默认代码路径
---@param handler function 回调函数
function M:watch_all_up(handle_name, handler)
	assert(type(handler) == 'function', "handler type err:" .. tostring(handler))
	handle_name = handle_name or debug_getinfo(2,"S").short_src
	g_all_handler_map[handle_name] = handler
	ensure_watch()
end

---#desc 监听节点下线事件
---@param svr_name string 结点名称
---@param handler function 回调函数
---@param handle_name? string 回调绑定名称 不填默认代码路径
function M:watch_down(svr_name, handler, handle_name)
	assert(type(svr_name) == 'string', "svr_name type err:" .. tostring(svr_name))
	assert(type(handler) == 'function', "handler type err:" .. tostring(handler))
	if not g_down_handler_map[svr_name] then
		g_down_handler_map[svr_name] = {}
	end
	handle_name = handle_name or debug_getinfo(2,"S").short_src
	g_down_handler_map[svr_name][handle_name] = handler
	ensure_watch()
end

---#desc 监听所有节点下线事件
---@param handle_name? string 回调绑定名称 不填默认代码路径
---@param handler function 回调函数
function M:watch_all_down(handle_name, handler)
	assert(type(handler) == 'function', "handler type err:" .. tostring(handler))
	handle_name = handle_name or debug_getinfo(2,"S").short_src
	g_all_down_handler_map[handle_name] = handler
	ensure_watch()
end

return M
