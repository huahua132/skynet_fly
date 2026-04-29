-- test bn library
local openssl = require "openssl"
local bn = openssl.bn

local lu = require('luaunit')
------------------------------------------------------------------------------
function testOpenSSL_BIGNUM()
  local p, q, m, mx, e, d, t, x, y, message, encoded
  assert(type(bn.version) == 'string')

  p = bn.random(32)
  q = p:totext()
  assert(#q==4 or #q==3)

  p = bn.aprime(100)
  assert(p:bits()==100)
  assert(p:isprime())
  q = bn.aprime(250)
  assert(q:bits()==250)
  assert(q:isprime())
  m = p * q
  mx = (p - 1) * (q - 1)
  e = bn.number "X10001"
  d = bn.invmod(e, mx)
  assert(bn.mulmod(e, d, mx):isone())
  t = bn.number(2)
  x = bn.powmod(t, e, m)
  y = bn.powmod(x, d, m)
  assert(t == y)

  message = "The quick brown fox jumps over the lazy dog"
  encoded = bn.text(message)
	assert(message)
  assert(encoded < m)
  assert(message == bn.totext(encoded))

  x = bn.powmod(encoded, e, m)
	assert(x)

  y = bn.powmod(x, d, m)
	assert(y)
  assert(y == encoded)
  y = bn.totext(y)
  assert(y == message)

  d = bn.number "X816f0d36f0874f9f2a78acf5643acda3b59b9bcda66775b7720f57d8e9015536160e728230ac529a6a3c935774ee0a2d8061ea3b11c63eed69c9f791c1f8f5145cecc722a220d2bc7516b6d05cbaf38d2ab473a3f07b82ec3fd4d04248d914626d2840b1bd337db3a5195e05828c9abf8de8da4702a7faa0e54955c3a01bf121"
  m =
    bn.number "Xbfedeb9c79e1c6e425472a827baa66c1e89572bbfe91e84da94285ffd4c7972e1b9be3da762444516bb37573196e4bef082e5a664790a764dd546e0d167bde1856e9ce6b9dc9801e4713e3c8cb2f12459788a02d2e51ef37121a0f7b086784f0e35e76980403041c3e5e98dfa43ab9e6e85558c5dc00501b2f2a2959a11db21f"
  t = bn.number(2)
  x = bn.powmod(t, e, m)
  y = bn.powmod(x, d, m)
  assert(t == y)

  x = bn.number("X10")
  y = x:tohex()
  assert(y=="10")
  y = x:tostring()
  assert(y=="16")
  y = x:tonumber()
  assert(y==16)
  assert(not x:isodd())
  assert(not x:isneg())
  assert(x:compare(16)==0)
  assert(x:sqr():compare(256)==0)
  assert(x:sqrmod(2):compare(0)==0)
  assert(x:sqrtmod(2):compare(0)==0)
  y = x:neg()
  assert(y:isneg())
  assert(y:abs():compare(16)==0)
  assert(x:add(1):compare(17)==0)

  assert(x:div(4):compare(4)==0)
  assert(x:mod(17):compare(x)==0)
  assert(x:mod(18):compare(16)==0)
  p, q = x:divmod(3)
  assert(p:compare(5)==0)
  assert(q:compare(1)==0)
  assert(x:gcd(4):compare(4)==0)
  assert(x:pow(2):compare(256)==0)
  assert(x:addmod(1, 18):compare(17)==0)
  assert(x:submod(1, 16):compare(15)==0)
  assert(x:sqrmod(256):compare(0)==0)
  assert(not x:iszero())
  assert(x:rmod(256):compare(16)==0)

end
