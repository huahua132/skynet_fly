local log = require "log"

local CMD = {}

--这里不会调用hook函数
log.error("test_m load")

--这里会调用hook函数
log.debug("test_m load")

function CMD.start()
	--这里会调用hook函数
	log.error("test_m start")
	log.debug("test_m start")
	return true
end

function CMD.exit()

end

return CMD