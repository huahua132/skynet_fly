local lu = require 'luaunit'

local openssl = require 'openssl'
local kdf = require'openssl'.kdf

TestKDF = {}

function TestKDF:testDerive()
  if kdf.iterator then return end
  local pwd = "1234567890"
  local salt = "0987654321"
  local md = 'sha256'
  local iter = 4096
  local keylen = 32

  local key = assert(kdf.derive(pwd, salt, md, iter, keylen))
  assert(key)
  assert(#key == 32)
end

function TestKDF:testBasic()
  if not kdf.iterator then return end
  kdf.iterator(function(k)
    assert(k:name())
    assert(k)
    assert(k:provider())
    assert(k:is_a(k:name()))
    --print(k:description())

    local t = k:settable_ctx_params()
    assert(#t>0)
    t = k:gettable_ctx_params()
    assert(#t>0)
    assert(k:get_params(t))
  end)
end

function TestKDF:testPBKDF2()
  if not kdf.fetch then return end

  local pwd = "1234567890";
  local salt = "0987654321" -- getSalt(pwd)
  local pbkdf2 = kdf.fetch('PBKDF2')
  local t = assert(pbkdf2:settable_ctx_params())
  local key = assert(pbkdf2:derive({
    {
      name = "pass",
      data = pwd,
    },
    {
      name = "salt",
      data = salt,
    },
    {
      name = "digest",
      data = "SHA2-256",
    },
    {
      name = "mac",
      data = "HMAC",
    },
    {
      name = "pkcs5",
      data = 1, -- 0 to enable
    },
    {
      name = "iter",
      data = 128,
    },
  }))
  assert(openssl.hex(key)=='4f3d3828fff90151dd81cef869a0175b')
end

function TestKDF:testPBKDF2CTX()
  if not kdf.fetch then return end

  local pwd = "1234567890";
  local salt = "0987654321" -- getSalt(pwd)
  local pbkdf2 = kdf.fetch('PBKDF2')
  local ctx = assert(pbkdf2:new())

  local t = ctx:settable_params()
  assert(#t>0)
  local key = assert(ctx:derive({
    {
      name = "pass",
      data = pwd,
    },
    {
      name = "salt",
      data = salt,
    },
    {
      name = "digest",
      data = "SHA2-256",
    },
    {
      name = "mac",
      data = "HMAC",
    },
    {
      name = "pkcs5",
      data = 1, -- 0 to enable
    },
    {
      name = "iter",
      data = 128,
    },
  }))
  assert(openssl.hex(key)=='4f3d3828fff90151dd81cef869a0175b')
end
