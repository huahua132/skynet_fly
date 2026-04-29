local lu = require("luaunit")
local openssl = require("openssl")
local bio, ssl = openssl.bio, openssl.ssl
local sslctx = require("sslctx")
local host, port, loop

local arg = arg

host = arg[1] or "127.0.0.1" -- only ip
port = arg[2] or "8383"
loop = arg[3] and tonumber(arg[3]) or 100

local _, _, opensslv = openssl.version(true)

local params = sslctx.client

local certstore = nil
if opensslv > 0x10002000 then
  certstore = openssl.x509.store:new()
  local cas = require("root_ca")
  for i = 1, #cas do
    local cert = assert(openssl.x509.read(cas[i]))
    assert(certstore:add(cert))
  end
end
local ctx = assert(sslctx.new(params))
if certstore then
  ctx:cert_store(certstore)
end

ctx:verify_mode(ssl.peer, function(_arg)
  --[[
  --do some check
  for k,v in pairs(arg) do
        print(k,v)
  end
  --]]
  return true -- return false will fail ssh handshake
end)

print(string.format("CONNECT to %s:%s with %s", host, port, tostring(ctx)))

local function mk_connection(_host, _port, i)
  local cli = assert(ctx:bio(_host .. ":" .. _port))
  if cli then
    assert(cli:handshake())
    ---[[
    if i % 2 == 2 then
      assert(cli:handshake())
    else
      assert(cli:connect())
    end
    -- ]]
    local s = "aaa"
    io.write(".")
    io.flush()
    for _ = 1, 100 do
      assert(cli:write(s))
      assert(cli:read())
    end
    assert(cli:ssl())
    cli:shutdown()
    cli:free()
  end
  openssl.errors()
end

for i = 1, loop do
  mk_connection(host, port, i)
end
print()
print("SSL bio client done")
collectgarbage()
os.exit(0, true)
