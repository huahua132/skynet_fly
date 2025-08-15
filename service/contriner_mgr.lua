local skynet = require "skynet.manager"
local skynet_util = require "skynet-fly.utils.skynet_util"
local time_util = require "skynet-fly.utils.time_util"
local log = require "skynet-fly.log"
local json = require "cjson"
local queue = require "skynet.queue"()

local loadfile = loadfile
local assert = assert
local ipairs = ipairs
local pairs = pairs
local os = os
local tinsert = table.insert
local tremove = table.remove
local tpack = table.pack
local tunpack = table.unpack
local tsort = table.sort
local skynet_call = skynet.call
local pcall = pcall

local loadmodsfile = skynet.getenv("loadmodsfile")

local g_name_id_list_map = {}
local g_id_list_map = {}
local g_watch_map = {}
local g_version_map = {}
local g_monitor_new_map = {}
local g_close_load_map = {}

skynet_util.register_info_func("id_list",function()
	return g_id_list_map
end)

skynet_util.register_info_func("name_id_list",function()
	return g_name_id_list_map
end)

skynet_util.register_info_func("version",function()
	return g_version_map
end)

local function parse_call_ret(isok, err, ...)
	if not isok then
		return tpack(false, err)
	else
		return tpack(err, ...)
	end
end

local function call_id_list(id_list, cmd, ...)
	local ret_map = {}
	for _,id in ipairs(id_list) do
		ret_map[skynet.address(id)] = parse_call_ret(pcall(skynet_call, id, 'lua', cmd, ...))
	end
	return ret_map
end

local function call_module(module_name, cmd, ...)
	local id_list = g_id_list_map[module_name]
	if not id_list or #id_list <= 0 then
		return
	end

	return call_id_list(id_list, cmd, ...)
end

local function launch_new_module(module_name, config)
	local launch_num = config.launch_num
	local is_record_on = config.is_record_on		--是否写录像
	local auto_reload = config.auto_reload		 	--自动热更机制
	local record_backup = config.record_backup      --录像文件整理
	local mod_args = config.mod_args or {}
	local default_arg = config.default_arg or {}

	local is_ok = true
	local id_list = {}
	local name_id_list = {}
	if not g_version_map[module_name] then
		g_version_map[module_name] = 0
	end

	if not g_watch_map[module_name] then
		g_watch_map[module_name] = {}
	end
	
	g_version_map[module_name] = g_version_map[module_name] + 1
	local version = g_version_map[module_name]
	local cur_time = time_util.time()
	local cur_date = os.date("%Y-%m-%d[%H:%M:%S]",cur_time)
	for i = 1,launch_num do
		local isok, server_id = pcall(skynet.newservice, 'hot_container', module_name, i, cur_date, cur_time, version, is_record_on)
		if not isok then
			is_ok = false
			log.fatal("launch_new_module load err ", module_name)
			break
		end
		local args = mod_args[i] or default_arg
		local isok,ret = pcall(skynet_call, server_id, 'lua', 'start', args, auto_reload, record_backup)
		if not isok or not ret then
			log.fatal("launch_new_module start err ",module_name, args)
			is_ok = false
			break
		end
		local instance_name = args.instance_name
		if instance_name then
			if not name_id_list[instance_name] then
				name_id_list[instance_name] = {}
			end
			tinsert(name_id_list[instance_name],server_id)
		end
		tinsert(id_list,server_id)
	end

	return is_ok,id_list,name_id_list
end

local function kill_modules(...)
	local module_name_list = {...}
	for _,module_name in ipairs(module_name_list) do
		call_module(module_name,"herald_exit")
		call_module(module_name,"close")
		
		g_name_id_list_map[module_name] = nil
		g_id_list_map[module_name] = nil
		g_watch_map[module_name] = nil
		g_version_map[module_name] = nil
	end
	return module_name_list
end

local function load_modules(...)
	local module_name_list = {...}
	for i = #module_name_list, 1, -1 do
		local mod_name = module_name_list[i]
		if g_close_load_map[mod_name] then
			tremove(module_name_list, i)
			log.warn("loading close load module_name = ", mod_name)
		end
	end

	if #module_name_list <= 0 then return end
	local load_mods = loadfile(loadmodsfile)()
	assert(load_mods,"not load_mods")

	--检查是否配置都有
	for _,module_name in ipairs(module_name_list) do
		local m_cfg = load_mods[module_name]
		assert(m_cfg,"not m_cfg " .. module_name)
	end

	--按顺序启动
	tsort(module_name_list,function(a,b)
		return load_mods[a].launch_seq < load_mods[b].launch_seq
	end)

	--通知旧服务即将要退出了
	for _,module_name in ipairs(module_name_list) do
		call_module(module_name,"herald_exit")
	end

	--启动新服务
	local is_allok = true   --是否所有都启动成功了
	--检查是否配置都有
	for _,module_name in ipairs(module_name_list) do
		local m_cfg = load_mods[module_name]
		assert(m_cfg,"not m_cfg")
	end
	local tmp_module_map = {}
	for _,module_name in ipairs(module_name_list) do
		local m_cfg = load_mods[module_name]
		local isok,id_list,name_id_list = launch_new_module(module_name,m_cfg)
		tmp_module_map[module_name] = {
			id_list = id_list,
			name_id_list = name_id_list,
		}
		if not isok then
			is_allok = false
		end
	end

	if not is_allok then
		--没有都启动成功
		--通知旧服务取消退出了
		for _,module_name in ipairs(module_name_list) do
			call_module(module_name,"cancel_exit")
		end

		--通知新服务退出
		for _,m in pairs(tmp_module_map) do
			call_id_list(m.id_list,'close')
		end

		return "notok"
	else
		--都启动成功
		--切换模板服务id绑定，通知其他服务更新id
		local old_id_list_map = {}
		local is_have_new = false
		for _,module_name in ipairs(module_name_list) do
			if g_id_list_map[module_name] then
				old_id_list_map[module_name] = g_id_list_map[module_name]
			else
				is_have_new = true
			end
		end

		for module_name,m in pairs(tmp_module_map) do
			local id_list = m.id_list
			local name_id_list = m.name_id_list
			g_name_id_list_map[module_name] = name_id_list
			g_id_list_map[module_name] = id_list
			local version = g_version_map[module_name]
			local watch_map = g_watch_map[module_name]
			for source,response in pairs(watch_map) do
				response(true,id_list,name_id_list,version)
				watch_map[source] = nil
			end
		end

		--通知有新模块上线
		if is_have_new then
			for source,response in pairs(g_monitor_new_map) do
				response(true,g_version_map)
				g_monitor_new_map[source] = nil
			end
		end

		--通知旧模块退出
		for module_name,id_list in pairs(old_id_list_map) do
			call_id_list(id_list,"close")
		end
		return "ok"
	end
end

local function query(source,module_name)
	assert(module_name,'not module_name:' .. module_name)
	assert(g_id_list_map[module_name],"not exists " .. module_name)
	assert(g_name_id_list_map[module_name],"not exists " .. module_name)
	assert(g_version_map[module_name],"not exists " .. module_name)

	local id_list = g_id_list_map[module_name]
	local name_id_list = g_name_id_list_map[module_name]
	local version = g_version_map[module_name]

	return id_list,name_id_list,version
end

local function watch(source,module_name,oldversion)
	assert(module_name,'not module_name')
	assert(oldversion,"not version")
	assert(g_id_list_map[module_name],"not exists " .. module_name)
	assert(g_version_map[module_name],"not exists " .. module_name)

	local id_list = g_id_list_map[module_name]
	local name_id_list = g_name_id_list_map[module_name]
	local newversion = g_version_map[module_name]
	local watch_map = g_watch_map[module_name]

	assert(not watch_map[source])
	if oldversion ~= newversion then
		return id_list,name_id_list,newversion
	end

	watch_map[source] = skynet.response()
	return skynet_util.NOT_RET
end

local function unwatch(source,module_name)
	assert(module_name,'not module_name')
	assert(g_id_list_map[module_name],"not exists " .. module_name)
	assert(g_version_map[module_name],"not exists " .. module_name)

	local id_list = g_id_list_map[module_name]
	local name_id_list = g_name_id_list_map[module_name]
	local version = g_version_map[module_name]
	local watch_map = g_watch_map[module_name]
	local response = watch_map[source]
	if response then
		response(true,id_list,name_id_list,version)
	end
	watch_map[source] = nil
	return true
end

local function monitor_new(source,mod_version_map)
	assert(not g_monitor_new_map[source])
	if not mod_version_map then
		return g_version_map
	end
	
	if mod_version_map then
		for mod_name,_ in pairs(g_version_map) do
			if not mod_version_map[mod_name] then
				return g_version_map
			end
		end
	end

	g_monitor_new_map[source] = skynet.response()
	return skynet_util.NOT_RET
end

local function unmonitor_new(source)
	local response = g_monitor_new_map[source]
	if response then
		response(true, g_version_map)
	end
	g_monitor_new_map[source] = nil
	return true
end

local function close_loads(module_names)
	for _,module_name in ipairs(module_names) do
		g_close_load_map[module_name] = true
	end
end

local function hotfix(module_map)
	local ret_map = {}
	for module_name in pairs(g_name_id_list_map) do
		local hotfix_mods = module_map[module_name]
		if hotfix_mods then
			ret_map[module_name] = call_module(module_name, 'hotfix', hotfix_mods) or "not exists"
		else
			ret_map[module_name] = call_module(module_name, 'hotfix', "") or "not exists"
		end
	end
	
	local ret = json.encode(ret_map)
	return ret
end

local CMD = {}

--通知模块退出
function CMD.kill_modules(source,...)
	log.info("kill_modules:", ...)
	return queue(kill_modules,...)
end

--通知所有模块退出
function CMD.kill_all(source)
	local module_name_list = {}
	for module_name,_ in pairs(g_id_list_map) do
		tinsert(module_name_list,module_name)
	end
	return queue(kill_modules,tunpack(module_name_list))
end

--启动模块
function CMD.load_modules(source,...)
	return queue(load_modules,...)
end

--查询
function CMD.query(source,module_name)
	return queue(query,source,module_name)
end

--监听
function CMD.watch(source,module_name,version)
    return queue(watch,source,module_name,version)
end

--取消监听
function CMD.unwatch(source,module_name)
	queue(unwatch,source,module_name)
end

--监听new模块启动
function CMD.monitor_new(source,mod_version_map)
	return queue(monitor_new,source,mod_version_map)
end

--取消监听new模块启动
function CMD.unmonitor_new(source)
	queue(unmonitor_new,source)
end

--关闭指定模块加载
function CMD.close_loads(source, ...)
	local module_names = {...}
	queue(close_loads, module_names)
end

--热更
function CMD.hotfix(source, ...)
	local module_names = {...}
	local module_map = {}
	for i = 1, #module_names, 2 do
		local module_name = module_names[i]
		if module_name ~= "update_config" then
			local hotfix_mods = module_names[i + 1] or ""
			module_map[module_name] = hotfix_mods
		end
	end
	return queue(hotfix, module_map)
end

--安全关服
function CMD.shutdown()
	local load_mods = loadfile(loadmodsfile)()
	local module_list = {}
	for mod_name, cfg in pairs(load_mods) do
		tinsert(module_list, {mod_name = mod_name, launch_seq = cfg.launch_seq})
	end

	tsort(module_list, function(a, b) return a.launch_seq > b.launch_seq end)

	local downed_map = {}
	--后启动的先关闭
	for _, one in ipairs(module_list) do
		local mod_name = one.mod_name
		local id_list = g_id_list_map[mod_name]
		if id_list then
			for _, id in ipairs(id_list) do
				skynet.call(id, "debug", 'shutdown')
				downed_map[skynet.address(id)] = true
			end
		end
	end

	local address_map = skynet.call(".launcher", "lua", "LIST")
	local address_list = {}
	for address, infostr in pairs(address_map) do
		tinsert(address_list, address)
	end

	tsort(address_list, function(a,b ) return a > b end)
	--后启动的先关闭
	for _,address in ipairs(address_list) do
		if not downed_map[address] then
			skynet.call(address, "debug", 'shutdown')
		end
	end

	skynet.call('.logger', 'lua', 'log', '<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<shutdown over>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>')
	return "shutdown ok"
end

skynet.start(function()
	skynet.register('.contriner_mgr')
	skynet_util.lua_dispatch(CMD)
end)