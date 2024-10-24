local assert = assert
local ARGV = { ... }
local skynet_fly_path = ARGV[1]
local load_mods_name = ARGV[2]
local is_daemon = ARGV[3]
local recordfile = ARGV[4]
assert(skynet_fly_path, '缺少 skynet_fly_path')

package.cpath = skynet_fly_path .. "/luaclib/?.so;"
package.path = './?.lua;' .. skynet_fly_path .. "/lualib/?.lua;"

local lfs = require "lfs"
local json = require "cjson"
local table_util = require "skynet-fly.utils.table_util"
local file_util = require "skynet-fly.utils.file_util"

load_mods_name = load_mods_name or 'load_mods.lua'

is_daemon = tonumber(is_daemon)
if not is_daemon or is_daemon == 1 then
	is_daemon = true
else
	is_daemon = false
end

local skynet_path = file_util.path_join(skynet_fly_path, '/skynet/')
local server_path = "./"
local common_path = "../../commonlualib/"

local svr_name = file_util.get_cur_dir_name()
local config = {
	thread          = 8,
	start           = "main",
	harbor          = 0,
	profile         = true,
	lualoader       = file_util.path_join(skynet_fly_path, '/lualib/skynet-fly/loader.lua'),
	bootstrap       = "snlua bootstrap", --the service for bootstrap
	logger          = "log_service",
	loglevel        = "info",
	logpath         = server_path .. 'logs/',
	recordpath      = server_path .. 'records/',
	logfilename     = 'server.log',
	logservice      = 'snlua',
	log_is_launch_rename = true,
	daemon          = is_daemon and string.format("./make/skynet.%s.pid", load_mods_name) or nil,
	svr_id          = 1,
	svr_name        = svr_name,
	debug_port      = 8888,
	skynet_fly_path = skynet_fly_path,
	preload         = file_util.path_join(skynet_fly_path, '/lualib/skynet-fly/preload.lua;'),
	cpath           = file_util.path_join(skynet_fly_path, '/cservice/?.so;') .. skynet_path .. "cservice/?.so;",

	lua_cpath       = file_util.path_join(skynet_fly_path, '/luaclib/?.so;') .. skynet_path .. "luaclib/?.so;",

	--luaservice 约束服务只能放在 server根目录 || server->service || common->service || skynet_fly->service || skynet->service
	luaservice      = server_path .. "?.lua;" ..
					  server_path .. "service/?.lua;" ..
					  file_util.path_join(skynet_fly_path, '/service/?.lua;') ..
					  common_path .. "service/?.lua;" ..
					  skynet_path .. "service/?.lua;",

	lua_path        = "",
	enablessl       = true,
	loadmodsfile    = load_mods_name, --可热更服务启动配置
	recordfile      = recordfile,		 --播放录像的文件名
	recordlimit     = 1024 * 1024 * 100, --录像记录限制(字节数) 超过不再写录像
}

config.lua_path = file_util.create_luapath(skynet_fly_path)

local load_mods_f = loadfile(load_mods_name)
if load_mods_f then
	load_mods_f = load_mods_f()
end

if load_mods_f and load_mods_f.share_config_m and load_mods_f.share_config_m.default_arg and load_mods_f.share_config_m.default_arg.server_cfg then
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
	if cfg.breakpoint_debug_host then										--断点调式连接host
		config.breakpoint_debug_host = cfg.breakpoint_debug_host
	end
	if cfg.breakpoint_debug_port then										--断点调式连接port
		config.breakpoint_debug_port = cfg.breakpoint_debug_port
	end
	if cfg.breakpoint_debug_module_name then								--断点调式的可热更模块名
		config.breakpoint_debug_module_name = cfg.breakpoint_debug_module_name
	end	
	if cfg.breakpoint_debug_module_index then								--断点调式的可热更模块启动下标
		config.breakpoint_debug_module_index = cfg.breakpoint_debug_module_index
	end
	if cfg.log_is_launch_rename ~= nil then
		config.log_is_launch_rename = cfg.log_is_launch_rename				--启动是否重命名旧日志
	end
	if cfg.recordpath then
		config.recordpath = cfg.recordpath									--录像文件目录
	end
	if cfg.recordlimit then													--录像记录限制
		config.recordlimit = cfg.recordlimit
	end
end

local file_path = server_path .. 'make/'

if not os.execute("mkdir -p " .. file_path) then
	error("create file_path err")
end

local config_path = file_path .. svr_name .. '_config.lua'

local file = io.open(config_path, 'w+')
assert(file)
local str = table_util.table_to_luafile("G", config)

file:write(str)
file:close()
print("make " .. config_path)
