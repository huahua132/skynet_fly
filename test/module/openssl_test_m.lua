local skynet = require "skynet"
local openssl = require "openssl"
local httpc = require "httpc"
local log = require "log"

local assert = assert

local CMD = {}

function CMD.start()
	local data = "dasadddddd"
	local digest = assert(openssl.digest)
  	local hmac = assert(openssl.hmac)

	local HMAC = {
		SHA256 = function(data, key) return hmac.new('sha256',key):final(data) end;
		SHA384 = function(data, key) return hmac.new('sha384',key):final(data) end;
		SHA512 = function(data, key) return hmac.new('sha512',key):final(data) end;
	  }
	
	local DIGEST = {
		SHA256 = function(data, hex) return digest.digest('sha256', data, not hex) end;
		SHA384 = function(data, hex) return digest.digest('sha384', data, not hex) end;
		SHA512 = function(data, hex) return digest.digest('sha512', data, not hex) end;
	}

	local key = HMAC.SHA256(data,"key")
	log.error(key)
	local ret = httpc.get("https://www.baidu.com")
	log.error("https ",ret)
	return true
end

function CMD.exit()

end

return CMD