local skynet = require "skynet"

local g_debug_console = nil
local CMD = {}

function CMD.start(config)
    g_debug_console = skynet.uniqueservice("debug_console", skynet.getenv('debug_port'))
	return true
end

function CMD.call(...)
    return skynet.call(g_debug_console, 'lua', ...)
end

function CMD.exit()
	return true
end

return CMD