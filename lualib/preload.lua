local skynet = require "skynet"
local debug = debug
local xpcall = xpcall
local math = math

--preload中 require的文件都不能热更

local skynet_fly_path = skynet.getenv('skynet_fly_path')
assert(skynet_fly_path,'not skynet_fly_path')

local file_util = loadfile(skynet_fly_path .. '/lualib/utils/file_util.lua')()
assert(file_util,'can`t load file_util')

package.path = file_util.create_luapath(skynet_fly_path)

function x_pcall(f,...)
	return xpcall(f, debug.traceback, ...)
end