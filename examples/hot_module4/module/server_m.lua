local skynet = require "skynet"

local CMD = {}

local IS_CLOSE = false

function CMD.ping(from)
	skynet.error("server ping:" .. from)
	return "server1 pong:" ..skynet.self()
end

function CMD.start()
	return true
end

function CMD.exit()
	
end

function CMD.is_close()
	return IS_CLOSE
end

return CMD