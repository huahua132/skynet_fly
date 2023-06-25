local assert = assert
local ARGV = {...}
local skynet_fly_path = ARGV[1]
local svr_name = ARGV[2]
local thread = tonumber(ARGV[3]) or 4
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

local old_config = loadfile(config_path)

if old_config then
	old_config = old_config()
	for k,_ in pairs(config) do
		if k ~= 'lua_path' and _G[k] then
			config[k] = _G[k]
		end
	end
end

local file = io.open(config_path,'w+')
assert(file)
local str = util.table_to_luafile("G",config)
file:write(str)
file:close()