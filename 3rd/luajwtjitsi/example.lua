#!/usr/bin/env lua

local function t2s(o)
        if type(o) == 'table' then
                local s = '{ '
                for k,v in pairs(o) do
                        if type(k) ~= 'number' then k = '"'..k..'"' end
                        s = s .. '['..k..'] = ' .. t2s(v) .. ','
                end

                return s .. '} '
        else
                return tostring(o)
        end
end

-- 
local jwt = require "luajwtjitsi"

local key = "example_key"

local claim = {
	iss = "12345678",
	nbf = os.time(),
	exp = os.time() + 3600,
}

local header = {
        test = "test123"
}

local alg = "HS256" -- default alg
local token, err = jwt.encode(claim, key, alg, header)

print("Token:", token)

local validate = true -- validate exp and nbf (default: true)
local decoded, err = jwt.verify(token, alg, key)

print("Claim:", t2s(decoded) )
