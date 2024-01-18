local assert = assert
local ARGV = { ... }
local skynet_fly_path = ARGV[1]
local load_mods_name = ARGV[2]
local is_daemon = ARGV[3]
assert(skynet_fly_path, '缺少 skynet_fly_path')

package.cpath = skynet_fly_path .. "/luaclib/?.so;"
package.path = './?.lua;' .. skynet_fly_path .. "/lualib/utils/?.lua;"

local lfs = require "lfs"
local json = require "cjson"
local table_util = require "table_util"
local file_util = require "file_util"

if load_mods_name then
	if string.find(load_mods_name, '.lua', nil, true) then
		load_mods_name = load_mods_name:sub(1,load_mods_name:len() - 4)
	end
end

is_daemon = tonumber(is_daemon)
if not is_daemon or is_daemon == 1 then
	is_daemon = true
else
	is_daemon = false
end

local skynet_path = skynet_fly_path .. '/skynet/'
local server_path = "./"
local common_path = "../../common/"

local svr_name = file_util.get_cur_dir_name()
local config = {
	thread          = 4,
	start           = "main",
	harbor          = 0,
	profile         = true,
	lualoader       = skynet_fly_path .. "/lualib/loader.lua",
	bootstrap       = "snlua bootstrap", --the service for bootstrap
	logger          = "log_service",
	loglevel        = "info",
	logpath         = server_path .. 'logs/',
	logfilename     = 'server.log',
	logservice      = 'snlua',
	daemon          = is_daemon and "./skynet.pid" or nil,
	svr_id          = 1,
	svr_name        = svr_name,
	debug_port      = 8888,
	skynet_fly_path = skynet_fly_path,
	preload         = skynet_fly_path .. '/lualib/preload.lua;',
	cpath           = skynet_fly_path .. "/cservice/?.so;" .. skynet_path .. "cservice/?.so;",

	lua_cpath       = skynet_fly_path .. "/luaclib/?.so;" .. skynet_path .. "luaclib/?.so;",

	--luaservice 约束服务只能放在 server根目录 || server->service || common->service || skynet_fly->service || skynet->service
	luaservice      = server_path .. "?.lua;" ..
		server_path .. "service/?.lua;" ..
		skynet_fly_path .. "/service/?.lua;" ..
		common_path .. "service/?.lua;" ..
		skynet_path .. "service/?.lua;",

	lua_path        = "",
	enablessl       = true,
	loadmodsfile    = load_mods_name or "load_mods", --可热更服务启动配置
}

config.lua_path = file_util.create_luapath(skynet_fly_path)

local load_mods_f = require(config.loadmodsfile)
if load_mods_f.share_config_m and load_mods_f.share_config_m.default_arg and load_mods_f.share_config_m.default_arg.server_cfg then
	local cfg = load_mods_f.share_config_m.default_arg.server_cfg
	if cfg.svr_id then
		config.svr_id = cfg.svr_id
	end
	if cfg.thread then
		config.thread = cfg.thread
	end
	if cfg.logpath then
		config.logpath = cfg.logpath
	end
	if cfg.loglevel then
		config.loglevel = cfg.loglevel
	end
	if cfg.logfilename then
		config.logfilename = cfg.logfilename
	end
	if cfg.debug_port then
		config.debug_port = cfg.debug_port
	end
end


local config_path = server_path .. svr_name .. '_config.lua'

local file = io.open(config_path, 'w+')
assert(file)
local str = table_util.table_to_luafile("G", config)
file:write(str)
file:close()
print("make " .. config_path)
