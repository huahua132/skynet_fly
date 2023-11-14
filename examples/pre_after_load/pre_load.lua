local log = require "log"
local test = require "test"
--preload中 require的文件也能热更
log.info("pre_load load")

log.add_hook(log.DEBUG,function(log_str)
	log.info("hook debug log ",log_str)
	log.info("test >>>>",test.test())
end)