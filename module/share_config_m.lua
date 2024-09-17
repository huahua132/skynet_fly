local skynet = require "skynet"

local g_config = nil
local CMD = {}

function CMD.start(config)
	g_config = config
	return true
end

function CMD.query(k)
	return g_config[k]
end

function CMD.exit()
	return true
end

return CMD