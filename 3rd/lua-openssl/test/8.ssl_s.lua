local openssl = require("openssl")
local bio, ssl = openssl.bio, openssl.ssl
local sslctx = require("sslctx")
local _, _, opensslv = openssl.version(true)
local host, port, loop

local arg = assert(arg)
host = arg[1] or "127.0.0.1" -- only ip
port = arg[2] or "8383"
loop = arg[3] and tonumber(arg[3]) or 100

local params = sslctx.server
local params01 = sslctx.server01
local params02 = sslctx.server02

local certstore
if opensslv > 0x10002000 then
  certstore = openssl.x509.store:new()
  local cas = require("root_ca")
  for i = 1, #cas do
    local cert = assert(openssl.x509.read(cas[i]))
    assert(certstore:add(cert))
  end
end

local function ssl_mode()
  local ctx = assert(sslctx.new(params))

  assert(ctx:verify_mode())
  assert(ctx:verify_depth(9) == 9)

  local ctx01 = assert(sslctx.new(params01))
  local ctx02 = assert(sslctx.new(params02))

  ctx:set_servername_callback({
    ["servera.br"] = ctx01,
    ["serveraa.br"] = ctx02,
  })

  if certstore then
    ctx:cert_store(certstore)
  end
  -- ctx:set_cert_verify({always_continue=true,verify_depth=4})
  ctx:set_cert_verify(function(arg)
    -- do some check
    --[[
    for k,v in pairs(arg) do
          print(k,v)
    end
     --]]
    return true -- return false will fail ssh handshake
  end)

  print(string.format("Listen at %s:%s SSL", host, port))
  local srv = assert(bio.accept(host .. ":" .. port))
  local i = 0
  if srv then
    -- make real listen
    if srv:accept(true) then
      print("accpeting...")
      io.flush()
      while i < loop do
        local cli = assert(srv:accept()) -- bio tcp
        io.write('+')
        io.flush()
        local s = ctx:ssl(cli, true)
        if i % 2 == 0 then
          assert(s:handshake())
        else
          assert(s:accept())
        end
        repeat
          local d = s:read()
          if d then
            assert(#d == s:write(d))
          end
        until not d
        assert(type(tostring(s)) == "string")
        s:shutdown()
        cli:close()
        cli = nil
        assert(cli == nil)
        collectgarbage()
        i = i + 1
      end
    end
    srv:shutdown()
    srv:close()
  end
end

ssl_mode()
print(openssl.errors())
print("SSL Server done")

os.exit(0, true)
