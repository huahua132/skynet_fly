local lu = require 'luaunit'
local openssl = require 'openssl'
local csr = openssl.x509.req
local helper = require 'helper'

TestPKCS12 = {}
function TestPKCS12:setUp()
  self.alg = 'sha1'
  self.dn = openssl.x509.name.new({{commonName = 'DEMO'},  {C = 'CN'}})

  self.ca = helper.get_ca()
  self.digest = 'sha1WithRSAEncryption'
end

function TestPKCS12:testNew()
  local extensions = {
    {
      object = 'nsCertType',
      value = 'email'
      -- critical = true
    },  {object = 'extendedKeyUsage',  value = 'emailProtection'}
  }

  local cert, pkey = helper.sign(self.dn, extensions)

  local ss = assert(openssl.pkcs12.export(cert, pkey, 'secret', 'USER'))
  local tt = assert(openssl.pkcs12.read(ss, 'secret'))
  lu.assertIsTable(tt)
  lu.assertStrContains(tostring(tt.cert), "openssl.x509")
  lu.assertStrContains(tostring(tt.pkey), "openssl.evp_pkey")

  ss = assert(openssl.pkcs12.export(cert, pkey, 'secret', 'USER', {self.ca.cacert}))
  tt = assert(openssl.pkcs12.read(ss, 'secret'))
  lu.assertIsTable(tt)
  lu.assertStrContains(tostring(tt.cert), "openssl.x509")
  lu.assertStrContains(tostring(tt.pkey), "openssl.evp_pkey")

  ss = assert(openssl.pkcs12.export(cert, pkey, 'secret', nil, {self.ca.cacert}))
  tt = assert(openssl.pkcs12.read(ss, 'secret'))
  lu.assertIsTable(tt)
  lu.assertStrContains(tostring(tt.cert), "openssl.x509")
  lu.assertStrContains(tostring(tt.pkey), "openssl.evp_pkey")
end
