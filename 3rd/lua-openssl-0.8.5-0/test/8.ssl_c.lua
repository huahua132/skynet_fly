local lu = require("luaunit")
local openssl = require("openssl")
local bio, ssl = openssl.bio, openssl.ssl
local sslctx = require("sslctx")
local _, _, opensslv = openssl.version(true)
local host, port, loop, name

local arg = arg

host = arg[1] or "127.0.0.1" -- only ip
port = arg[2] or "8383"
loop = arg[3] and tonumber(arg[3]) or 100
name = arg[4]

local params = sslctx.client

print(string.format("CONNECT to %s:%s", host, port))

local certstore = nil
if opensslv > 0x10002000 then
  certstore = openssl.x509.store:new()
  local cas = require("root_ca")
  for i = 1, #cas do
    local cert = assert(openssl.x509.read(cas[i]))
    assert(certstore:add(cert))
  end
end

local function mk_connection(_host, _port, i)
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
  ctx:set_cert_verify(function(arg)
    -- do some check
    --[[
    for k,v in pairs(arg) do
          print(k,v)
    end
    --]]
    return true -- return false will fail ssh handshake
  end)

  local cli = assert(bio.connect(_host .. ":" .. _port, true))
  if cli then
    local S = ctx:ssl(cli, false)
    if name then
      cli:set("hostname", name)
    end
    if i % 2 == 2 then
      assert(S:handshake())
    else
      assert(S:connect())
    end
    local succ, errs = S:getpeerverification()
    if type(errs) == "table" then
      for i, err in pairs(errs) do
        for j, msg in ipairs(err) do
          print("depth = " .. i, "error = " .. msg)
        end
      end
    end
    local s = "aaa"
    io.write(".")
    io.flush()
    for _ = 1, 100 do
      assert(S:write(s))
      assert(S:read())
    end
    local t = S:current_cipher()
    assert(type(t) == "table")
    assert(S:getfd())
    assert(not S:is_server())
    S:get("side")
    S:shutdown()
    cli:shutdown()
    cli:close()
    collectgarbage()
  end
  openssl.errors()
end

for i = 1, loop do
  mk_connection(host, port, i)
end

print()
print("SSL Client done")
os.exit(0, true)
