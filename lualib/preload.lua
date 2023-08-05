local skynet = require "skynet"
local debug = debug
local xpcall = xpcall
local pcall = pcall
local math = math

local tremove = table.remove
local tunpack = table.unpack

--preload中 require的文件都不能热更

local skynet_fly_path = skynet.getenv('skynet_fly_path')
assert(skynet_fly_path,'not skynet_fly_path')

local file_util = loadfile(skynet_fly_path .. '/lualib/utils/file_util.lua')()
assert(file_util,'can`t load file_util')

local log = loadfile(skynet_fly_path .. '/lualib/log.lua')()
assert(log,"not log file")

package.path = file_util.create_luapath(skynet_fly_path)

function x_pcall(f,...)
	return xpcall(f, debug.traceback, ...)
end

local x_pcall = x_pcall

function xx_pcall(f,...)
	local ret = {x_pcall(f,...)}
	local isok = tremove(ret,1)
	if not isok then
		log.fatal(ret[1])
		return
	end

	return tunpack(ret)
end