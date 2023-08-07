local lu = require 'luaunit'
local openssl = require 'openssl'
local cipher = require'openssl'.cipher
local helper = require'helper'

TestCipherCompat = {}

function TestCipherCompat:setUp()
  self.msg = 'abcdabcdabcdabcdabcdabcd'
  self.msg1 = 'abcd'
  self.alg = 'aes-128-cbc'
  self.key = string.char(01, 02, 03, 04, 05, 06, 07, 08, 09, 0x0a, 0x0b, 0x0c,
                         0x0d, 0x0e, 0x0f)
  self.key = self.key .. string.reverse(self.key)
  self.iv = string.rep(string.char(00), 32)

  lu.assertEquals('nil', type(getmetatable(cipher)))
end

function TestCipherCompat:tearDown()
end

function TestCipherCompat:testCipher()
  local a, b, c, d

  a = cipher.cipher(self.alg, true, self.msg, self.key, self.iv)
  assert(#a > #self.msg)
  b = cipher.cipher(self.alg, false, a, self.key, self.iv)
  lu.assertEquals(b, self.msg)

  c = cipher.encrypt(self.alg, self.msg, self.key, self.iv)
  lu.assertEquals(c, a)
  d = cipher.decrypt(self.alg, c, self.key, self.iv)
  lu.assertEquals(d, self.msg)

  local o = openssl.asn1.new_object(self.alg)
  assert(type(o:nid())=='number')

  c = cipher.encrypt(o, self.msg, self.key, self.iv)
  lu.assertEquals(c, a)
  d = cipher.decrypt(o:nid(), c, self.key, self.iv)
  lu.assertEquals(d, self.msg)
end

function TestCipherCompat:testObject()
  local a, b, aa, bb
  local obj, obj1

  obj = cipher.new(self.alg, true, self.key, self.iv)
  obj:padding(true)
  a = assert(obj:update(self.msg))
  a = a .. obj:final()

  local info = obj:info()
  --
  assert(info.block_size)
  assert(info.key_length)
  assert(info.iv_length)
  assert(info.flags)
  assert(info.mode)

  if helper.openss3 then
  assert(obj:ctrl(openssl.cipher.EVP_CTRL_INIT))
  end

  obj:init(self.key, self.iv, true)
  b = assert(obj:update(self.msg))
  b = b .. obj:final()
  assert(a==b)

  obj1 = cipher.new(self.alg, false, self.key, self.iv)
  b = assert(obj1:update(a))
  b = b .. assert(obj1:final())
  lu.assertEquals(b, self.msg)
  assert(#a > #self.msg)

  obj = cipher.encrypt_new(self.alg, self.key, self.iv)
  aa = assert(obj:update(self.msg))
  aa = aa .. assert(obj:final())

  obj1 = cipher.decrypt_new(self.alg, self.key, self.iv)
  bb = assert(obj1:update(aa))
  local dd = assert(obj1:final())
  bb = bb .. dd
  lu.assertEquals(self.msg, bb)
  assert(#self.msg < #aa)
end

TestCipherMY = {}

function TestCipherMY:setUp()
  self.msg = 'abcdabcdabcdabcdabcdabcd'
  self.msg1 = 'abcd'
  self.alg = 'aes-128-cbc'
  self.key = string.char(01, 02, 03, 04, 05, 06, 07, 08, 09, 0x0a, 0x0b, 0x0c,
                         0x0d, 0x0e, 0x0f)
  self.key = self.key .. string.reverse(self.key)
  self.iv = string.rep(string.char(00), 32)
end

function TestCipherMY:testList()

  local t1, t2, t3
  t1 = cipher.list(true)
  t2 = cipher.list()
  assert(#t1 == #t2)
  t3 = cipher.list(false)
  assert(#t1 > #t3)

  local C = cipher.get('aes-128-cbc')

  local a, b, aa, bb
  local obj, obj1

  obj = C:new(true, self.key, self.iv)
  a = assert(obj:update(self.msg))
  a = a .. obj:final()

  obj1 = C:new(false, self.key, self.iv)
  b = assert(obj1:update(a))
  b = b .. assert(obj1:final())
  lu.assertEquals(b, self.msg)
  assert(#a >= #self.msg)

  obj = C:encrypt_new(self.key, self.iv)
  aa = assert(obj:update(self.msg))
  aa = aa .. assert(obj:final())

  obj1 = C:decrypt_new(self.key, self.iv)
  bb = assert(obj1:update(aa))
  bb = bb .. assert(obj1:final())
  lu.assertEquals(self.msg, bb)
  assert(#self.msg <= #aa)

  local r = openssl.random(16)
  local k, i = C:BytesToKey(r)

  local k1, i1 = C:BytesToKey(r)
  lu.assertEquals(k, k1)
  lu.assertEquals(i, i1)
  local t = obj:info()
  lu.assertEquals(#k, t.key_length)
  lu.assertEquals(#i, t.iv_length)
end

function TestCipherMY:testAesCTR()

  local C = cipher.get('aes-128-ctr')
  assert(type(C:info())=='table')

  local a, b, aa, bb, cc
  local obj, obj1

  obj = C:new(true, self.key, self.iv)
  a = assert(obj:update(self.msg))
  a = a .. obj:final()

  assert(obj:init(self.key, self.iv, true))
  b = assert(obj:update(self.msg))
  b = b .. obj:final()
  assert(a==b)

  obj1 = C:new(false, self.key, self.iv)
  b = assert(obj1:update(a))
  b = b .. assert(obj1:final())
  lu.assertEquals(b, self.msg)
  assert(#a >= #self.msg)

  assert(obj1:init(self.key, self.iv, false))
  b = assert(obj1:update(a))
  b = b .. assert(obj1:final())
  lu.assertEquals(b, self.msg)
  assert(#a >= #self.msg)

  obj = C:encrypt_new(self.key, self.iv)
  aa = assert(obj:update(self.msg))
  aa = aa .. assert(obj:final())

  assert(obj:init(self.key, self.iv))
  bb = assert(obj:update(self.msg))
  bb = bb .. assert(obj:final())
  assert(aa==bb)

  obj1 = C:decrypt_new(self.key, self.iv)
  bb = assert(obj1:update(aa))
  bb = bb .. assert(obj1:final())
  lu.assertEquals(self.msg, bb)
  assert(#self.msg <= #aa)

  assert(obj1:init(self.key, self.iv))
  bb = assert(obj1:update(aa))
  bb = bb .. assert(obj1:final())
  lu.assertEquals(self.msg, bb)
  assert(#self.msg <= #aa)
end

