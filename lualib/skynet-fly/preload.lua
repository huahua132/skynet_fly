local skynet = require "skynet"
local debug = debug
local xpcall = xpcall
local pcall = pcall
local math = math
local tostring = tostring

local tremove = table.remove
local tunpack = table.unpack

local skynet_fly_path = skynet.getenv('skynet_fly_path')
assert(skynet_fly_path,'not skynet_fly_path')

local file_util = loadfile(skynet_fly_path .. '/lualib/skynet-fly/utils/file_util.lua')()
assert(file_util,'can`t load file_util')

local log = loadfile(skynet_fly_path .. '/lualib/skynet-fly/log.lua')()
assert(log,"not log file")

package.path = file_util.create_luapath(skynet_fly_path)

-- 为了处理err是个table的情况下，无法获取到堆栈
local function error_handler(err)
	return tostring(err) .. debug.traceback("", 2)
end

function x_pcall(f,...)
	return xpcall(f, error_handler, ...)
end

local x_pcall = x_pcall

function xx_pcall(f,...)
	local ret = {x_pcall(f,...)}
	local isok = tremove(ret,1)
	if not isok then
		log.error(ret[1])
		return
	end

	return tunpack(ret)
end