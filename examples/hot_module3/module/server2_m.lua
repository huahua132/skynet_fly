local skynet = require "skynet"

local CMD = {}

local IS_CLOSE = false

function CMD.ping(from)
	skynet.error("server2 ping:" .. from)
	return "server2 pong:" ..skynet.self()
end

function CMD.start()
	return true
end

function CMD.exit()
	skynet.error(skynet.self(),"exit")
	skynet.fork(skynet.exit)
end

function CMD.is_close()
	return IS_CLOSE
end

return CMD