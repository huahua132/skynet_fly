local assert = assert
local pairs = pairs
local ARGV = { ... }
local skynet_fly_path = ARGV[1]
local load_mods_name = ARGV[2]
local is_daemon = ARGV[3]
local recordfile = ARGV[4]
assert(skynet_fly_path, '缺少 skynet_fly_path')
if package.config:sub(1, 1) == '\\' then
	package.cpath = skynet_fly_path .. "/luaclib/?.dll;"
else
	package.cpath = skynet_fly_path .. "/luaclib/?.so;"
end

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

skynet_fly_path = file_util.convert_windows_to_linux_relative(skynet_fly_path)

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
	svr_type 		= 1,				 --服务类型(可理解为svr_name的唯一编码(0,255))
	debug_port      = 8888,
	skynet_fly_path = skynet_fly_path,
	preload         = file_util.path_join(skynet_fly_path, '/lualib/skynet-fly/preload.lua;'),
	--luaservice 约束服务只能放在 server根目录 || server->service || common->service || skynet_fly->service || skynet->service
	luaservice      = server_path .. "?.lua;" ..
					  server_path .. "service/?.lua;" ..
					  file_util.path_join(skynet_fly_path, '/service/?.lua;') ..
					  common_path .. "service/?.lua;" ..
					  skynet_path .. "service/?.lua;",

	lua_path        = "",
	enablessl       = true,
	loadmodsfile    = load_mods_name,     --可热更服务启动配置
	recordfile      = recordfile,		  --播放录像的文件名
	recordlimit     = 1024 * 1024 * 100,  --录像记录限制(字节数) 超过不再写录像
	machine_id      = 1,				  --机器ID(全局唯一)
	trace			= 0,				  --链路追踪
	certfile        = "./server-cert.pem",--ssl 证书相关
	keyfile 		= "./server-key.pem",
}

if package.config:sub(1, 1) == '\\' then
	config.cpath = file_util.path_join(skynet_fly_path, '/cservice/?.dll;') .. skynet_path .. "cservice/?.dll;"
	config.lua_cpath = file_util.path_join(skynet_fly_path, '/luaclib/?.dll;') .. skynet_path .. "luaclib/?.dll;"
else
	config.cpath = file_util.path_join(skynet_fly_path, '/cservice/?.so;') .. skynet_path .. "cservice/?.so;"
	config.lua_cpath = file_util.path_join(skynet_fly_path, '/luaclib/?.so;') .. skynet_path .. "luaclib/?.so;"
end

config.lua_path = file_util.create_luapath(skynet_fly_path)

local load_mods_f = loadfile(load_mods_name)
if load_mods_f then
	load_mods_f = load_mods_f()
end

if load_mods_f and load_mods_f.share_config_m and load_mods_f.share_config_m.default_arg and load_mods_f.share_config_m.default_arg.server_cfg then
	local cfg = load_mods_f.share_config_m.default_arg.server_cfg
	for k, v in pairs(cfg) do
		config[k] = v
	end
end

--重放录像时用一个工作线程即可
if recordfile then
	config.thread = 1
end

local file_path = server_path .. 'make/'

local isok, err = file_util.mkdir(file_path)
if not isok then
	error("create file_path err " .. err)
end

local config_path = file_path .. svr_name .. '_config.lua'

local file = io.open(config_path, 'w+')
assert(file)
local str = table_util.table_to_luafile("G", config)

file:write(str)
file:close()
print("make " .. config_path)
