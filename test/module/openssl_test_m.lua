local skynet = require "skynet"
local crypt_util = require "crypt_util"
local httpc = require "httpc"
local log = require "log"

local assert = assert

local CMD = {}

function CMD.start()
	local data = "dasadddddd"
	
	local key = crypt_util.HMAC.SHA256(data,"key")
	log.error(key)
	local code, body = httpc.get("https://www.baidu.com", '/')
	log.error("https ",code, body)
	return true
end

function CMD.exit()
	return true
end

return CMD