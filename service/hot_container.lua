local skynet = require "skynet"
local cache = require "skynet.codecache"
cache.mode "OFF"
local assert = assert
local tonumber = tonumber

local ARGV = {...}
local MODULE_NAME = ARGV[1]
local INDEX = tonumber(ARGV[2])
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

local CMD = require(MODULE_NAME)
local write_mod_required = require "write_mod_required"

local module_start = CMD.start
local module_exit = CMD.exit
assert(module_start,MODULE_NAME .. " not start func")

function CMD.start(...)
	module_start(...)
	skynet.fork(write_mod_required,MODULE_NAME,new_loaded)
end

function CMD.exit(list)
	if module_exit then
		module_exit()
	else
		skynet.timeout(60,function()
			skynet.error(MODULE_NAME .. ' exit')
		end)
	end
end

skynet.start(function()
	if CMD.init then
		CMD.init()
	end

	skynet.dispatch('lua',function(session,source,cmd,...)
		local f = CMD[cmd]
		assert(f,'cmd no found :'..cmd)
	
		if session == 0 then
			f(...)
		else
			skynet.retpack(f(...))
		end
	end)
end)