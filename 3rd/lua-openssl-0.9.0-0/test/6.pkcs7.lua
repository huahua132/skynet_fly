local lu = require 'luaunit'

local openssl = require 'openssl'
local pkcs7 = openssl.pkcs7
local helper = require 'helper'

TestPKCS7 = {}
function TestPKCS7:setUp()
  self.alg = 'sha1'
  self.dn = {{commonName = 'DEMO'},  {C = 'CN'}}

  self.digest = 'sha1WithRSAEncryption'
end

function TestPKCS7:testNew()
  local ca = helper.get_ca()
  local store = ca:get_store()
  assert(store:trust(true))
  store:add(ca.cacert)
  store:add(ca.crl)

  local e = openssl.x509.extension.new_extension(
              {object = 'keyUsage',  value = 'smimesign'}, false)
  assert(e)
  local extensions = {
    {
      object = 'nsCertType',
      value = 'email'
      -- critical = true
    },  {object = 'extendedKeyUsage',  value = 'emailProtection'}
  }
  -- extensions:push(e)

  local cert, pkey = helper.sign(self.dn, extensions)

  local msg = 'abcd'

  local skcert = {cert}
  local p7 = assert(pkcs7.encrypt(msg, skcert))
  local ret = assert(pkcs7.decrypt(p7, cert, pkey))
  lu.assertEquals(msg, ret)
  assert(p7:parse())
  -------------------------------------
  p7 = assert(pkcs7.sign(msg, cert, pkey))
  assert(p7:export())
  ret = assert(p7:verify(skcert, store))
  assert(ret==msg)
  assert(p7:parse())

  p7 = assert(pkcs7.sign(msg, cert, pkey, nil, openssl.pkcs7.DETACHED))
  assert(p7:export())
  ret = assert(p7:verify(skcert, store, msg, openssl.pkcs7.DETACHED))
  assert(type(ret)=='boolean')
  assert(ret)
  assert(p7:parse())

  local der = assert(p7:export('der'))
  p7 = assert(openssl.pkcs7.read(der, 'der'))

  der = assert(p7:export('smime'))
  p7 = assert(openssl.pkcs7.read(der, 'smime'))

  der = assert(p7:export())
  assert(openssl.pkcs7.read(der, 'auto'))

  local p = openssl.pkcs7.new('signed', 'data')
  p:add(ca.cacert)
  p:add(cert)
  p:add(ca.crl)
  assert(p:parse())
  -- FIXME: illegal zero content
  -- assert(p:export())
  -- assert(p:export('der'))
  local ln, sn = p:type()
  assert(ln)
  assert(sn)

  p7 = openssl.pkcs7.create({
      ca.cacert,
      cert
    }, {ca.crl})
  assert(p7:parse())

  -- TODO: enable below
  -- p7:set_content(p)

  -- FIXME: illegal zero content
  -- assert(p7:export())
  -- assert(p7:export('der'))
  ln, sn = p7:type()
  assert(ln)
  assert(sn)

end

function TestPKCS7:testData()
  local p = openssl.pkcs7.new('signed', 'data')
  assert(p:final('content'))
  local conent = p:parse().contents:parse()

  assert('content' == conent.data:tostring())
end

function TestPKCS7:testDigest()
  local p = openssl.pkcs7.new('signed', 'data')
  assert(p:set_digest('sha256'))
  assert(p:final('content'))
  local conent = p:parse().contents:parse()

  assert('content' == conent.data:tostring())
end

