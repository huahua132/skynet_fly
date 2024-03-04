local skynet = require "skynet"
local chat_filter = require "chat_filter"
local log = require "skynet-fly.log"

local assert = assert

local CMD = {}

function CMD.start()
	chat_filter.init()
	chat_filter.loadstring("http")

	local str = "http://www.baidu.com"
	local filter_str = chat_filter.filter_chat(str)
	log.info(str,filter_str)
	
	return true
end

function CMD.exit()
	return true
end

return CMD