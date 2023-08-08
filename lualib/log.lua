local skynet = require "skynet"
local table_util = require "table_util"
local sformat = string.format
local sdump = table_util.dump
local serror = skynet.error
local debug_getinfo = debug.getinfo
local MODULE_NAME = MODULE_NAME
local SERVICE_NAME = SERVICE_NAME
local pairs = pairs
local assert = assert
local tostring = tostring
local tinsert = table.insert
local ipairs = ipairs

local M = {
	INFO = 0,
	DEBUG = 1,
	WARN = 2,
	ERROR = 3,
	FATAL = 4,
}

local level_map = {
	['info'] = M.INFO,
	['debug'] = M.DEBUG,
	['warn'] = M.WARN,
	['error'] = M.ERROR,
	['fatal'] = M.FATAL,
}

--钩子函数
local hooks = {}
do
	for n,v in pairs(M) do
		hooks[v] = {}
	end
end

local loglevel = skynet.getenv('loglevel') or 'info'
local use_level = level_map[loglevel] or 0

local function create_log_func(level_name,is_format)
	local level = level_map[level_name]
	return function (...)
		local msgs = {...}

		if level < use_level or #msgs < 1 then return end

		local info = debug_getinfo(2,"Sl")
		local lineinfo = info.short_src .. ":" .. info.currentline
		local log_str = ""
		if is_format then
			log_str = sformat(...)
		else
			for i = 1,#msgs do
				log_str = log_str .. sdump(msgs[i]) .. ' '
			end
		end

		local server_name = SERVICE_NAME
		if MODULE_NAME then
			server_name = MODULE_NAME
		end

		serror(sformat("[%s][%s][%s]%s",level_name,server_name,lineinfo,log_str))

		local log_hook = hooks[level]
		for _,hook_func in ipairs(log_hook) do
			hook_func(log_str)
		end
	end
end

M.info = create_log_func("info")
M.debug = create_log_func("debug")
M.warn = create_log_func("warn")
M.error = create_log_func("error")
M.fatal = create_log_func("fatal")
M.info_fmt = create_log_func("info",true)
M.debug_fmt = create_log_func("debug",true)
M.warn_fmt = create_log_func("warn",true)
M.error_fmt = create_log_func("error",true)
M.fatal_fmt = create_log_func("fatal",true)

function M.add_hook(loglevel,hook_func)
	assert(hooks[loglevel],"not loglevel " .. tostring(loglevel))
	tinsert(hooks[loglevel],hook_func)
end

return M