local log = require "log"
--preload中 require的文件都不能热更
log.info("pre_load load")

log.add_hook(log.DEBUG,function(log_str)
	log.info("hook debug log ",log_str)
end)