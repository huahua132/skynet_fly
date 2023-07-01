local skynet = require "skynet"
local math = math

local M = {}

local starttime
--毫秒时间戳
function M.millisecondtime()
	if not starttime then
		starttime = math.floor(skynet.starttime() * 100)
	end
	return skynet.now() + starttime
end

return M