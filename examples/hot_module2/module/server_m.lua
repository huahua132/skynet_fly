local skynet = require "skynet"

local CMD = {}

local IS_CLOSE = false

function CMD.ping(from)
	skynet.error("ping:" .. from)
	return "pong:" ..skynet.self()
end

function CMD.start()
	return true
end

function CMD.exit()
	skynet.error(skynet.self(),"exit")
	skynet.timeout(500,function()
		IS_CLOSE = true
		skynet.exit()
	end)
end

function CMD.is_close()
	return IS_CLOSE
end

return CMD