local lu = require 'luaunit'
local openssl = require 'openssl'
local algor = require'openssl'.x509.algor

TestX509Algor = {}

function TestX509Algor:testAll()
  local alg1 = algor.new()
  assert(alg1:dup() == nil)
  local alg2 = algor.new()
  if alg1.equals then
    assert(alg1:equals(alg2))
    assert(alg1==alg2)
  end

  alg1:md('sha1')
  alg2:md('sha256')

  assert(alg1~=alg2)

  local o1 = openssl.asn1.new_object('C')
  alg1:set(o1)
  local a, b = alg1:get()
  assert(tostring(a):match('openssl.asn1_object:'))
  assert(b==nil)

  local s = openssl.asn1.new_string('CN',  openssl.asn1.UTF8STRING)
  alg1:set(o1, s)

  a, b = alg1:get()
  assert(tostring(a):match('openssl.asn1_object'))
  assert(o1==a)
  assert(b==s)

  local b = alg2:get()
  assert(a~=b)
  alg2 = assert(alg1:dup())
  assert(alg2==alg1)
end

