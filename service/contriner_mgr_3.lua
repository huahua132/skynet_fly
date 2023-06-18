local skynet = require "skynet.manager"
local queue = require "skynet.queue"
local assert = assert
local ipairs = ipairs
local table = table

local cmd_queue = queue()
local NORET = {}

local g_module_id_list_map = {}
local g_module_watch_map = {}
local g_module_threshold_map = {}

local CMD = {}

function CMD.load_module(module_name,launch_num)
	assert(module_name,'not module_name')
	assert(launch_num and launch_num > 0,"launch_num err")

	local id_list = {}
	for i = 1,launch_num do
		local server_id = skynet.newservice('hot_container_3',module_name)
		skynet.call(server_id,'lua','start')
		table.insert(id_list,server_id)
	end

	local old_id_list = g_module_id_list_map[module_name] or {}
	for _,id in ipairs(old_id_list) do
		skynet.send(id,'lua','exit')
	end
	g_module_id_list_map[module_name] = id_list

	
	return id_list
end

function CMD.query(module_name)
	assert(module_name,'not module_name')
	return g_module_id_list_map[module_name]
end

local function check_watch(watch_list)
	for i = #watch_list,1,-1 do
		local rsp = watch_list[i]
		if not rsp("TEST") then
			table.remove(watch_list,i)
		end
	end
end

function CMD.watch(module_name)
    assert(module_name,'not module_name')
    if not g_module_watch_map[module_name] then
		g_module_watch_map[module_name] = {}
		g_module_threshold_map[module_name] = 16
	end

	local watch_list = g_module_watch_map[module_name]
	local threshold = g_module_threshold_map[module_name]

	table.insert(watch_list,skynet.response())

	local n = #watch_list
	if n > threshold then
		check_watch(watch_list)
		if #watch_list > threshold then
			g_module_threshold_map[module_name] = g_module_threshold_map[module_name] * 2
		end
	end
	return NORET
end

local function cmd_dispatch(cmd,...)
	local f = CMD[cmd]
	assert(f,'cmd no found :'..cmd)

	local r = f(...)
	if r ~= NORET then
		skynet.ret(skynet.pack(r))
	end
end

skynet.start(function()
	skynet.register('.contriner_mgr_3')
	skynet.dispatch('lua',function(session,source,cmd,...)
		cmd_queue(cmd_dispatch,cmd,...)
	end)
end)