local log = require "log"

log.info("after_load  load")

--钩子函数
log.add_hook(log.ERROR,function(logstr)
	log.info("hook error log :",logstr)
end)