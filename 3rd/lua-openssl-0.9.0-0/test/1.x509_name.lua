local lu = require 'luaunit'
local openssl = require 'openssl'
local name = require'openssl'.x509.name
local asn1 = require'openssl'.asn1

TestX509Name = {}
function TestX509Name:setUp()
  self.names = {{C = 'CN'},  {O = 'kkhub.com'},  {CN = 'zhaozg'}}
end

function TestX509Name:tearDown()
end

function TestX509Name:testAll()
  local n1 = name.new(self.names)
  lu.assertEquals(n1:tostring(), n1:oneline())
  local der = n1:i2d()
  local n2 = name.d2i(der)
  assert(n1:cmp(n2) == (n1 == n2))
  n2 = assert(n1:dup())
  assert(n1:cmp(n2) == (n1 == n2))
  lu.assertEquals(n1, n2)
  lu.assertEquals(n1:oneline(), '/C=CN/O=kkhub.com/CN=zhaozg')

  lu.assertIsNumber(n1:hash())
  lu.assertEquals(#n1:digest('SHA1'), 20)

  lu.assertEquals(n2:toprint(), 'C=CN, O=kkhub.com, CN=zhaozg')

  local info = n1:info()
  lu.assertIsTable(info)
  assert(n1:entry_count(), 3)

  lu.assertEquals(n1:get_text('CN'), 'zhaozg')
  lu.assertEquals(n1:get_text('C'), 'CN')
  lu.assertEquals(n1:get_text('OU'), nil)

  lu.assertIsTable(n1:get_entry(0))

  lu.assertIsTable(n1:get_entry(1))
  lu.assertIsTable(n1:get_entry(2))
  lu.assertIsNil(n1:get_entry(3))

  local s2 = asn1.new_string('中文名字', asn1.BMPSTRING)
  local utf_cn = s2:toutf8()
  local s3 = asn1.new_string(utf_cn, asn1.UTF8STRING)
  assert(s3)

  assert(n1:add_entry('OU', utf_cn, true))
  local S, i = n1:get_text('OU')
  lu.assertEquals(i, 3)
  assert(S==utf_cn)

  local t = n1:info()
  for _ = 1, #t do
    v = t[_]
    lu.assertIsTable(v)
    for K,V in pairs(v) do
      assert(type(K)=='string')
      assert(type(V)=='string')
    end
  end

  t = n1:info(true)
  for _ = 1, #t do
    v = t[_]
    for K,V in pairs(v) do
      assert(type(K)=='userdata')
      assert(type(V)=='userdata')
    end
  end

  local k, v = n1:delete_entry(3)
  lu.assertStrContains(tostring(k), 'openssl.asn1_object')
  local _, _, opensslv = openssl.version(true)
  if opensslv > 0x10002000 then
    lu.assertEquals(v:toprint(), [[\UE4B8\UADE6\U9687\UE590\U8DE5\UAD97]])
    lu.assertEquals(v:tostring(), v:toutf8())
  end

  k, v = name.new({{XXXX='SHOULDERROR'}})
  assert(k==nil)
  assert(v:match("can't add to openssl.x509_name with value"))
end

