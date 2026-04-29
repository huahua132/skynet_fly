local lu = require 'luaunit'

local openssl = require 'openssl'
local hmac = require'openssl'.hmac

TestHMACCompat = {}
function TestHMACCompat:setUp()
  self.msg = 'abcd'
  self.alg = 'sha1'
  self.key = 'abcdefg'
end

function TestHMACCompat:tearDown()
end

function TestHMACCompat:testDigest()
  local a, b, c
  a = hmac.hmac(self.alg, self.msg, self.key, true)
  lu.assertEquals(#a, 20)

  b = hmac.hmac(self.alg, self.msg, self.key, false)
  lu.assertEquals(#b, 40)
  lu.assertEquals(openssl.hex(a):lower(), b)

  a = assert(hmac.new(self.alg, self.key))
  assert(a:size()>0)
  a:update(self.msg)
  c = a:final()
  lu.assertEquals(c, b)

  a = assert(hmac.new(self.alg, self.key))
  c = a:final(self.msg)
  lu.assertEquals(c, b)

  c = a:final(self.msg, true)
  assert(c, openssl.hex(b))
end
