local skynet = require "skynet"
local crypt_util = require "skynet-fly.utils.crypt_util"
local httpc = require "http.httpc"
local log = require "skynet-fly.log"
local openssl = require "openssl"
local crypt = require "skynet.crypt"


local dh = openssl.dh
local pkey = openssl.pkey

local assert = assert

local client_kkk = [[
-----BEGIN PUBLIC KEY-----
MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEvN9auyL/Ovr0Rvdwt3ZoRUhmkHV2
641RQXMrOPj/DdM4Dvw2eX7wq4hkRQEjWiU3CrXPoiyoUgFWoyEVHTpmvw==
-----END PUBLIC KEY-----
]]

local CMD = {}

function CMD.start()
	-- local clientec = pkey.new('ec', "prime256v1")
	-- log.info("public key:", clientec:get_public():export('der'):len())
	local clientec = pkey.read(client_kkk, false, 'pem', 'ec')
	clientec =clientec:parse().ec
	
	log.info("client_key:", clientec:parse())

	local serverec = pkey.new('ec', "prime256v1")--server_key:export('der'))
	serverec = serverec:parse().ec
	
	log.info("server_key:", serverec, serverec:parse())

	local share_secret = clientec:compute_key(serverec)
	local share_secret2 = serverec:compute_key(clientec)

	log.info("share_secret1 ", share_secret:len())
	log.info("share_secret2 ", share_secret2:len())

	log.info("share_secret1:", crypt.base64encode(share_secret))
	log.info("share_secret2:", crypt.base64encode(share_secret2))

	local data = "dasadddddd"
	
	local key = crypt_util.HMAC.SHA256(data,"key")
	log.error(key)


	-- local code, body = httpc.get("https://www.baidu.com", '/')
	-- log.error("https ",code, body)
	return true
end

function CMD.exit()
	return true
end

-- -----BEGIN PUBLIC KEY-----
-- MFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEGPgQahbbzM0wkQjT/NLh8tJBM7Ni
-- sC+/1mMTSuE7v31iSKPRLCRLI35AQ6PAZa/ZFD0J9xlPi6EJG8pUK5PS4Q==
-- -----END PUBLIC KEY-----
-- -----BEGIN PUBLIC KEY-----
-- BImIGDm9WZ6OMFOVGXffWfeDn1+P4uitjPp3kfSCk6ihx1TlHIaSipDInRdUsPOn
-- tZTFehJZqPkvp0+sy1Mkalk=
-- -----END PUBLIC KEY-----

return CMD