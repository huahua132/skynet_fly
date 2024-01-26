local skynet = require "skynet"
local cache = require "skynet.codecache"
local skynet_util = require "skynet_util"
cache.mode "OFF"
local assert = assert
local tonumber = tonumber

local ARGV = {...}
local MODULE_NAME = ARGV[1]
assert(MODULE_NAME)

local CMD = require(MODULE_NAME)

local module_start = CMD.start
local module_exit = CMD.exit
assert(module_start,MODULE_NAME .. " not start func")

function CMD.start(...)
	module_start(...)
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
	skynet_util.lua_dispatch(CMD)
end)