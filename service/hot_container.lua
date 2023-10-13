local skynet = require "skynet"
skynet.cache.mode "OFF"

local assert = assert
local tonumber = tonumber
local table = table
local ipairs = ipairs
local next = next

local ARGV = {...}
MODULE_NAME = ARGV[1]
local INDEX = tonumber(ARGV[2])
local LAUNCH_DATE = ARGV[3]
local LAUNCH_TIME = ARGV[4]
local VERSION = ARGV[5]
assert(MODULE_NAME)

local new_loaded = {}

if INDEX == 1 then
	local old_require = require
	local loaded = package.loaded
	require = function(name)
		if not loaded[name] then
			new_loaded[name] = true
		end
		return old_require(name)
	end
end

local MODULE_NAME = MODULE_NAME
local module_info = require "module_info"


local contriner_client = require "contriner_client"
contriner_client:close_ready()

local CMD = require(MODULE_NAME)
local write_mod_required = require "write_mod_required"
local skynet_util = require "skynet_util"
local log = require "log"

local timer = require "timer"

local NOT_FUNC = function() return true end

local module_start = CMD.start
local module_exit = CMD.exit
local module_before_exit = CMD.before_exit or NOT_FUNC
local module_cancel_exit = CMD.cancel_exit or NOT_FUNC
local module_check_exit = CMD.check_exit or NOT_FUNC
local module_fix_exit = CMD.fix_exit or NOT_FUNC
assert(module_start,MODULE_NAME .. " not start func")
assert(module_exit,MODULE_NAME .. " not exit func")

local old_skynet_exit = skynet.exit

local SELF_ADDRESS = skynet.self()

module_info.set_base_info {
	module_name = MODULE_NAME,
	index = INDEX,
	launch_date = LAUNCH_DATE,
	launch_time = LAUNCH_TIME,
	version = VERSION,
}

skynet.exit = function()
	log.info("mod exit ",MODULE_NAME,INDEX,LAUNCH_DATE)
	old_skynet_exit()
end

local check_timer = nil
local is_fix_check_exit = nil

local g_source_map = {}        --来访者列表

local function check_exit()
	if not is_fix_check_exit then
		is_fix_check_exit = module_check_exit()
	end
	log.info("check_exit:",is_fix_check_exit,g_source_map)
	if is_fix_check_exit and not next(g_source_map) then
		--真正退出
		if module_exit() then
			timer:new(timer.minute * 10,1,skynet.exit)
		else
			log.warn("warning " .. MODULE_NAME .. ' can`t exit')
		end
		check_timer:cancel()
	end
end

function CMD.start(cfg)
	module_info.set_cfg(cfg)
	local ret = module_start(cfg)
	if INDEX == 1 then
		--start 之后require的文件，监视不到文件修改，触发不了check reload,所以加载文件要在start之前或者在start中全部require
		skynet.fork(write_mod_required,MODULE_NAME,new_loaded)
	end
	skynet.fork(contriner_client.open_ready)
	return ret
end

--退出
function CMD.exit()
	check_timer = timer:new(timer.minute * 10,0,check_exit)
	module_fix_exit() --确定要退出
end

--退出之前
function CMD.before_exit()
	contriner_client:close_switch()
	module_before_exit()
end

--取消退出
function CMD.cancel_exit()
	contriner_client:open_switch()
	module_cancel_exit()
end

--ping报道，用于记录来访地址
function CMD.ping(source,module_name) 
	if not module_name then
		--不是可热更服务，不用管
		return
	end

	if contriner_client:is_week_visitor(module_name) then
		return
	end

	g_source_map[source] = module_name
	skynet.fork(function()
		skynet.call('.monitor_exit','lua','watch',source)
		g_source_map[source] = nil
	end)
	return "pong"
end

skynet.start(function()
	skynet_util.lua_dispatch(CMD,{})
end)