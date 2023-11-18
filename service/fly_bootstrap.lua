local skynet = require "skynet"
local harbor = require "skynet.harbor"
local service = require "skynet.service"
local env_util = require "env_util"
require "skynet.manager"	-- import skynet.launch, ...

skynet.start(function()
	local preload = skynet.getenv("preload")
	if preload then
		env_util.add_pre_load(preload:sub(1,preload:len() - 1))
	end

	skynet.launch("snlua","bootstrap")
end)
