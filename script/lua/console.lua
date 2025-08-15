local ARGV = {...}
local skynet_fly_path = ARGV[1]
local svr_name = ARGV[2]
local load_modsfile = ARGV[3]
local cmd = ARGV[4]
assert(skynet_fly_path,'缺少 skynet_fly_path' .. table.concat(ARGV,','))
assert(svr_name,'缺少 svr_name' .. table.concat(ARGV, ','))
assert(load_modsfile, "缺少 启动配置文件 " .. table.concat(ARGV,','))
assert(cmd,"缺少命令 " .. table.concat(ARGV,','))

if package.config:sub(1, 1) == '\\' then
	package.cpath = skynet_fly_path .. "/luaclib/?.dll;"
else
	package.cpath = skynet_fly_path .. "/luaclib/?.so;"
end
package.path = './?.lua;' .. skynet_fly_path .."/lualib/?.lua;"

local ARGV_HEAD = 4

local lfs = require "lfs"
local file_util = require "skynet-fly.utils.file_util"
local table_util = require "skynet-fly.utils.table_util"
local time_util = require "skynet-fly.utils.time_util"
local json = require "cjson"
debug_port = nil
local skynet_cfg_path = string.format("make/%s_config.lua.%s.run",svr_name, load_modsfile)  --读取skynet启动配置
local file = loadfile(skynet_cfg_path)

if file then
	file()
end

local function get_host()
	if not debug_port then
		print("can`t get debug_port", load_modsfile)
		return
	end
	return string.format("http://127.0.0.1:%s",debug_port)
end

local CMD = {}

function CMD.get_list()
	local host = get_host()
	if not host then
		print("can`t get host", load_modsfile)
		return
	end
	print(host .. '/list')
end

function CMD.find_server_id()
	local module_name = assert(ARGV[ARGV_HEAD + 1])
	local offset = assert(ARGV[ARGV_HEAD + 2])
	for i = ARGV_HEAD + 3,#ARGV do
		local line = ARGV[i]
		if string.find(line,module_name,nil,true) then
			print(ARGV[i - offset])
			return
		end
	end
	print("can`t find_server_id ", module_name)
end

function CMD.reload()
	local file = io.open(string.format("./make/%s.tmp_reload_cmd.txt", load_modsfile),'w+')
	assert(file)
	local load_mods = loadfile(load_modsfile)()
	local server_id = assert(ARGV[ARGV_HEAD + 1])
	local mod_name_str = "0"
	for i = ARGV_HEAD + 2,#ARGV, 2 do
		local module_name = ARGV[i]
		mod_name_str = mod_name_str .. '/' .. module_name
		assert(load_mods[module_name], "module_name not exists " .. module_name)
	end
	local reload_url = string.format('%s/call/%s/load_modules/%s',get_host(),server_id,mod_name_str)
	file:write(string.format("'%s'",reload_url))
	file:close()
	print(string.format("'%s'",reload_url))
end

function CMD.handle_reload_result()
	local is_ok = false
	for i = ARGV_HEAD + 1,#ARGV do
		local str = ARGV[i]
		if str == "ok" then
			is_ok = true
			break
		end
	end

	if not is_ok then
		--执行失败
		print("reload faild")
	else
		--执行成功
		print("reload succ")
		os.remove(string.format("./make/%s.tmp_reload_cmd.txt", load_modsfile))
	end
end

function CMD.try_again_reload()
	local is_ok,str = pcall(file_util.readallfile,string.format("./make/%s.tmp_reload_cmd.txt", load_modsfile))
	if is_ok then
		print(str)
	end
end

function CMD.check_reload()
	local module_info_dir = "make/module_info_" .. load_modsfile:sub(1, #load_modsfile - 4)
	local dir_info = lfs.attributes(module_info_dir)
	assert(dir_info and dir_info.mode == 'directory')
	local load_mods = loadfile (load_modsfile)()

	local module_info_map = {}
	for f_name,f_path,f_info in file_util.diripairs(module_info_dir) do
		local m_name = string.sub(f_name,1,#f_name - 9)
		if load_mods[m_name] and f_info.mode == 'file' and string.find(f_name,'.required',nil,true) then
			local func, err = loadfile(f_path)
			if func then
				module_info_map[m_name] = func()
			else
				error("loadfile err:" .. err)
			end
		end
	end

	local need_reload_module = {}

  	for module_name,loaded in pairs(module_info_map) do
    	local change_f_name = {}

		for load_f_name,load_f_info in pairs(loaded) do
			local load_f_dir = load_f_info.dir
			local last_change_time = load_f_info.last_change_time
			local now_f_info = lfs.attributes(load_f_dir)
			if now_f_info then
				local new_change_time = now_f_info.modification
				if new_change_time > last_change_time then
					table.insert(change_f_name,load_f_name)
				end
			end
		end

		if #change_f_name > 0 then
			need_reload_module[module_name] = "changefile:" .. table.concat(change_f_name,':::')
		end
  	end

	for module_name,_ in pairs(load_mods) do
		if not module_info_map[module_name] then
			need_reload_module[module_name] = "launch_new_module"
		end
	end

	local old_mod_confg = loadfile(string.format("make/%s.old", load_modsfile))
	if old_mod_confg then
		old_mod_confg = old_mod_confg()
	end

	if old_mod_confg and next(old_mod_confg) then
		for module_name,module_cfg in pairs(load_mods) do
			local old_module_cfg = old_mod_confg[module_name]
			if old_module_cfg then
				local def_des = table_util.check_def_table(module_cfg,old_module_cfg)
				if next(def_des) then
					need_reload_module[module_name] = table_util.def_tostring(def_des)
				end
			else
				need_reload_module[module_name] = "relaunch_module"
			end
		end
	end


	local args_list = {}
	for module_name,change_file in pairs(need_reload_module) do
		table.insert(args_list, module_name)
		table.insert(args_list, change_file)
	end

	if file_util.is_window() then
		print(table.concat(args_list, ' '))
	else
		for _,v in ipairs(args_list) do
			print(v)
		end
	end
end

function CMD.check_kill_mod()
	local load_mods = loadfile(load_modsfile)()
	local old_mod_confg = loadfile(string.format("make/%s.old", load_modsfile))
	if not old_mod_confg then
		return	
	end
	old_mod_confg = old_mod_confg()

	local args_list = {}
	for mod_name,_ in pairs(old_mod_confg) do
		if not load_mods[mod_name] then
			table.insert(args_list, mod_name)
		end
	end

	if file_util.is_window() then
		print(table.concat(args_list, ' '))
	else
		for _,v in ipairs(args_list) do
			print(v)
		end
	end
end

function CMD.call()
	local mod_cmd = assert(ARGV[ARGV_HEAD + 1])
	local server_id = assert(ARGV[#ARGV])

	local mod_cmd_args = ""
	for i = ARGV_HEAD + 2,#ARGV - 1 do
		mod_cmd_args = mod_cmd_args .. string.format('/%s',ARGV[i])
	end

	local cmd_url = string.format('%s/call/%s/%s%s',get_host(),server_id,mod_cmd,mod_cmd_args)
 	print(string.format("'%s'",cmd_url))
end

function CMD.create_load_mods_old()
	local copy_obj = file_util.new_copy_file(false)
	copy_obj.set_source_target(load_modsfile, string.format("make/%s.old", load_modsfile))
	copy_obj.execute(cmd)
end

--拷贝一个运行时配置供console.lua读取
function CMD.create_running_config()
	local copy_obj = file_util.new_copy_file(false)
	copy_obj.set_source_target(string.format("make/%s_config.lua", svr_name), string.format("make/%s_config.lua.%s.run", svr_name, load_modsfile))
	copy_obj.execute(cmd)
end

--快进时间
function CMD.fasttime()
	local fastdate = ARGV[ARGV_HEAD + 1]
	local one_add = ARGV[ARGV_HEAD + 2]  --单次加速时间 1表示1秒
	assert(fastdate,"not fastdate")
	assert(one_add, "not one_add")
	local date,err = time_util.string_to_date(fastdate, '-', ':')
	if not date then
		error(err)
	end

	local fastcmd = string.format('%s/fasttime/%s/%s',get_host(),os.time(date),one_add)
	print(string.format("'%s'",fastcmd))
end

--检查热更
function CMD.check_hotfix()
	local module_info_dir = "make/hotfix_info_" .. load_modsfile:sub(1, #load_modsfile - 4)
	local dir_info = lfs.attributes(module_info_dir)
	assert(dir_info and dir_info.mode == 'directory')
	local load_mods = loadfile (load_modsfile)()

	local module_info_map = {}
	for f_name,f_path,f_info in file_util.diripairs(module_info_dir) do
		local m_name = string.sub(f_name,1,#f_name - 9)
		if load_mods[m_name] and f_info.mode == 'file' and string.find(f_name,'.required',nil,true) then
			local func, err = loadfile(f_path)
			if func then
				module_info_map[m_name] = func()
			else
				error("loadfile err:" .. err)
			end
		end
	end

	local need_reload_module = {}

  	for module_name,loaded in pairs(module_info_map) do
    	local change_f_name = {}

		for load_f_name,load_f_info in pairs(loaded) do
		local load_f_dir = load_f_info.dir
		local last_change_time = load_f_info.last_change_time
		local now_f_info = lfs.attributes(load_f_dir)
			if now_f_info then
				local new_change_time = now_f_info.modification
				if new_change_time > last_change_time then
					table.insert(change_f_name,load_f_name)
				end
			end
		end

		if #change_f_name > 0 then
			need_reload_module[module_name] = table.concat(change_f_name,':::')
		end
  	end

	local args_list = {}
	for module_name,change_file in pairs(need_reload_module) do
		table.insert(args_list, module_name)
		table.insert(args_list, change_file)
	end
	if #args_list <= 0 then
		table.insert(args_list, "update_config")
		table.insert(args_list, "|||")
	end
	if file_util.is_window() then
		print(table.concat(args_list, ' '))
	else
		for _,v in ipairs(args_list) do
			print(v)
		end
	end
end

--热更
function CMD.hotfix()
	local load_mods = loadfile(load_modsfile)()
	local server_id = assert(ARGV[ARGV_HEAD + 1])
	local mod_name_str = "0"
	for i = ARGV_HEAD + 2,#ARGV, 2 do
		local module_name = ARGV[i]
		local hotmods = ARGV[i + 1]
		mod_name_str = mod_name_str .. '/' .. module_name
		mod_name_str = mod_name_str .. '/' .. hotmods
		assert(load_mods[module_name] or module_name == "update_config")
	end
	local url = string.format('%s/call/%s/hotfix/%s',get_host(),server_id,mod_name_str)
	print(string.format("'%s'",url))
end

--解析热更结果
function CMD.handle_hotfix_result()
	local ret = ARGV[ARGV_HEAD + 2]
	print("ret = ",ret)
end

--更新共享数据
function CMD.upsharedata()
	local server_id = assert(ARGV[ARGV_HEAD + 1])
	local url = string.format('%s/call/%s/check_reload/', get_host(), server_id)
	print(string.format("'%s'", url))
end

--解析更新结果
function CMD.handle_upsharedata_result()
	local ret = ARGV[ARGV_HEAD + 2]
	print("ret = ", ret)
end

--偏移拼接所有参数
function CMD.offset_param()
	local offset = tonumber(assert(ARGV[ARGV_HEAD + 1]))
    local param = {}
	for i = ARGV_HEAD + offset + 2,#ARGV do
		table.insert(param, ARGV[i])
	end
	print(table.concat(param, ' '))
end

assert(CMD[cmd],'not cmd:' .. cmd)
CMD[cmd]()