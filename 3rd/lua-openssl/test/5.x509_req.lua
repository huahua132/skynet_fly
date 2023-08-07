local lu = require 'luaunit'

local openssl = require 'openssl'
local csr = require'openssl'.x509.req
local asn1 = require'openssl'.asn1
local helper = require'helper'

TestCSR = {}

function TestCSR:setUp()
  self.digest = 'sha256'
  self.subject = openssl.x509.name.new({
    {C = 'CN'},  {O = 'kkhub.com'},  {CN = 'zhaozg'}
  })

  self.timeStamping = openssl.asn1.new_string('timeStamping', asn1.IA5STRING)
  self.cafalse = openssl.asn1.new_string('CA:FALSE', asn1.OCTET_STRING)

  self.exts = {
    openssl.x509.extension.new_extension(
      {object = 'extendedKeyUsage',  critical = true,  value = 'timeStamping'}),
    openssl.x509.extension.new_extension(
      {object = 'basicConstraints',  value = self.cafalse}),
    openssl.x509.extension.new_extension(
      {object = 'basicConstraints',  value = 'CA:FALSE'})
  }

  self.attrs = {
    {
      object = 'extendedKeyUsage',
      type = asn1.IA5STRING,
      value = 'timeStamping'
    },
    {
      object = 'basicConstraints',
      type = asn1.OCTET_STRING,
      value = self.cafalse
    },
    {
      object = 'basicConstraints',
      type = asn1.OCTET_STRING,
      value = 'CA:FALSE'
    }
  }

  self.extensions = self.exts
  self.attributes = self.attrs
end

function TestCSR:testNew()
  local pkey = assert(openssl.pkey.new())
  local req1, req2
  req1 = assert(csr.new())
  req2 = assert(csr.new(pkey))
  local t = req1:parse()
  lu.assertIsTable(t)
  t = req2:parse()
  lu.assertIsTable(t)
  assert(req1:verify() == false);
  assert(req2:verify())

  req1 = assert(csr.new(self.subject))
  req2 = assert(csr.new(self.subject, pkey))

  t = req1:parse()
  lu.assertIsTable(t)
  t = req2:parse()
  lu.assertIsTable(t)
  assert(req1:verify() == false);
  assert(req2:verify());

  req1 = assert(csr.new(self.subject))
  req2 = assert(csr.new(self.subject))
  assert(req2:sign(pkey, 'sha1WithRSAEncryption'))
  t = req1:parse()
  lu.assertIsTable(t)
  t = req2:parse()
  lu.assertIsTable(t)

  assert(req1:verify() == false);
  assert(req2:verify())

  req1 = assert(csr.new(self.subject))
  req1:attribute(self.attributes)
  req1:extensions(self.extensions)
  req2 = assert(csr.new(self.subject))
  req2:attribute(self.attributes)
  req2:extensions(self.extensions)
  assert(req2:sign(pkey))
  assert(req1:verify() == false);
  assert(req2:verify())

  t = req1:parse()
  lu.assertIsTable(t)
  t = req2:parse()
  lu.assertIsTable(t)

  assert(req1:verify() == false);
  assert(req2:verify())

  req1 = assert(csr.new(self.subject))
  req1:attribute(self.attributes)
  req1:extensions(self.extensions)
  assert(req1:sign(pkey))
  req2 = assert(csr.new(self.subject))
  req2:attribute(self.attributes)
  req2:extensions(self.extensions)
  assert(req2:sign(pkey, self.digest))

  t = req1:parse()
  lu.assertIsTable(t)
  t = req2:parse()
  lu.assertIsTable(t)

  assert(req1:verify())
  assert(req2:verify())

  local pem = req2:export('pem')
  lu.assertIsString(pem)
  local req2 = assert(csr.read(pem, 'pem'))
  lu.assertIsNil(csr.read(pem, 'der'))
  req2 = assert(csr.read(pem, 'auto'))

  local der = req2:export('der')
  lu.assertIsString(der)
  req2 = assert(csr.read(der, 'der'))
  lu.assertIsNil(csr.read(der, 'pem'))
  req2 = assert(csr.read(der, 'auto'))
  local pubkey = req2:public()
  lu.assertStrContains(tostring(pubkey), "openssl.evp_pkey")
  assert(req1:public(pubkey))

  local cnt = req1:attr_count()
  -- FIXME: openssl v3.0.9 or v3.0.10
  -- FIXME: attr should include extensions
  lu.assertTrue(cnt >= 3 and cnt <= 4)

  local attr = req1:attribute(0)
  lu.assertStrContains(tostring(attr), 'openssl.x509_attribute')

  attr = req1:attribute(0, nil)
  lu.assertStrContains(tostring(attr), 'openssl.x509_attribute')
  lu.assertEquals(req1:attr_count(), cnt - 1)
  req1:attribute(attr)
  lu.assertEquals(req1:attr_count(), cnt)

  lu.assertEquals(req1:version(), 0)
  lu.assertEquals(req1:version(1), true)
  lu.assertEquals(req1:version(), 1)
  assert(req1:version(0))

  lu.assertEquals(req1:subject():tostring(), self.subject:tostring())
  assert(req1:subject(self.subject))
  lu.assertEquals(req1:subject():tostring(), self.subject:tostring())

  lu.assertStrContains(type(req1:extensions()), 'table')
  -- FIXME: openssl v3.0.9 or v3.0.10
  -- assert(req1:extensions(self.extensions))
  lu.assertEquals(req1:subject():tostring(), self.subject:tostring())

  local s = req1:digest()
  local r = req1:digest('sha256')
  lu.assertEquals(r, s)
  assert(req2:check(pkey))

  local cert = assert(req2:to_x509(pkey, 3650)) -- self sign
  t = cert:parse()
  assert(type(t) == 'table')
  lu.assertStrContains(tostring(req1:to_x509(pkey, 3650)), 'openssl.x509')
  lu.assertStrContains(tostring(req2:to_x509(pkey, 3650)), 'openssl.x509')

  openssl.errors()

  if not helper.openssl3 then -- FIXME: lua-openssl, avoid foreign key dup
    req1 = assert(req2:dup())
    assert(req1:export()==req2:export())
  end

  --[[ FIXME: memleaks
  local tosign = assert(req1:sign())
  local sig = assert(pkey:sign(tosign, 'sha256'))
  assert(req1:sign(sig, 'sha256')==true)
  --]]
end

function TestCSR:testIO()
  local csr_data = [==[
-----BEGIN CERTIFICATE REQUEST-----
MIIBvjCCAScCAQAwfjELMAkGA1UEBhMCQ04xCzAJBgNVBAgTAkJKMRAwDgYDVQQH
EwdYSUNIRU5HMQ0wCwYDVQQKEwRUQVNTMQ4wDAYDVQQLEwVERVZFTDEVMBMGA1UE
AxMMMTkyLjE2OC45LjQ1MRowGAYJKoZIhvcNAQkBFgtzZGZAc2RmLmNvbTCBnzAN
BgkqhkiG9w0BAQEFAAOBjQAwgYkCgYEA0auDcE3VFsp6J3NvyPBiiZLLnAUnUMPQ
lxmGUcbGI12UA3Z0+hNcRprDX5vD7ODUVZrR4iAozaTKUGe5w2KrhElrV/3QGzGH
jMUKvYgtlYr/vK1cAX9wx67y7YBnPbIRVqdLQRLF9Zu8T5vaMx0a/e1dzQq7EvKr
xjPVjCSgZ8cCAwEAAaAAMA0GCSqGSIb3DQEBBQUAA4GBAF3sMj2dtIcVTHAnLmHY
lemLpEEo65U7iLJUskUNMsDrNLEVt7kuWlz0uQDnuZ4qgrRVJ2BpxskTR5D5Yzzc
wSpxg0VN6+i6u9C9n4xwCe1VyteOC2In0LbxMAGL3rVFm9yDFRU3LDy3EWG6DIg/
4+QM/GW7qfmes65THZt0Hram
-----END CERTIFICATE REQUEST-----
]==]

  local x = assert(csr.read(csr_data))
  local t = x:parse()
  lu.assertIsTable(t)
  lu.assertIsUserdata(t.subject)
  lu.assertIsNumber(t.version)
  lu.assertIsTable(t.req_info)

  if not helper.libressl
    or (helper.libressl and helper._opensslv < 0x3050000f) then
  lu.assertIsTable(t.req_info.pubkey)
  lu.assertIsUserdata(t.req_info.pubkey.pubkey)
  lu.assertIsUserdata(t.req_info.pubkey.algorithm)
  else
  --FIXME: t.req_info is nil
  lu.assertIsNil(t.req_info.pubkey)
  end

end
