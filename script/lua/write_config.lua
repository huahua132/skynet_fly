local assert = assert
local ARGV = {...}
local skynet_fly_path = ARGV[1]
assert(skynet_fly_path,'缺少 skynet_fly_path')

package.cpath = skynet_fly_path .. "/luaclib/?.so;"
package.path = './?.lua;' .. skynet_fly_path .."/lualib/utils/?.lua;"

local lfs = require "lfs"
local json = require "cjson"
local table_util = require "table_util"
local file_util = require "file_util"

local skynet_path = skynet_fly_path .. '/skynet/'
local server_path = "./"
local common_path = "../../common/"

local svr_name = file_util.get_cur_dir_name()
local config = {
	thread = 4,
	start = "main",
	harbor = 0,
	profile = true,
	lualoader	= skynet_path.."lualib/loader.lua",
	bootstrap 	= "snlua bootstrap",        --the service for bootstrap
	logger 		= "server.log",
	loglevel    = "info",
	logpath		= server_path,
	daemon	= "./skynet.pid",
	svr_id = 1,
	svr_name = svr_name,
	debug_port = 8888,
	skynet_fly_path = skynet_fly_path,
	preload = skynet_fly_path .. '/lualib/preload.lua',
	cpath = skynet_fly_path .. "/cservice/?.so;" .. skynet_path .. "cservice/?.so;",

	lua_cpath = skynet_fly_path .. "/luaclib/?.so;" .. skynet_path .. "luaclib/?.so;",

	--luaservice 约束服务只能放在 server根目录 || server->service || common->service || skynet_fly->service || skynet->service
	luaservice = server_path .. "?.lua;" .. 
 			 server_path .. "service/?.lua;" .. 
			  skynet_fly_path .. "/service/?.lua;" .. 
			  common_path .. "service/?.lua;" ..
			 skynet_path .. "service/?.lua;",

	lua_path = "",
}

config.lua_path = file_util.create_luapath(skynet_fly_path)

local config_path = server_path .. '/' .. svr_name .. '_config.lua'

local old_config = loadfile(config_path)

if old_config then
	old_config = old_config()
	for k,_ in pairs(config) do
		if _G[k] then
			config[k] = _G[k]
		end
	end
end

local file = io.open(config_path,'w+')
assert(file)
local str = table_util.table_to_luafile("G",config)
file:write(str)
file:close()
print("make " .. config_path)