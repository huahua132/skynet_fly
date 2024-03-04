local skynet = require "skynet"
local contriner_launcher = require "skynet-fly.contriner.contriner_launcher"

skynet.start(function()
	skynet.call('.logger','lua','add_hook', 'loghook')
	skynet.error("start log_hook!!!>>>>>>>>>>>>>>>>>")
	contriner_launcher.run()
	skynet.exit()
end)