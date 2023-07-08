local skynet = require "skynet"
local math = math

local M = {}

local starttime
--整型的skynet_time 
function M.skynet_int_time()
	if not starttime then
		starttime = math.floor(skynet.starttime() * 100)
	end
	return skynet.now() + starttime
end

return M