local lu = require 'luaunit'
local openssl = require 'openssl'
local digest = require'openssl'.digest
local helper = require'helper'
local unpack = unpack or table.unpack

TestDigestCompat = {}
function TestDigestCompat:setUp()
  self.msg = 'abcd'
  self.alg = 'sha1'
end

function TestDigestCompat:tearDown()
end

function TestDigestCompat:testDigest()
  local a, b, c
  a = digest.digest(self.alg, self.msg)
  lu.assertEquals(#a, 40)

  b = digest.digest(self.alg, self.msg, false)
  lu.assertEquals(#b, 40)
  lu.assertEquals(a, b)
  c = digest.digest(self.alg, self.msg, true)
  lu.assertEquals(#c, 20)

  local o = openssl.asn1.new_object(self.alg)
  assert(type(o:nid())=='number')

  c = digest.digest(o:nid(), self.msg, true)
  lu.assertEquals(#c, 20)

  c = digest.digest(o, self.msg, true)
  lu.assertEquals(#c, 20)
end

function TestDigestCompat:testObject()
  local a, b, c, aa, bb
  local obj = digest.new(self.alg)
  assert(obj:update(self.msg))
  a = obj:final()
  obj:reset()
  b = obj:final(self.msg, false)
  assert(a == b)
  assert(#a == 40)

  obj:reset()
  assert(obj:update(self.msg))
  c = obj:final(self.msg, true)
  lu.assertEquals(2 * #c, #a)

  obj:reset()
  obj:update(self.msg)
  aa = obj:final(self.msg)

  obj:reset()
  bb = obj:final(self.msg .. self.msg)
  lu.assertEquals(aa, bb)
end

TestDigestMY = {}
function TestDigestMY:testList()
  local t1, t2, t3, t
  t1 = digest.list(true)
  t2 = digest.list()
  assert(#t1 == #t2)
  t3 = digest.list(false)
  assert(#t1 > #t3)
  local md = digest.get('sha1')
  t = md:info()
  assert(t.size == 20)
  t = md:digest('abcd')
  assert(type(t)=='string')
  assert(#t==20)

  if (not helper.openssl3) --FIXME: digest ctx copy
    and not (helper.libressl and helper._opensslv > 0x3050000f) then
  local ctx1 = md:new()
  t1 = ctx1:info()
  assert(ctx1:update('ab'))
  local dat = ctx1:data()
  local ctx = digest.new('sha1')
  t2 = ctx:info()
  for k, _ in pairs(t1) do if (k ~= 'digest') then assert(t1[k] == t2[k]) end end
  assert(ctx:data(dat))
  assert(t1.size == 20)
  assert(ctx:update('cd'))
  t2 = ctx:final(true)
  assert(t==t2)
  end
end

local function mk_key(args)
  assert(type(args), 'table')

  local k = assert(openssl.pkey.new(unpack(args)))
  return k
end

TestDigestSignVry = {}
function TestDigestSignVry:setUp()
  self.msg = 'abcd'
  self.alg = 'sha1'
  self.prik = mk_key({'rsa',  2048,  3})
  self.pubk = assert(openssl.pkey.get_public(self.prik))
end
function TestDigestSignVry:testSignVry()
  local md = assert(digest.get(self.alg))
  local sctx = digest.signInit(md, self.prik);
  assert(sctx:signUpdate(self.msg))
  assert(sctx:signUpdate(self.msg))
  local sig = sctx:signFinal()
  lu.assertEquals(#sig, 256)
  local vctx = digest.verifyInit(md, self.pubk)
  assert(vctx:verifyUpdate(self.msg))
  assert(vctx:verifyUpdate(self.msg))
  assert(vctx:verifyFinal(sig))
end
function TestDigestSignVry:testSignVry1()
  local md = digest.get(self.alg)
  local sctx = md:signInit(self.prik);
  assert(sctx:signUpdate(self.msg))
  assert(sctx:signUpdate(self.msg))
  local sig = sctx:signFinal()
  lu.assertEquals(#sig, 256)
  local vctx = md:verifyInit(self.pubk)
  assert(vctx:verifyUpdate(self.msg))
  assert(vctx:verifyUpdate(self.msg))
  assert(vctx:verifyFinal(sig))
end

function TestDigestOneShotSignVry_ED25519()
  local pkey = openssl.pkey
  if pkey.ED25519 and not helper.libressl then
    local ctx = assert(pkey.ctx_new('ED25519'))
    local k = assert(ctx:keygen())
    local msg = 'abcd'

    local sctx = assert(digest.signInit(nil, k));
    local sig = assert(sctx:sign(msg))

    local vctx = digest.verifyInit(nil, k)
    assert(vctx:verify(sig, msg))
  end
end

function TestDigestOneShotSignVry_ED448()
  local pkey = openssl.pkey
  if pkey.ED448 and not helper.libressl then
    local ctx = assert(pkey.ctx_new('ED448'))
    local k = assert(ctx:keygen())
    local msg = 'abcd'

    local sctx = assert(digest.signInit(nil, k));
    local sig = assert(sctx:sign(msg))

    local vctx = digest.verifyInit(nil, k)
    assert(vctx:verify(sig, msg))
  end
end

