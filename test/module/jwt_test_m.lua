local jwt = require "luajwtjitsi"
local log = require "log"

local CMD = {}

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

local pem_key =
[[
-----BEGIN PRIVATE KEY-----
MIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQDujoQuDvHO5wZ3
rZTiLw0TNeShJw389wd4POfqp8GjbQcjdIHpBH5W77sBiif06JV/3pWMNdFfz630
PBojR2raEW7h6Bq3mF3JAGamUZwmjibW4uA8i+Jd9vDag+fWCfEv+Kvf0NjtmT62
njC+1HdsvqvXP8w9rD3Nwl2WpYIRw34f7wnF6KZqoKhIbUIxSNzIiu/FTANIV8BG
WGytHV/+skGfO3L2L+BSKDuymPvgh1qgjg+bPMCl8sBpS99V8AFqGmu83fdIO+Jj
B1WpHkKqMz4zcTVue5KdSxH/EVxBP6UCXHn3sYF4owy0m8l2m+qRSFMEhZhk7AEF
9Vi0UWHpAgMBAAECggEAAsEkgv+iCI9o5v5I0Dsx/ZimtQPukdgsWlXGROTsaHSF
rd1EF+FmsAxKAOnVUkZ28AO/fyjPWaduXzDZ5Ps+jQd37iXUpbbmz3ZVS2BUbWGJ
80RgyZbBCjmRkYRYGV9Luuta2LDggFgbEEUGeH2bQbBTojENrM7pCX2ZLi8eL8je
yxsxFymvy7K6VlQXvWMigjEybGATTdI080HqccB3B0ZMyhiiuJfxRePbyEOWkmVP
QzWYDDsjfYdTrIv2Yfttedq2mnEBUbHdPLTg65TrcuEwB1IcLJFsbI9dKzDOipu2
00C93gxW1aN0Wi8/JuYc8xrnbz6i+qYXpap4DZRI8QKBgQDusoXWa7os6Bf6uhEk
USsSYtdm3oGRJ1vSzTHHqGwESHywy9xyx1E391TdFMHZQHgkIwQhS6Q+1h1wTiZO
tilwv0FfDffu7pzSfzGKdn7WfKL/7W6Bv7+1LY9NOXkk0YkjBoBKoDwuXdam8dmq
jF7P6bMQCJhTeojU1/6MxI13DQKBgQD/2WIstTZqJ+7JIg20HRoawT1nNzw5haBG
rUuShiYyMDnkyNYlUa8ZNj6Hm0xwAXuiYQZXDSDXazmsKu2r/0pAlkrOhxxvibH7
WavG4r2FeUX+BFUhEFmdQsMoexRFjZcwUYykg7TSErnwWJ4x6FAA92A093TaiwJ2
WZ1KD0IfTQKBgFjuWGDv1/hdLHn0kuhl+VcrTjd8VOegs1xRqOdLP5tE6nfwLBzz
V7YzRwHrduGbXGeSSDqjdPkYSvWJmEohIkVobFGe4a26ZuEiFHIS/eSpoQ0bB939
c85rwAU0kYb/LknHZUrociOQQKYIW2FoVPa/ikBCA4auk4ZBRwxpOo+NAoGBALYb
zT11Xt4Avn57trVVYZdZpJMrRbrL2mF0SC5rPhTLLuoh6gt2MOQJMEjlyWqQI6hY
12Ju/clXkR1zEOk0NW3zjBulICBkKkN2eEaAbdXrlF5SRyXZtW+ybacKtEstlUfX
Q/x1oudEXQUujquHaCrH6brJyGsmNwJ2lvZ4FeChAoGBAK+nll0/ulyOZveQWXc9
/5ML5ZAZXWaz2riuUfMITR2rRzw+Z/asgPg5MK1/AywHgvyCxAU/RSs+tihzPz5G
cG2UHoW6GVnP8y73pwY8p78Q7n308g74W5ZeFko8RRxhPttkJBd5szrlHQsyA8LI
fWxp0aMVVx6pHWHcwZtPAuOq
-----END PRIVATE KEY-----
]]

local pem_cert = [[
-----BEGIN CERTIFICATE-----
MIIDojCCAoqgAwIBAgIUE0iPAg8GJSGTDZACCPNUUIENaPswDQYJKoZIhvcNAQEL
BQAwMDEWMBQGA1UEAwwNcnlrb3Zhbm92LmNvbTEWMBQGA1UECgwNUmVhbHRpbWVM
b2dpYzAeFw0yMzA2MTgxMjMyNThaFw0zMzA2MTUxMjMyNThaMDAxFjAUBgNVBAMM
DXJ5a292YW5vdi5jb20xFjAUBgNVBAoMDVJlYWx0aW1lTG9naWMwggEiMA0GCSqG
SIb3DQEBAQUAA4IBDwAwggEKAoIBAQDujoQuDvHO5wZ3rZTiLw0TNeShJw389wd4
POfqp8GjbQcjdIHpBH5W77sBiif06JV/3pWMNdFfz630PBojR2raEW7h6Bq3mF3J
AGamUZwmjibW4uA8i+Jd9vDag+fWCfEv+Kvf0NjtmT62njC+1HdsvqvXP8w9rD3N
wl2WpYIRw34f7wnF6KZqoKhIbUIxSNzIiu/FTANIV8BGWGytHV/+skGfO3L2L+BS
KDuymPvgh1qgjg+bPMCl8sBpS99V8AFqGmu83fdIO+JjB1WpHkKqMz4zcTVue5Kd
SxH/EVxBP6UCXHn3sYF4owy0m8l2m+qRSFMEhZhk7AEF9Vi0UWHpAgMBAAGjgbMw
gbAwHQYDVR0OBBYEFNvyWnOsnBAxlqa1cKFDIMEI6u4iMB8GA1UdIwQYMBaAFNvy
WnOsnBAxlqa1cKFDIMEI6u4iMA8GA1UdEwEB/wQFMAMBAf8wMQYDVR0RBCowKIYX
dXJuOnJlYWx0aW1lbG9naWM6b3BjdWGCDXJ5a292YW5vdi5jb20wCwYDVR0PBAQD
AgP4MB0GA1UdJQQWMBQGCCsGAQUFBwMBBggrBgEFBQcDAjANBgkqhkiG9w0BAQsF
AAOCAQEA4vK6qt1fUWgksi55HYeqXrT35fWOcHTv5qOhnWOZ3q5lX/j2bfHej4FH
ZRoHwyObIIRXulhK2DUrQqlgUnHD78vHiHCGjX8iGX/sSZbHihuZQWMo7I24MNA3
V9IMMQ3Nh7izMksvtMrC7TQqakjPC96D+0mFUJJOnL8Ca0vJYWA8KG7XuwbMPeJm
74Ykof89P2SL2os3enxrWlvoJwGiJGEXnjSBFhn5bul7ZvHK5YNvZHcsGOfXZIll
9I36RChYvNJ3YbHJBcxxsr8RqB3midXMYP885hUeWySB+OopJVYhlAAn5Odd6/gK
8upzr+Rb8XYpFQudXBjQZ6qKQd7Osw==
-----END CERTIFICATE-----
]]

function CMD.start()
	for _, test in ipairs(TESTS) do
		-- Select key(s).
		local privkey, pubkey
		if test.rsa then
			privkey = pem_key
			pubkey = pem_cert
		else
			privkey = "sekr1t"
			pubkey = "sekr1t"
		end
		
		log.info("test :",test.algo)
		-- Create a token.
		local token = assert(jwt.encode(claim, privkey, test.algo, header))
		assert(type(token) == "string")
		log.error("token ",token)
		-- Make sure it verifies and decodes.
		local decoded = assert(jwt.verify(token, test.algo, pubkey))
		log.error("decoded ",decoded)
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
	return true
end

function CMD.exit()

end

return CMD