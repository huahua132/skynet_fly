local skynet = require "skynet"
local contriner_launcher = require "skynet-fly.contriner.contriner_launcher"
local sharedata = require "skynet-fly.sharedata"

skynet.start(function()
	sharedata.load({
		'../../commonlualib/sharedata/',
		'./sharedata/',
	}, sharedata.enum.sharedata)

	sharedata.load({
		'../../commonlualib/sharetable/',
		'./sharetable/',
	}, sharedata.enum.sharetable)
	
	skynet.error("start record!!!>>>>>>>>>>>>>>>>>")
	contriner_launcher.run()

	skynet.exit()
end)