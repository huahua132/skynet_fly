local lu = require 'luaunit'

local helper = require'helper'
local openssl = require 'openssl'
local crl, csr = openssl.x509.crl, openssl.x509.req

TestCRL = {}
function TestCRL:setUp()
  self.alg = 'sha1'

  self.dn = openssl.x509.name.new({{commonName = 'DEMO'},  {C = 'CN'}})

  self.digest = 'sha1WithRSAEncryption'
  self.fake_subject = openssl.x509.name.new({{commonName = 'Fake'},  {C = 'CN'}})
end

function TestCRL:testReason()
  local reasons = crl.reason()
  assert(#reasons>=10)
end

function TestCRL:testNew()
  local ca = helper.get_ca()

  local pkey = assert(openssl.pkey.new())
  local fake = assert(csr.new(self.fake_subject, pkey))
  fake = assert(fake:to_x509(pkey, 3650)) -- self sign

  local other = crl.new()
  assert(other:issuer(ca.cacert))
  assert(other:version(0))
  assert(other:lastUpdate(os.time()))
  assert(other:nextUpdate(os.time() + 24*3600))
  local ret, err = other:sign(ca.pkey, fake)
  assert(not ret)
  lu.assertStrMatches("private key not match with cacert", err)

  local list = assert(crl.new({
    {sn = 1,  time = os.time()},  {sn = 2,  time = os.time()},
    {sn = 3,  time = os.time()},  {sn = 4,  time = os.time()}
  }, ca.cacert, ca.pkey))
  assert(#list == 4)
  -- print_r(list:parse())
  other = crl.new()
  assert(other:issuer(ca.cacert:issuer()))
  issuer = other:issuer()
  assert(other:issuer(ca.cacert))
  assert(issuer:cmp(other:issuer()))
  assert(other:version(0))
  assert(other:lastUpdate(os.time()))
  assert(other:nextUpdate(os.time() + 24*3600))

  assert(other:add('21234', os.time()))
  assert(other:add('31234', os.time()))
  assert(other:add('41234', os.time()))
  assert(other:add('11234', os.time()))

  assert(other:sign(ca.pkey, ca.cacert))
  assert(other:verify(ca.cacert))
  local pem = other:export()

  assert(other:updateTime(3600))
  assert(other:updateTime(os.time(), 3600))

  assert(other:extensions({
    openssl.x509.extension.new_extension(
      {object = 'basicConstraints',  value = 'CA:FALSE'}
    )
  }))

  local exts = other:extensions()
  assert(#exts==1)
  assert(tostring(exts[1]):match("openssl.x509_extension"))

  assert(other:add('21234', os.time()))
  assert(other:sort())
  assert(other:sign(ca.pkey, ca.cacert:issuer()))
  assert(other:verify(ca.cacert))
  assert(other:verify(ca.pkey))

  assert(other:export())
  local info = other:parse()

  assert(type(info.revoked)=='table')
  assert(type(info.extensions)=='table')
  local t = other:get(0, true)
  lu.assertIsTable(t)
  assert(type(other:digest())=='string')
  local r = other:get(0)
  info = r:info()
  assert(type(info)=='table')
  assert(info.code)
  assert(info.reason)
  assert(info.revocationDate)
  assert(info.serialNumber)
  assert(info.extensions)

  local code, reason = r:reason()
  assert(type(code)=='number')
  assert(type(reason)=='string')
  assert(r:revocationDate())
  assert(r:serialNumber())
  assert(r:extensions())

  if other.diff then
    local crx = crl.read(pem)
    local diff = other:diff(crx, ca.pkey)
    if diff then
      diff = diff:get('21234')
      assert(type(diff)=='table')

      assert(#diff==1)
    end
  end
end

function TestCRL:testRead()
  local dat = [[
-----BEGIN X509 CRL-----
MIIBNDCBnjANBgkqhkiG9w0BAQIFADBFMSEwHwYDVQQKExhFdXJvcGVhbiBJQ0Ut
VEVMIFByb2plY3QxIDAeBgNVBAsTF0NlcnRpZmljYXRpb24gQXV0aG9yaXR5Fw05
NzA2MDkxNDQyNDNaFw05NzA3MDkxNDQyNDNaMCgwEgIBChcNOTcwMzAzMTQ0MjU0
WjASAgEJFw05NjEwMDIxMjI5MjdaMA0GCSqGSIb3DQEBAgUAA4GBAH4vgWo2Tej/
i7kbiw4Imd30If91iosjClNpBFwvwUDBclPEeMuYimHbLOk4H8Nofc0fw11+U/IO
KSNouUDcqG7B64oY7c4SXKn+i1MWOb5OJiWeodX3TehHjBlyWzoNMWCnYA8XqFP1
mOKp8Jla1BibEZf14+/HqCi2hnZUiEXh
-----END X509 CRL-----
]]
  local r = crl.read(dat)
  lu.assertIsTable(r:parse())
  -- print_r(r:parse())
  local e = r:export()
  lu.assertEquals(e, dat)
  e = r:export('der')
  local r1 = crl.read(e)
  assert(r:cmp(r1) == (r == r1))
  assert(r == r1)

  lu.assertEquals(r:version(), 0)
  lu.assertEquals(r:issuer():tostring(),
                  '/O=European ICE-TEL Project/OU=Certification Authority')
  lu.assertEquals(r:lastUpdate():toprint(), 'Jun  9 14:42:43 1997 GMT')
  lu.assertEquals(r:nextUpdate():toprint(), 'Jul  9 14:42:43 1997 GMT')
  lu.assertEquals(r:extensions(), nil)
  local l, n = r:updateTime()
  lu.assertEquals(r:lastUpdate(), l)
  lu.assertEquals(r:nextUpdate(), n)

  lu.assertEquals(r:count(), #r)
  lu.assertEquals(#r, 2)
end
