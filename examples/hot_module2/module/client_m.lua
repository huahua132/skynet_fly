local skynet = require "contriner_client"

local CMD = {}

function CMD.start()
	skynet.fork(function()
		while true do
			skynet.error(skynet.contriner_mod_call("server_m","ping",skynet.self()))
			skynet.sleep(100)
		end
	end)
end

function CMD.exit()

end

function CMD.is_close()

end

function CMD.init()

end

return CMD