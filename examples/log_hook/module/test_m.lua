local log = require "log"
local skynet = require "skynet"

local CMD = {}

function CMD.start()
	log.add_hook(log.ERROR,function(log_str)
		log.info("hook_one logs:",log_str)
	end)

	log.add_hook(log.ERROR,function(log_str)
		log.info("hook_two logs:",log_str)
	end)

	log.info("hello skynet !!!")
	log.debug("hello skynet !!!")
	log.warn("hello skynet !!!")
	log.error("hello skynet !!!")
	log.fatal("hello skynet !!!")
	
	assert(1 == 2)
	return true
end

function CMD.exit()
	return true
end

return CMD