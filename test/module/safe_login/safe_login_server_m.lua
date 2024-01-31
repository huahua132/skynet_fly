local log = require "log"
local skynet = require "skynet"
local crypt = require "skynet.crypt"

local CMD = {}

local client_handle = nil
local challenge = nil -- 这是一个 8 字节长的随机串，用于后序的握手验证
local client_key = nil -- 这是一个 8 字节的由客户端发送过来，用于交换 secret 的 key 。
local serverkey = nil  -- 生成一个用户交换 secret 的 key 。
local secret = nil     -- 密钥

--建立连接
function CMD.accept(handle)
    log.info("accept:", handle)
    client_handle = handle
    --stop 1 S2C : base64(8bytes random challenge)
    challenge = crypt.randomkey()
    skynet.send(client_handle, 'lua', 'to_client', 1, crypt.base64encode(challenge))
end

local function decode_token(token)
	local user, servername, pass = token:match "(.+)@(.+):(.+)"
    log.info("decode_token:", user, servername, pass)
	return crypt.base64decode(user), crypt.base64decode(servername), crypt.base64decode(pass)
end

function CMD.to_server(stop, ...)
    local args = {...}
    log.info("to_server:", stop, args)
    if stop == 2 then
        -- stop 2 C2S : base64(8bytes handshake client key) 
        client_key = crypt.base64decode(args[1])
        if #client_key ~= 8 then
			error "Invalid client key"
		end
        -- stop 3 Server: Gen a 8bytes handshake server key 生成一个用户交换 secret 的 key 
        serverkey = crypt.randomkey()
        -- stop 4 S2C : base64(DH-Exchange(server key)) 利用 DH 密钥交换算法，发送交换过的 server key 。
        skynet.send(client_handle, 'lua', 'to_client', 4, crypt.base64encode(crypt.dhexchange(serverkey)))
        -- stop 5 Server/Client secret := DH-Secret(client key/server key) 服务器和客户端都可以计算出同一个 8 字节的 secret 。
        secret = crypt.dhsecret(client_key, serverkey)
    elseif stop == 6 then
        local hmac = crypt.hmac64(challenge, secret)

		if hmac ~= crypt.base64decode(args[1]) then
			error "challenge failed"
		end
    elseif stop == 7 then
        local etoken = args[1]

		local token = crypt.desdecode(secret, crypt.base64decode(etoken))
        log.info("token:", token, decode_token(token))
    end
end

function CMD.start()
    return true
end

function CMD.exit()
    return true
end

return CMD