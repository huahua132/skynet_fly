#!/usr/bin/env lua

-- This tests encoding and decoding JWTs with each of the supported algorithms.
-- It prints out the valid tokens it creates.

-- You can confirm tokens are valid using Python's implementation, copy and paste
-- the tokens printed into the pyjwt command.
--
-- For HMAC algos: pyjwt --key=sekr1t decode TOKEN
-- For RSA algos:  pyjwt --key="$(cat test/pubkey.pem)" decode TOKEN
--
-- You'll need something like this to install the Python dependencies:
--   pip3 install pyjwt
--   pip3 install cryptography
--
-- The RSA keypair used is the JWK example in RFC 7515, converted to PEM files.

local jwt = require "luajwtjitsi"

local function read_file (filename)
	local fh = assert(io.open(filename, "rb"))
	local data = fh:read(_VERSION <= "Lua 5.2" and "*a" or "a")
	fh:close()
	return data
end

-- Test data.
local claim = {
	iss = "12345678",
	aud = "foobar",
	nbf = os.time(),
	exp = os.time() + 3600,
}
local header = {
	test = "test123"
}

-- Actual tests.
local TESTS = {
	{ algo = "HS256" },
	{ algo = "HS384" },
	{ algo = "HS512" },
	{ algo = "RS256", rsa = true },
	{ algo = "RS384", rsa = true },
	{ algo = "RS512", rsa = true },
}
for _, test in ipairs(TESTS) do
	-- Select key(s).
	local privkey, pubkey
	if test.rsa then
		privkey = read_file("test/privkey.pem")
		pubkey = read_file("test/pubkey.pem")
	else
		privkey = "sekr1t"
		pubkey = "sekr1t"
	end

	-- Create a token.
	local token = assert(jwt.encode(claim, privkey, test.algo, header))
	assert(type(token) == "string")

	-- Make sure it verifies and decodes.
	local decoded = assert(jwt.verify(token, test.algo, pubkey))
	assert(type(decoded) == "table")
	assert(decoded.iss == claim.iss)
	assert(decoded.aud == claim.aud)
	assert(decoded.nbf == claim.nbf)
	assert(decoded.exp == claim.exp)

	-- Should verify with correct accepted issuers.
	assert(jwt.verify(token, test.algo, pubkey, {"12345678"}))
	assert(jwt.verify(token, test.algo, pubkey, {"other", "12345678"}))
	assert(jwt.verify(token, test.algo, pubkey, {"*"}))

	-- Should verify with correct accepted audience.
	assert(jwt.verify(token, test.algo, pubkey, nil, {"foobar"}))
	assert(jwt.verify(token, test.algo, pubkey, nil, {"other", "foobar"}))
	assert(jwt.verify(token, test.algo, pubkey, nil, {"*"}))

	-- Should get an error if signature is corrupted
	local bad_token = token:sub(1, #token - 10) .. 'aaaaaaaaaa'
	local failed, err = jwt.verify(bad_token, test.algo, pubkey)
	assert(failed == nil)
	assert(err == "Invalid signature")

	-- Should get an error if issuer is not accepted.
	local failed, err = jwt.verify(token, test.algo, pubkey, {"other"})
	assert(failed == nil)
	assert(err == "invalid 'iss' claim")

	-- Should get an error if audience is not accepted.
	local failed, err = jwt.verify(token, test.algo, pubkey, nil, {"other"})
	assert(failed == nil)
	assert(err == "invalid 'aud' claim")

	-- Should get an error if token expired.
	local expiredClaim = {table.unpack(claim)}
	expiredClaim.exp = os.time() - 1
	local expiredToken = assert(jwt.encode(expiredClaim, privkey, test.algo, header))
	assert(type(token) == "string")
	local failed, err = jwt.verify(expiredToken, test.algo, pubkey)
	assert(failed == nil)
	assert(err == "Not acceptable by exp")

	-- Should get an error if token is not valid yet.
	local invalidClaim = {table.unpack(claim)}
	invalidClaim.nbf = os.time() + 1000
	local expiredToken = assert(jwt.encode(invalidClaim, privkey, test.algo, header))
	assert(type(token) == "string")
	local failed, err = jwt.verify(expiredToken, test.algo, pubkey)
	assert(failed == nil)
	assert(err == "Not acceptable by nbf")

	-- Output the tokens for checking with external tool, like pyjwt.
	print("Token for " .. test.algo .. ":\n" .. token .. "\n")
end
