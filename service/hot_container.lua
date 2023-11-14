local skynet = require "skynet"
local assert = assert
local tonumber = tonumber
local table = table
local ipairs = ipairs
local next = next
local pairs = pairs

local ARGV = {...}
MODULE_NAME = ARGV[1]
local INDEX = tonumber(ARGV[2])
local LAUNCH_DATE = ARGV[3]
local LAUNCH_TIME = ARGV[4]
local VERSION = ARGV[5]
assert(MODULE_NAME)

local new_loaded = _loaded

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

local module_start = CMD.start                             --开始
local module_exit = CMD.exit							   --退出
local module_herald_exit = CMD.herald_exit or NOT_FUNC	   --预告退出
local module_cancel_exit = CMD.cancel_exit or NOT_FUNC	   --取消退出
local module_check_exit = CMD.check_exit or NOT_FUNC	   --检查退出
local module_fix_exit = CMD.fix_exit or NOT_FUNC		   --确认退出
assert(module_start,MODULE_NAME .. " not start func")
assert(module_exit,MODULE_NAME .. " not exit func")

local old_skynet_exit = skynet.exit

local SELF_ADDRESS = skynet.self()
local SERVER_STATE = "loading"

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

local g_check_timer = nil
local is_fix_check_exit = nil
local g_exit_timer = nil

local g_source_map = {}        --来访者列表

skynet_util.register_info_func("hot_container",function()
	local info = {
		module_info = module_info.get_base_info(),
		server_state = SERVER_STATE,
		source_map = g_source_map,
		exit_remain_time = g_exit_timer and g_exit_timer:remain_expire() or 0,
		week_visitor_map = contriner_client:get_week_visitor_map(),
		need_visitor_map = contriner_client:get_need_visitor_map(),
	}

	return info
end)

local function check_exit()
	if not is_fix_check_exit then
		is_fix_check_exit = module_check_exit()
	end
	log.info("check_exit:",is_fix_check_exit,g_source_map)
	if is_fix_check_exit then
		for source,_ in pairs(g_source_map) do
			--问对方是否还需要访问自己
			if skynet.call(source, 'lua', 'is_not_need_visitor', SELF_ADDRESS, MODULE_NAME) then
				g_source_map[source] = nil
			end
		end

		if not next(g_source_map) then
			--真正退出
			log.info("exited")
			SERVER_STATE = "exited"
			if module_exit() then
				g_exit_timer = timer:new(timer.minute * 10,1,skynet.exit)
			else
				log.warn("warning " .. MODULE_NAME .. ' can`t exit')
			end
			g_check_timer:cancel()
		end
	end
end

function CMD.start(cfg)
	module_info.set_cfg(cfg)
	local ret = module_start(cfg)
	if INDEX == 1 then
		--start 之后require的文件，监视不到文件修改，触发不了check reload,所以加载文件要在start之前或者在start中全部require
		skynet.fork(write_mod_required,MODULE_NAME,new_loaded)
	end
	new_loaded = nil
	contriner_client.open_ready()
	SERVER_STATE = "starting"
	return ret
end

--退出
function CMD.exit()
	g_check_timer = timer:new(timer.minute * 10,timer.loop,check_exit)
	g_check_timer:after_next()
	module_fix_exit() --确定要退出
	SERVER_STATE = "fix_exited"
end

--退出之前
function CMD.herald_exit()
	contriner_client:close_switch()
	module_herald_exit()
end

--取消退出
function CMD.cancel_exit()
	contriner_client:open_switch()
	module_cancel_exit()
end

--注册访问，用于记录来访地址
assert(not CMD['register_visitor'], "repeat cmd register_visitor")
function CMD.register_visitor(source,module_name) 
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

--是否不再需要访问
assert(not CMD['is_not_need_visitor'], "repeat cmd is_not_need_visitor")
function CMD.is_not_need_visitor(source,module_name)
	return contriner_client:is_not_need_visitor(module_name, source)
end

skynet.start(function()
	skynet_util.lua_dispatch(CMD,{})
end)