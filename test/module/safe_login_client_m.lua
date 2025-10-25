local log = require "skynet-fly.log"
local skynet = require "skynet"
local container_client = require "skynet-fly.client.container_client"
local crypt = require "skynet.crypt"

container_client:register("safe_login_server_m")

local CMD = {}
local server = nil
local challenge = nil  -- 这是一个 8 字节长的随机串，用于后序的握手验证(服务器发送过来的)
local client_key = nil -- 这是一个 8 字节的由客户端发送过来，用于交换 secret 的 key 。
local server_key = nil -- serverkey，服务端发过来的
local secret = nil     -- 密钥

local token = {
	server = "sample",
	user = "hello",
	pass = "password",
}

local function encode_token(token)
	return string.format("%s@%s:%s",
		crypt.base64encode(token.user),
		crypt.base64encode(token.server),
		crypt.base64encode(token.pass))
end

function CMD.to_client(stop, ...)
    local args = {...}
    log.info("to_client:", stop, args)
    if stop == 1 then
        challenge = crypt.base64decode(args[1])
        client_key = crypt.randomkey()
        server:mod_send("to_server", 2, crypt.base64encode(crypt.dhexchange(client_key)))
    elseif stop == 4 then
        server_key = crypt.base64decode(args[1])
        -- stop 5 Server/Client secret := DH-Secret(client key/server key) 服务器和客户端都可以计算出同一个 8 字节的 secret 。
        secret = crypt.dhsecret(server_key, client_key)

        -- stop 6 C2S : base64(HMAC(challenge, secret)) 回应服务器第一步握手的挑战码，确认握手正常。
        server:mod_send("to_server", 6, crypt.base64encode(crypt.hmac64(challenge, secret)))
        
        -- stop 7 C2S : DES(secret, base64(token)) 使用 DES 算法，以 secret 做 key 加密传输 token 串。
        local etoken = crypt.desencode(secret, encode_token(token))
        server:mod_send("to_server", 7, crypt.base64encode(etoken))
    end
end

function CMD.start()
    skynet.fork(function()
        server = container_client:new("safe_login_server_m")
        server:mod_send("accept", skynet.self())
    end)
    return true
end

function CMD.exit()
    return true
end

return CMD