local openssl = require("openssl")

-- prepare a SSL_CTX object
local ctx = assert(openssl.ssl.ctx_new("TLSv1_2_client"))

-- make a TCP connection, and do connect first
local cli = assert(openssl.bio.connect("echo.websocket.org:443", true))

-- make a SSL connection over TCP
local ssl = ctx:ssl(cli)
-- set SNI name
ssl:set("hostname", "echo.websocket.org")

-- do SSL handshake
assert(ssl:connect())

-- send a HTTP request over SSL connection
assert(ssl:write("GET / HTTP/1.1\r\nHost: echo.websocket.org\r\nConnection: close\r\n\r\n"))

-- read response
print(ssl:read(4096))

-- shutdown SSL connection and close TCP connection
ssl:shutdown()
cli:close()
