local lu = require 'luaunit'
local openssl = require 'openssl'
local ssl = openssl.ssl
local sslctx = require 'sslctx'
local _, _, opensslv = openssl.version(true)
local host, port, loop

local arg = assert(arg)
host = arg[1] or "127.0.0.1"; -- only ip
port = arg[2] or "8383";
loop = arg[3] and tonumber(arg[3]) or 100

local params = sslctx.server

--
local certstore
if opensslv > 0x10002000 then
  certstore = openssl.x509.store:new()
  local cas = require 'root_ca'
  for i = 1, #cas do
    local cert = assert(openssl.x509.read(cas[i]))
    assert(certstore:add(cert))
  end
end

local ctx = assert(sslctx.new(params))
if certstore then
  ctx:cert_store(certstore)
end
assert(ctx:cert_store())
ctx:timeout(60)
assert(ctx:timeout()==60)
ctx:quiet_shutdown(1)
assert(ctx:quiet_shutdown()==1)

ctx:verify_mode(ssl.peer, function(_arg)
  --[[
  --do some check
  for k,v in pairs(arg) do
        print(k,v)
  end
  --]]
  return true -- return false will fail ssh handshake
end)

print(string.format('Listen at %s:%s with %s', host, port, tostring(ctx)))
ctx:set_cert_verify({
  always_continue = true,
  verify_depth = 9
})

local function ssl_mode()
  local srv = assert(ctx:bio(host .. ':' .. port, true))
  local i = 0
  if srv then
    print('listen BIO:', srv)
    assert(srv:accept(true), 'Error in accept BIO') -- make real listen
    print('accpeting...')
    io.flush()
    while i < loop do
      local cli = assert(srv:accept(), 'Error in ssl connection') -- bio tcp
      io.write('+')
      io.flush()
      assert(cli:handshake(), 'handshake fail')
      repeat
        local d = cli:read()
        if d then
          assert(#d == cli:write(d))
        end
      until not d
      assert(cli:ssl())
      cli:shutdown()
      cli:close(true)
      collectgarbage()
      i = i + 1
    end
    srv:close()
  end
end

ssl_mode()
print(openssl.errors())
