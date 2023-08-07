local lu = require 'luaunit'

local openssl = require 'openssl'
local cms, csr = openssl.cms, openssl.x509.req
local helper = require 'helper'
if not cms then
  print('Skip cms test')
  return
end

TestCMS = {}

-- need OpenSSL build with zlib support

function TestCMS:testCompress()
  local msg = openssl.random(1000)
  local cs = cms.compress(msg)
  if cs then
    local ret = assert(cms.uncompress(cs))
    lu.assertEquals(msg, ret)
  end

  local cs = cms.compress(msg, 'zlib')
  if cs then
    local ret = assert(cms.uncompress(cs))
    lu.assertEquals(msg, ret)
  end
end

function TestCMS:setUp()
  self.alg = 'sha1'
  self.cadn = {{commonName = 'CA'},  {C = 'CN'}}
  self.alicedn = {{commonName = 'Alice'},  {C = 'CN'}}
  self.bobdn = {{commonName = 'Bob'},  {C = 'CN'}}

  local ca = helper.get_ca()

  self.ca = ca

  local req, pkey = helper.new_req(self.alicedn)
  local cert = ca:sign(req)
  self.alice = {key = pkey,  cert = cert}

  cert, pkey = assert(helper.sign(self.bobdn))
  self.bob = {key = pkey,  cert = cert}

  self.msg = openssl.hex(openssl.random(128))
  self.digest = 'sha1WithRSAEncryption'
  self.castore = assert(ca:get_store())

  local c = cms.new()
  assert(c)
end

function TestCMS:testEncrypt()
  local opts = {
    self.alice.cert,
    key = "1234567890abcdef",
    keyid = "aes-128-cbc",
    password = 'secret'
  }
  local msg = assert(cms.encrypt(self.msg, opts))
  local smime = assert(cms.export(msg))
  local ss = assert(cms.read(smime, 'smime'))
  local raw = assert(cms.decrypt(ss, self.alice.key, self.alice.cert, nil, 0, opts))
  lu.assertEquals(raw, self.msg)
end

function TestCMS:testSign()
  local c1 = assert(cms.sign(
    self.bob.cert, self.bob.key, self.msg, {}))
  assert(cms.export(c1))
  local msg = assert(cms.verify(c1, {self.bob.cert}, self.castore))
  lu.assertEquals(msg, self.msg)
  msg = assert(cms.verify(c1, {}, self.castore))
  lu.assertEquals(msg, self.msg)
  assert(c1:signers()[1]==self.bob.cert)
end

--[[
--FIXME: enable
function TestCMS:testSignReceipt()
  local c1 = assert(cms.sign(
    self.bob.cert, self.bob.key, self.msg, {}))

  print(c1:sign_receipt(
    self.alice.cert,
    self.alice.key,
    {self.ca.cert},
    0))
  assert(rc)
  if rc then
    assert(rc:verify_receipt(c1, {self.bob.cert}, self.castore, 0))
  end
end
--]]

function TestCMS:testEncryptedData()
  local key = openssl.random(16)
  local c1 = assert(cms.EncryptedData_encrypt(self.msg, key))
  assert(cms.export(c1))
  local msg = assert(cms.EncryptedData_decrypt(c1, key))
  lu.assertEquals(msg, self.msg)
end

function TestCMS:testDigest()
  local key = openssl.random(24)
  assert(key)
  local c1 = assert(cms.digest_create(self.msg))
  local smime = assert(cms.export(c1))
  assert(smime)
  local msg = assert(cms.digest_verify(c1))
  lu.assertEquals(msg, self.msg)

  c1 = assert(cms.digest(self.msg, "sha1"))
  smime = assert(cms.export(c1))
  assert(smime)
  msg = assert(c1:verify())
  lu.assertEquals(msg, self.msg)
end

function TestCMS:testData()
  local c = cms.data("data")
  assert(c)
  assert(c:detached()==false)
  assert(c:type())
  assert(c:data()=='data')
  assert(c:content()=='data')

  local d = assert(c:export("data", 0, "der"))
  assert(cms.read(d, 'auto'))
  d = cms.read(d, 'der')
  assert(d)
  d = assert(c:export("data", 0, "pem"))
  d = cms.read(d, 'pem')
  assert(d)
  d = assert(c:export("data", 0, "smime"))
  d = cms.read(d, 'smime')
  assert(d)

  assert(c:detached(true))
  assert(c:detached() == true)
  d = assert(c:export("data", 0, "der"))
  assert(d)

  c = assert(cms.data("data", cms.stream + cms.partial))
  assert(c:final('aaaa'))
  assert(c:data()=='aaaa')
end

