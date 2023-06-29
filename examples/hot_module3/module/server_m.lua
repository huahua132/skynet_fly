local skynet = require "skynet"

local CMD = {}

local IS_CLOSE = false

function CMD.ping(from)
	skynet.error("server1 ping:" .. from)
	return "server1 pong:" ..skynet.self()
end

function CMD.start()

end

function CMD.exit()
	skynet.error(skynet.self(),"server1 exit")
	skynet.fork(skynet.exit)
end

function CMD.is_close()
	return IS_CLOSE
end

return CMD