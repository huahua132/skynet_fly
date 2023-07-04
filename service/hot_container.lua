local skynet = require "skynet"
local cache = require "skynet.codecache"
cache.mode "OFF"
local assert = assert
local tonumber = tonumber
local table = table

local ARGV = {...}
MODULE_NAME = ARGV[1]
local INDEX = tonumber(ARGV[2])
local LAUNCH_TIME = ARGV[3]
assert(MODULE_NAME)

local log = require "log"

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

local CMD = require(MODULE_NAME)
local write_mod_required = require "write_mod_required"

local module_start = CMD.start
local module_exit = CMD.exit
local module_before_exit = CMD.before_exit
assert(module_start,MODULE_NAME .. " not start func")
assert(module_exit,MODULE_NAME .. " not exit func")

local old_skynet_exit = skynet.exit

skynet.exit = function()
	log.info("mod exit ",MODULE_NAME,INDEX,LAUNCH_TIME)
	old_skynet_exit()
end

function CMD.start(...)
	local ret = {module_start(...)}
	if INDEX == 1 then
		--start 之后require的文件，监视不到文件修改，触发不了check reload,所以加载文件要在start之前或者在start中全部require
		skynet.fork(write_mod_required,MODULE_NAME,new_loaded)
	end
	return table.unpack(ret)
end

function CMD.exit()
	module_exit()
end

--退出之前
function CMD.before_exit()
	if module_before_exit then
		module_before_exit()
	end
end

skynet.start(function()
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