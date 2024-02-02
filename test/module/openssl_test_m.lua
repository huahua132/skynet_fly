local skynet = require "skynet"
local crypt_util = require "crypt_util"
local httpc = require "httpc"
local log = require "log"
local openssl = require "openssl"
local crypt = require "skynet.crypt"


local dh = openssl.dh
local pkey = openssl.pkey

local assert = assert

local CMD = {}

function CMD.start()
	local clientec = pkey.new('ec', "prime256v1")
	local client_pk = pkey.read(clientec:get_public():export('der'))
	client_pk =client_pk:parse().ec
	clientec = clientec:parse().ec
	log.info("client_key:", clientec:parse(), client_pk:parse())

	local serverec = pkey.new('ec', "prime256v1")--server_key:export('der'))
	serverec = serverec:parse().ec
	
	log.info("server_key:", serverec, serverec:parse())

	local share_secret = clientec:compute_key(serverec)
	local share_secret2 = serverec:compute_key(client_pk)

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

return CMD