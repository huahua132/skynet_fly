local openssl = require "openssl"

local assert = assert

local digest = assert(openssl.digest)
local hmac = assert(openssl.hmac)

local M = {}

M.HMAC = {
    SHA256 = function(data, key) return hmac.new('sha256',key):final(data) end;
    SHA384 = function(data, key) return hmac.new('sha384',key):final(data) end;
    SHA512 = function(data, key) return hmac.new('sha512',key):final(data) end;
}

M.DIGEST = {
    SHA256 = function(data, hex) return digest.digest('sha256', data, not hex) end;
    SHA384 = function(data, hex) return digest.digest('sha384', data, not hex) end;
    SHA512 = function(data, hex) return digest.digest('sha512', data, not hex) end;
}

return M