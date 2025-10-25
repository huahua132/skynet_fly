---@diagnostic disable: duplicate-set-field, undefined-field, need-check-nil
local skynet = require "skynet"
local assert = assert
local tonumber = tonumber
local table = table
local ipairs = ipairs
local next = next
local pairs = pairs
local string = string

local ARGV = {...}
MODULE_NAME = ARGV[1]
local INDEX = tonumber(ARGV[2])
local LAUNCH_DATE = ARGV[3]
local LAUNCH_TIME = tonumber(ARGV[4])
local VERSION = tonumber(ARGV[5])
local IS_RECORD_ON = tonumber(ARGV[6])			--是否记录录像
assert(MODULE_NAME)

local new_loaded = _loaded

if IS_RECORD_ON == 1 then
	local record_file_name = string.format("%s-%s-%s-%s-%08x", MODULE_NAME, VERSION, INDEX, os.date('%Y%m%d-%H%M%S', LAUNCH_TIME), skynet.self())
	skynet.start_record(ARGV, record_file_name)
end

local CMD = {}

local skynet_util = require "skynet-fly.utils.skynet_util"
local MODULE_NAME = MODULE_NAME
local module_info = require "skynet-fly.etc.module_info"
module_info.set_base_info {
	module_name = MODULE_NAME,
	index = INDEX,
	launch_date = LAUNCH_DATE,
	launch_time = LAUNCH_TIME,
	version = VERSION,
	is_record_on = IS_RECORD_ON,
}

local container_interface = require "skynet-fly.container.container_interface"
local table_util = require "skynet-fly.utils.table_util"
local SERVER_STATE_TYPE = require "skynet-fly.enum.SERVER_STATE_TYPE"
local hotfix = require "skynet-fly.hotfix.hotfix"
hotfix_require = hotfix.require

local g_breakpoint_debug_module_name = skynet.getenv("breakpoint_debug_module_name")
local g_breakpoint_debug_module_index = tonumber(skynet.getenv("breakpoint_debug_module_index"))

local g_breakpoint_debug_host = nil
local g_breakpoint_debug_port = nil

if g_breakpoint_debug_module_name == MODULE_NAME and INDEX == g_breakpoint_debug_module_index then
	g_breakpoint_debug_host = skynet.getenv("breakpoint_debug_host")
	g_breakpoint_debug_port = tonumber(skynet.getenv("breakpoint_debug_port"))
end

local SERVER_STATE = SERVER_STATE_TYPE.loading
local IS_CLOSE_HOT_RELOAD = false

local g_time_point_obj = nil

--启动成功之后回调列表
local g_start_after_cb = {}

--确定退出之后的回调列表
local g_fix_exit_after_cb = {}

--container_interface
function container_interface.get_server_state()
	return SERVER_STATE
end

function container_interface.hook_start_after(cb)
	table.insert(g_start_after_cb, cb)
end

function container_interface.hook_fix_exit_after(cb)
	table.insert(g_fix_exit_after_cb, cb)
end

function container_interface.close_hotreload()
	IS_CLOSE_HOT_RELOAD = true
end

local container_client = require "skynet-fly.client.container_client"
container_client:close_ready()
local write_mod_required = require "skynet-fly.write_mod_required"
local log = require "skynet-fly.log"
local timer = require "skynet-fly.timer"

do
	local mod_cmd = require(MODULE_NAME)
	for name,func in pairs(mod_cmd) do
		assert(not CMD[name], "exists cmd name " .. name)
		CMD[name] = func
	end
end

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
		server_state = container_interface.get_server_state(),
		source_map = {},
		exit_remain_time = g_exit_timer and g_exit_timer:remain_expire() or 0,
		week_visitor_map = container_client:get_week_visitor_map(),
		need_visitor_map = container_client:get_need_visitor_map(),
	}

	for source in pairs(g_source_map) do
		info['' .. source] = true
	end

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
			SERVER_STATE = SERVER_STATE_TYPE.exited
			if module_exit() then
				g_exit_timer = timer:new(timer.minute * 10,1,skynet.exit)
			else
				log.warn("warning " .. MODULE_NAME .. ' can`t exit')
			end
			g_check_timer:cancel()
			skynet.close_record()
		end
	end
end

function CMD.start(cfg, auto_reload, record_backup)
	log.info("start begin")
	if g_breakpoint_debug_host and g_breakpoint_debug_port then
		log.warn_fmt("start breakpoint module_name[%s] index[%s] host[%s] port[%s]", MODULE_NAME, INDEX, g_breakpoint_debug_host, g_breakpoint_debug_port)
		require("skynet-fly.LuaPanda").start(g_breakpoint_debug_host, g_breakpoint_debug_port);
	end

	module_info.set_cfg(cfg)
	local ret = module_start(cfg)
	if INDEX == 1 then
		--start 之后require的文件，监视不到文件修改，触发不了check reload,所以加载文件要在start之前或者在start中全部require
		skynet.fork(write_mod_required,"make/module_info",MODULE_NAME,new_loaded)

		local hotfix_loaded = hotfix.get_loadedmap()
		skynet.fork(write_mod_required,"make/hotfix_info",MODULE_NAME,hotfix_loaded)
	end

	if ret then
		for _,func in ipairs(g_start_after_cb) do
			skynet.fork(func)
		end

		--自动热更处理
		if auto_reload and INDEX == 1 then
			local timer_point = require "skynet-fly.time_extend.timer_point"
			g_time_point_obj = timer_point:new(auto_reload.type)

			local function set_time_point_opt(opt)
				if auto_reload[opt] then
					local set_func = assert(timer_point['set_' .. opt], "opt func not exists: " .. opt)
					g_time_point_obj = set_func(g_time_point_obj, auto_reload[opt])
				end
			end
			set_time_point_opt('month')
			set_time_point_opt('day')
			set_time_point_opt('hour')
			set_time_point_opt('min')
			set_time_point_opt('sec')
			set_time_point_opt('wday')
			set_time_point_opt('yday')
			g_time_point_obj = g_time_point_obj:builder(function()
				log.info("auto reload >>>>>>>>>> ", MODULE_NAME)
				skynet.send('.container_mgr','lua','load_modules', skynet.self(), MODULE_NAME)
			end)
		end

		--录像保留文件整理
		if record_backup and INDEX == 1 and IS_RECORD_ON == 1 then
			local logrotate = require "skynet-fly.logrotate"
			skynet.fork(function()
				local rotate_obj = logrotate:new()
				:set_file_path(skynet.getenv('recordpath'))
				local function set_rotate_opt(opt)
					if record_backup[opt] then
						local set_func = assert(logrotate['set_' .. opt], "opt func not exists: " .. opt)
						rotate_obj = set_func(rotate_obj, record_backup[opt])
					end
				end
				set_rotate_opt('max_age')
				set_rotate_opt('max_backups')

				set_rotate_opt('point_type')
				set_rotate_opt('month')
				set_rotate_opt('day')
				set_rotate_opt('hour')
				set_rotate_opt('min')
				set_rotate_opt('sec')
				set_rotate_opt('wday')
				set_rotate_opt('yday')
				
				rotate_obj:set_back_pattern(MODULE_NAME)	--设置匹配文件名
				rotate_obj:builder()
			end)
		end

		container_client:open_ready()
		SERVER_STATE = SERVER_STATE_TYPE.starting
	else
		SERVER_STATE = SERVER_STATE_TYPE.start_failed
	end

	if INDEX == 1 and IS_CLOSE_HOT_RELOAD then
		skynet.send('.container_mgr', 'lua', 'close_loads', SELF_ADDRESS, MODULE_NAME)
	end
	log.info("start end")
	return ret
end

--退出
assert(not CMD['close'], "repeat cmd close")
function CMD.close()
	log.info("fix_exit begin")
	g_check_timer = timer:new(timer.minute * 10,timer.loop,check_exit)
	g_check_timer:after_next()
	module_fix_exit() --确定要退出
	for _,func in ipairs(g_fix_exit_after_cb) do
		skynet.fork(func)
	end
	SERVER_STATE = SERVER_STATE_TYPE.fix_exited

	if g_time_point_obj then
		g_time_point_obj:cancel()
	end
	log.info("fix_exit end")
end

--退出之前
function CMD.herald_exit()
	log.info("herald_exit begin")
	container_client:close_switch()
	module_herald_exit()
	log.info("herald_exit end")
end

--取消退出
function CMD.cancel_exit()
	log.info("cancel_exit begin")
	container_client:open_switch()
	module_cancel_exit()
	log.info("cancel_exit end")
end

--注册访问，用于记录来访地址
assert(not CMD['register_visitor'], "repeat cmd register_visitor")
function CMD.register_visitor(source,module_name,servername)
	
	-- 弱访问者
	if module_name and container_client:is_week_visitor(module_name) then
		return
	end

	g_source_map[source] = module_name or servername
	skynet.fork(function()
		skynet.call('.monitor_exit', 'lua', 'watch', SELF_ADDRESS, source)
		g_source_map[source] = nil
	end)
	return "pong"
end

--热更
assert(not CMD['hotfix'], "repeat cmd hotfix")
function CMD.hotfix(hotfixmods)
	local isok, ret = hotfix.hotfix(hotfixmods)
	if isok and INDEX == 1 then
		local hotfix_loaded = hotfix.get_loadedmap()
		skynet.fork(write_mod_required,"make/hotfix_info",MODULE_NAME,hotfix_loaded)
	end
	return ret
end

skynet.start(function()
	skynet_util.lua_dispatch(CMD)
end)

if IS_RECORD_ON == 1 then
	skynet_util.reg_shutdown_func(function()
		skynet.close_record()
	end, -1) -- -1 最后执行
end