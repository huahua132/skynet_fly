local lu = require 'luaunit'
local openssl = require 'openssl'
local attr = require'openssl'.x509.attribute
local asn1 = require'openssl'.asn1

TestX509attr = {}
function TestX509attr:setUp()
  self.timeStamping = openssl.asn1.new_string('timeStamping', asn1.IA5STRING)
  self.cafalse = openssl.asn1.new_string('CA:FALSE', asn1.OCTET_STRING)
  self.time = {
    object = 'extendedKeyUsage',
    type = asn1.IA5STRING,
    value = 'timeStamping'
  }
  self.ca = {
    object = 'basicConstraints',
    type = asn1.OCTET_STRING,
    value = self.cafalse
  }
  self.cas = {
    object = 'basicConstraints',
    type = asn1.OCTET_STRING,
    value = 'CA:FALSE'
  }
  self.attrs = {self.time,  self.ca,  self.cas}
end

function TestX509attr:tearDown()
end

function TestX509attr:testAll()
  local n1 = attr.new_attribute(self.ca)
  lu.assertStrContains(tostring(n1), 'openssl.x509_attribute')
  local info = n1:info()
  lu.assertIsTable(info)
  lu.assertEquals(info.object:ln(), "X509v3 Basic Constraints")
  lu.assertEquals(#info.value, 1)
  lu.assertEquals(info.value[1].type, asn1.OCTET_STRING)
  lu.assertEquals(info.value[1].value, "CA:FALSE")
  local n2 = n1:dup()
  lu.assertEquals(n2:info(), info)

  local t = n1:type(0)
  lu.assertIsTable(t)
  lu.assertEquals(t.type, asn1.OCTET_STRING)
  lu.assertEquals(t.value, 'CA:FALSE')

  n2 = attr.new_attribute(self.cas)
  lu.assertEquals(n1:info(), n2:info())

  lu.assertEquals(n1:object():ln(), 'X509v3 Basic Constraints')
  n1:object('extendedKeyUsage')
  lu.assertEquals(n1:object():sn(), 'extendedKeyUsage')

  lu.assertEquals(n1:data(0, asn1.OCTET_STRING):tostring(), 'CA:FALSE')

  assert(n1:data(0, "ABCD"))
end
