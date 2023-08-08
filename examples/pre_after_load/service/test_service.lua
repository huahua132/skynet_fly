local skynet = require "skynet"
local log = require "log"

--这里不会调用hook函数
log.error("test service load")
--这里会调用hook函数
log.debug("test service load")

skynet.start(function()
	--这里会调用hook函数
	log.error("test service start")
	log.debug("test service start")
end)