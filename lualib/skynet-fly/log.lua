local skynet = require "skynet"
local table_util = require "skynet-fly.utils.table_util"
local sformat = string.format
local sdump = table_util.dump
local serror = skynet.error
local debug_getinfo = debug.getinfo
local LOG_SERVICE_NAME = LOG_SERVICE_NAME
local pairs = pairs
local assert = assert
local tostring = tostring
local tinsert = table.insert
local sfind = string.find
local ssub = string.sub
local schar = string.char
local tpack = table.pack

local M = {
	DEBUG = -1,
	INFO = 0,
	WARN = 2,
	ERROR = 3,
	FATAL = 4,

	TRACEBACK = 5, --错误堆栈
	UNKNOWN = 6,   --未知
}

local level_map = {
	['debug'] = M.DEBUG,
	['info'] = M.INFO,
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
		if level < use_level then return end
		local msgs = tpack(...)
		if #msgs < 1 then return end

		local info = debug_getinfo(2,"Sl")
		local lineinfo = info.short_src .. ":" .. info.currentline
		local log_str = ""
		if is_format then
			log_str = sformat(...)
		else
			for i = 1,msgs.n do
				log_str = log_str .. sdump(msgs[i]) .. ' '
			end
		end

		serror(sformat("[%s][%s][%s]%s", level_name, LOG_SERVICE_NAME, lineinfo, log_str))

		local log_hook = hooks[level]
		local len = #log_hook
		for i = 1, len do
			local func = log_hook[i]
			func(log_str)
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

local g_log_type_info = {
	log_type = M.UNKNOWN,            --日志类型
	address = "",         		     --服务地址
	time_date = "",                  --日期
	server_name = "",                --服务名称
	code_line = "",                  --代码行号
}

--解析日志
function M.parse(log_str)
	local log_type = M.UNKNOWN
	local address = ""         		      --服务地址
	local time_date = ""                  --日期
	local server_name = ""                --服务名称
	local code_line = ""                  --代码行号
	if sfind(log_str,"[:",nil,true) then
		address = ssub(log_str,2,10)
		time_date = ssub(log_str,13,32)

		if schar(log_str:byte(34)) == '[' then
			local _,type_e = sfind(log_str,"]",38,true)
			if type_e then
				local log_type_str = ssub(log_str,35,type_e - 1)
				log_type = level_map[log_type_str] or M.UNKNOWN

				local s_n_b = type_e + 2
				local _,s_n_e = sfind(log_str,"]",s_n_b,true)
				if s_n_e then
					server_name = ssub(log_str,s_n_b,s_n_e - 1)
					
					local c_l_b = s_n_e + 2
					local _,c_l_e = sfind(log_str,"]",c_l_b,true)
					if c_l_e then
						code_line = ssub(log_str,c_l_b,c_l_e - 1)
					end
				end
			end
		elseif sfind(log_str,"stack traceback:",nil,true) then
			log_type = M.TRACEBACK
		end
	else
		log_type = M.UNKNOWN
	end

	g_log_type_info.log_type = log_type
	g_log_type_info.address = address
	g_log_type_info.time_date = time_date
	g_log_type_info.server_name = server_name
	g_log_type_info.code_line = code_line
	return g_log_type_info
end

return M