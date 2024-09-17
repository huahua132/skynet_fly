local skynet = require "skynet"
local time_util = require "skynet-fly.utils.time_util"
local skynet_util = require "skynet-fly.utils.skynet_util"

local g_debug_console = nil
local CMD = {}

function CMD.start(config)
    g_debug_console = skynet.uniqueservice("debug_console", skynet.getenv('debug_port'))
	return true
end

--运行时长
function CMD.run_time()
    return time_util.time() - skynet.starttime()
end

function CMD.call(...)
    return skynet.call(g_debug_console, 'lua', ...)
end

function CMD.exit()
	return true
end

skynet_util.register_info_func("dec",function()
    return "I am is debug_console"
end)

return CMD