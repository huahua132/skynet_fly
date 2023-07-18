local ARGV = {...}
local skynet_fly_path = ARGV[1]
local svr_name = ARGV[2]
local cmd = ARGV[3]
assert(skynet_fly_path,'缺少 skynet_fly_path')
assert(svr_name,'缺少 svr_name')
assert(cmd,"缺少命令")

package.cpath = skynet_fly_path .. "/luaclib/?.so;"
package.path = './?.lua;' .. skynet_fly_path .."/lualib/utils/?.lua;"

local lfs = require "lfs"
local file_util = require "file_util"
local table_util = require "table_util"
local json = require "cjson"
debug_port = nil
local skynet_cfg_path = string.format("%s_config",svr_name)
require(skynet_cfg_path)

local function get_host()
	assert(debug_port)
	return string.format("http://127.0.0.1:%s",debug_port)
end

local CMD = {}

function CMD.get_list()
	print(get_host() .. '/list')
end

function CMD.find_server_id()
	local module_name = assert(ARGV[4])
	local offset = assert(ARGV[5])
	for i = 5,#ARGV do
		local line = ARGV[i]
		if string.find(line,module_name,nil,true) then
			print(ARGV[i - offset])
			return
		end
	end
	assert(1 == 2)
end

function CMD.reload()
	local module_name = assert(ARGV[4])
	local server_id = assert(ARGV[5])
	
	local mod_config = require "mod_config"
	local mod_cfg = mod_config[module_name]
	assert(mod_cfg,"not mod_cfg")

	local reload_url = string.format('%s/call/%s/"load_module","%s"',get_host(),server_id,module_name)
	print(string.format("'%s'",reload_url))
end

function CMD.check_reload()
	local module_info_dir = "module_info"
	local dir_info = lfs.attributes(module_info_dir)
	assert(dir_info and dir_info.mode == 'directory')
	local mod_config = require "mod_config"

	local module_info_map = {}
	for f_name,f_path,f_info in file_util.diripairs(module_info_dir) do
		local m_name = string.sub(f_name,1,#f_name - 9)
		if mod_config[m_name] and f_info.mode == 'file' and string.find(f_name,'.required',nil,true) then
			local f_tb = loadfile(f_path)()
			module_info_map[m_name] = f_tb
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
			need_reload_module[module_name] = "changefile:" .. table.concat(change_f_name,'|')
		end
  	end

	for module_name,_ in pairs(mod_config) do
		if not module_info_map[module_name] then
		need_reload_module[module_name] = "launch_new_module"
		end
	end

	local old_mod_confg = loadfile("mod_config.lua.old")
	if old_mod_confg then
		old_mod_confg = old_mod_confg()
	end

	if old_mod_confg and next(old_mod_confg) then
		for module_name,module_cfg in pairs(mod_config) do
			local old_module_cfg = old_mod_confg[module_name]
			if old_module_cfg then
			local def_des = table_util.check_def_table(module_cfg,old_module_cfg)
			if next(def_des) then
				need_reload_module[module_name] = table_util.def_tostring(def_des)
			end
			else
			need_reload_module[module_name] = "relaunch module"
			end
		end
	end

	for module_name,change_file in pairs(need_reload_module) do
		print(module_name)
		print(change_file)
	end
end

function CMD.check_kill_mod()
	local mod_config = require "mod_config"
	local old_mod_confg = loadfile("mod_config.lua.old")
	if not old_mod_confg then
		return	
	end
	old_mod_confg = old_mod_confg()

	for mod_name,_ in pairs(old_mod_confg) do
		if not mod_config[mod_name] then
			print(mod_name)
		end
	end
end

function CMD.call()
	local mod_cmd = assert(ARGV[4])
	local server_id = assert(ARGV[#ARGV])

	local mod_cmd_args = ""
	for i = 5,#ARGV - 1 do
		if tonumber(ARGV[i]) then
			mod_cmd_args = mod_cmd_args .. string.format(',%s',ARGV[i])
		else
			mod_cmd_args = mod_cmd_args .. string.format(',"%s"',ARGV[i])
		end
	end

	local cmd_url = string.format('%s/call/%s/"%s"%s',get_host(),server_id,mod_cmd,mod_cmd_args)
 	print(string.format("'%s'",cmd_url))
end

function CMD.create_mod_config_old()
	local mod_config = require "mod_config"
	os.execute("cp mod_config.lua mod_config.lua.old")
end

function CMD.create_logrotate()
	local currentdir = lfs.currentdir()
	local logrotate_file_name = "/etc/logrotate.d/skynet_"..svr_name
	local info = lfs.attributes(logrotate_file_name)
	local logrotate_file = io.open(logrotate_file_name,'w+')
	assert(logrotate_file)
	logrotate_file:write(currentdir .. '/*.log {\n')
	logrotate_file:write('\tdaily\n')
	logrotate_file:write('\trotate 30\n')
	logrotate_file:write('\tmissingok\n')
	logrotate_file:write('\tnotifempty\n')
	logrotate_file:write('\tnocompress\n')
	logrotate_file:write('\tdateext\n')
	logrotate_file:write('\tpostrotate\n')
	logrotate_file:write(string.format('\t\t/usr/bin/pkill -HUP -f skynet.%s_config.lua\n',svr_name))
	logrotate_file:write('\tendscript\n')

	logrotate_file:write('}\n')
	logrotate_file:close()
	os.execute("chmod -R 644 ./")
end

assert(CMD[cmd],'not cmd:' .. cmd)
CMD[cmd]()