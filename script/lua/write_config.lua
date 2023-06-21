local assert = assert
local ARGV = {...}
local skynet_fly_path = ARGV[1]
local svr_name = ARGV[2]
local thread = ARGV[3] or 4
assert(skynet_fly_path,'缺少 skynet_fly_path')
assert(svr_name,'缺少 svr_name')

package.cpath = skynet_fly_path .. "/luaclib/?.so;"
package.path = './?.lua;' .. skynet_fly_path .."/lualib/?.lua;"

local lfs = require "lfs"
local json = require "cjson"
local util = require "util"

local skynet_path = skynet_fly_path .. '/skynet/'
local server_path = "./"

local config = {
	thread = thread,
	start = "main",
	harbor = 0,
	profile = true,
	lualoader	= skynet_path.."lualib/loader.lua",
	bootstrap 	= "snlua bootstrap",        --the service for bootstrap
	logger 		= "server.log",
	logpath		= server_path,
	daemon	= "./skynet.pid",
	svr_id = 1,
	svr_name = svr_name,
	cpath = skynet_fly_path .. "cservice/?.so;" .. skynet_path .. "cservice/?.so;",

	lua_cpath = skynet_fly_path .. "luaclib/?.so;" .. skynet_path .. "luaclib/?.so;",

	--luaservice 约束服务只能放在 server根目录 || server->service || skynet_fly->service || skynet->service
	luaservice = server_path .. "?.lua;" .. 
 			 server_path .. "service/?.lua;" .. 
			  skynet_fly_path .. "service/?.lua;" .. 
			 skynet_path .. "service/?.lua;",

	lua_path = "",
}

--路径优先级  服务 > skynet_fly > skynet

--lua_path server [非service的目录] skynet_fly[lualib 目录下所有文件] skynet[lualib 下所有文件] 自动生成路径

local lua_path = server_path .. '?.lua;'

for file_name,file_path,file_info in util.diripairs(server_path) do
	if file_info.mode == 'directory' and file_name ~= 'service' then
		lua_path = lua_path .. file_path .. '/?.lua;'
	end
end

lua_path = lua_path .. skynet_fly_path .. '/lualib/?.lua;'
for file_name,file_path,file_info in util.diripairs(skynet_fly_path .. '/lualib') do
	if file_info.mode == 'directory' then
		lua_path = lua_path .. file_path .. '/?.lua;'
	end
end

lua_path = lua_path .. skynet_path .. '/lualib/?.lua;'
for file_name,file_path,file_info in util.diripairs(skynet_path .. '/lualib') do
	if file_info.mode == 'directory' then
		lua_path = lua_path .. file_path .. '/?.lua;'
	end
end

config.lua_path = lua_path

local config_path = server_path .. '/' .. svr_name .. '_config.lua'

--mod_config
local old_config = loadfile(config_path)
if not old_config then
	--全写
	config.mod_config = util.readallfile(server_path .. '/load_mods.lua')
	local file = io.open(config_path,'w+')
	assert(file)
	for k,v in util.kvsortipairs(config) do
		if type(v) == 'number' or type(v) == 'boolean' then
			file:write(string.format("%s = %s\n",k,v))
		elseif type(v) == 'string' then
			file:write(string.format("%s = [[%s]]\n",k,v))
		else
			error('can`t use type = ' .. type(v) .. ' key = ' .. k)
		end
	end
	file:close()
else
	--对比load_mods 和 mod_config
	--load_mods 新增字段对应config添加
	--load_mods 删除字段对应config删除
	--load_mods 修改字段值对应config值不变
	local load_mods = require "load_mods"
	assert(load_mods)
	old_config = old_config()
	local old_mod_config = load(_G['mod_config'])()
	assert(old_mod_config)

	local def_t = util.check_def_table(load_mods,old_mod_config,"config")
	print(util.dump(def_t))
end