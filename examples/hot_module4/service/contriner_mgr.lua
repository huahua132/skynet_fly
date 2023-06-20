local skynet = require "skynet.manager"

local assert = assert
local ipairs = ipairs
local pairs = pairs
local tinsert = table.insert
local tremove = table.remove
local skynet_send = skynet.send
local skynet_call = skynet.call
local skynet_pack = skynet.pack
local skynet_ret = skynet.ret

local NORET = {}

local g_module_id_list_map = {}
local g_module_watch_map = {}
local g_module_version_map = {}

local CMD = {}

function CMD.load_module(source,module_name,launch_num)
	assert(module_name,'not module_name')
	assert(launch_num and launch_num > 0,"launch_num err")

	local id_list = {}
	for i = 1,launch_num do
		local server_id = skynet.newservice('hot_container',module_name)
		skynet_call(server_id,'lua','start')
		tinsert(id_list,server_id)
	end

	local old_id_list = g_module_id_list_map[module_name] or {}
	for _,id in ipairs(old_id_list) do
		skynet_send(id,'lua','exit')
	end

	g_module_id_list_map[module_name] = id_list

	if not g_module_version_map[module_name] then
		g_module_version_map[module_name] = 0
	end

	if not g_module_watch_map[module_name] then
		g_module_watch_map[module_name] = {}
	end
	
	g_module_version_map[module_name] = g_module_version_map[module_name] + 1
	local version = g_module_version_map[module_name]

	local watch_map = g_module_watch_map[module_name]
	for source,response in pairs(watch_map) do
		response(true,id_list,version)
		watch_map[source] = nil
	end
	
	return id_list,version
end

function CMD.query(source,module_name)
	assert(module_name,'not module_name')
	assert(g_module_id_list_map[module_name])
	assert(g_module_version_map[module_name])

	local id_list = g_module_id_list_map[module_name]
	local version = g_module_version_map[module_name]

	return id_list,version
end

function CMD.watch(source,module_name,version)
    assert(module_name,'not module_name')
	assert(version,"not version")
	assert(g_module_id_list_map[module_name])
	assert(g_module_version_map[module_name])

	local id_list = g_module_id_list_map[module_name]
	local version = g_module_version_map[module_name]
	local watch_map = g_module_watch_map[module_name]

	assert(not watch_map[source])
	if version ~= version then
		return id_list,version
	end

	watch_map[source] = skynet.response()
	return NORET
end

function CMD.unwatch(source,module_name)
	assert(module_name,'not module_name')
	assert(g_module_id_list_map[module_name])
	assert(g_module_version_map[module_name])

	local id_list = g_module_id_list_map[module_name]
	local version = g_module_version_map[module_name]
	local watch_map = g_module_watch_map[module_name]
	local response = watch_map[source]
	assert(response)

	skynet.error("unwatch:",module_name,version)
	response(true,id_list,version)
	watch_map[source] = nil
	return true
end

skynet.start(function()
	skynet.register('.contriner_mgr')
	skynet.dispatch('lua',function(session,source,cmd,...)
		skynet.error("dispatch:",source,cmd,...)
		local f = CMD[cmd]
		assert(f,'cmd no found :'..cmd)
		local r1,r2 = f(source,...)
		if r1 ~= NORET then
			skynet_ret(skynet_pack(r1,r2))
		end
	end)
end)