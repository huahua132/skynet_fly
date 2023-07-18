local skynet = require "skynet"
local table_util = require "table_util"
local string = string
local debug_getinfo = debug.getinfo
local MODULE_NAME = MODULE_NAME
local SERVICE_NAME = SERVICE_NAME



local level_map = {
	['info'] = 0,
	['debug'] = 1,
	['warn'] = 2,
	['error'] = 3,
	['fatal'] = 4,
}

local loglevel = skynet.getenv('loglevel') or 'info'
local use_level = level_map[loglevel] or 0

local function create_log_func(level_name)
	local level = level_map[level_name]
	return function (...)
		local msgs = {...}

		if level < use_level or #msgs < 1 then return end

		local info = debug_getinfo(2,"Sl")
		local lineinfo = info.short_src .. ":" .. info.currentline

		local log_str = ""
		for i = 1,#msgs do
			log_str = log_str .. table_util.dump(msgs[i]) .. ' '
		end

		local server_name = SERVICE_NAME
		if MODULE_NAME then
			server_name = MODULE_NAME
		end

		log_str = string.format("[%s][%s][%s]%s",level_name,server_name,lineinfo,log_str)
		skynet.error(log_str)
	end
end

local M = {}

M.info = create_log_func("info")
M.debug = create_log_func("debug")
M.warn = create_log_func("warn")
M.error = create_log_func("error")
M.fatal = create_log_func("fatal")

return M