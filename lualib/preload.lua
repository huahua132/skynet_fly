local skynet = require "skynet"
local debug = debug
local xpcall = xpcall

local skynet_fly_path = skynet.getenv('skynet_fly_path')
assert(skynet_fly_path,'not skynet_fly_path')

local util = loadfile(skynet_fly_path .. '/lualib/util.lua')()
assert(util,'can`t load util')

package.path = util.create_luapath(skynet_fly_path)

function x_pcall(f,...)
	return xpcall(f, debug.traceback, ...)
end