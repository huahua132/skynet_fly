local skynet = require "skynet"
local chat_filter = require "chat_filter"
local log = require "skynet-fly.log"
local json = require "cjson"

local assert = assert

local CMD = {}

function CMD.start()
	chat_filter.init()
	chat_filter.loadstring("http")

	local str = "http://www.baidu.com"
	local filter_str = chat_filter.filter_chat(str)
	log.info(str,filter_str)
	
	local a = {
		b = 20000,
	}

	local astr = json.encode(a)
	local b = json.decode(astr)
	log.info(b)

	return true
end

function CMD.exit()
	return true
end

return CMD