local skynet = require "skynet"
local cache = require "skynet.codecache"
cache.mode "OFF"
local assert = assert
local tonumber = tonumber

local ARGV = {...}
local MODULE_NAME = ARGV[1]
local VERSION = tonumber(ARGV[2])
assert(MODULE_NAME)
assert(VERSION)

local CMD = require(MODULE_NAME)

local is_exit = false
local module_start = CMD.start
local module_exit = CMD.exit
assert(module_start,MODULE_NAME .. " not start func")

local new_id_list = nil

function CMD.start(...)
	module_start(...)
end

function CMD.exit(list)
	new_id_list = list
	is_exit = true
	if module_exit then
		module_exit()
	else
		skynet.timeout(60,function()
			skynet.error(MODULE_NAME .. ' exit')
		end)
	end
end

skynet.start(function()
	skynet.dispatch('lua',function(session,source,module_name,version,cmd,...)
		local f = CMD[cmd]
		assert(f,'cmd no found :'..cmd)
		
		if module_name ~= MODULE_NAME 
		or version ~= VERSION
		or (is_exit and CMD.is_close()) then
			return skynet.retpack("move",new_id_list)
		end

		if session == 0 then
			f(...)
		else
			skynet.retpack("OK",f(...))
		end
	end)
end)