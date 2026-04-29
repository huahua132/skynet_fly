local lu = require 'luaunit'
local openssl = require 'openssl'
local ext = require'openssl'.x509.extension
local asn1 = require'openssl'.asn1

TestX509ext = {}

function TestX509ext:setUp()
  self.timeStamping = openssl.asn1.new_string('timeStamping', asn1.IA5STRING)
  self.cafalse = openssl.asn1.new_string('CA:FALSE', asn1.OCTET_STRING)
  self.time = {
    object = 'extendedKeyUsage',
    critical = true,
    value = 'timeStamping'
  }
  self.ca = {object = 'basicConstraints',  value = self.cafalse}
  self.cas = {object = 'basicConstraints',  value = 'CA:FALSE'}
  self.exts = {self.time,  self.ca,  self.cas}
end

function TestX509ext:tearDown()
end

function TestX509ext:testSupport()
  local supports = ext.support()
  assert(#supports>0)
  assert(supports[1].sname)
  assert(supports[1].lname)
  assert(supports[1].nid)

  local caext = ext.new_extension(self.ca)
  assert(ext.support(caext))

  local obj = openssl.asn1.new_object('extendedKeyUsage')
  assert(ext.support(obj))
  obj = openssl.asn1.new_object('emailAddress')
  assert(obj)
  assert(not ext.support(obj))

  local exts = {
    {
      object = 'subjectAltName',
      value = 'IP:192.168.1.1,RID:1.2.3.4'
    },
    {
      object = 'subjectAltName',
      value = 'IP:192.168.1.1'
    },
    {
      object = 'subjectAltName',
      value = 'DNS:abc.xyz'
    },
    {
      object = 'subjectAltName',
      value = 'URI:http://my.url.here/'
    },
    {
      object = 'subjectAltName',
      value = 'otherName:1.2.3.4;UTF8:some other identifier'
    },
    {
      object = 'subjectAltName',
      value = 'email:123@abc.com'
    },
    --{
    --  object = 'subjectAltName',
    --  value = 'x400Name:C=US/O=Organization/G=Nuno/CN=demo'
    --},
    --{
    --  object = 'subjectAltName',
    --  value = 'EdiPartyName:123@abc.com'
    --},
    --{
    --  object = 'subjectAltName',
    --  value = 'dirName:/C=NZ/CN=Jackov al-Trades'
    --}
  }

  for i=1, #exts do
    local obj = ext.new_extension(exts[i])
    assert(ext.support(obj))
    lu.assertIsTable(obj:info())
  end

end

function TestX509ext:testAll()
  local n1 = ext.new_extension(self.ca)
  lu.assertStrContains(tostring(n1), 'openssl.x509_extension')
  local info = n1:info()
  lu.assertIsTable(info)
  lu.assertEquals(info.object:ln(), "X509v3 Basic Constraints")
  lu.assertEquals(info.critical, false)
  lu.assertEquals(info.value:tostring(), "CA:FALSE")

  local n2 = n1:dup()
  lu.assertEquals(n2:info(), info)
  lu.assertEquals(n1:critical(), false)
  n1:critical(true)
  lu.assertEquals(n1:critical(), true)

  assert(ext.new_extension(self.cas))
  lu.assertEquals(n1:object():ln(), 'X509v3 Basic Constraints')
  n1:object('extendedKeyUsage')
  lu.assertEquals(n1:object():sn(), 'extendedKeyUsage')

  lu.assertEquals(n1:data():tostring(), 'CA:FALSE')
  lu.assertErrorMsgEquals(
    "bad argument #2 to '?' (only accpet asn1 octet string if is a asn1 string)",
    n1.data, n1, self.timeStamping)
  assert(n1:data('CA:FALSE'))
  lu.assertEquals(n1:data(), self.cafalse)

  local time = ext.new_extension(self.time)
  lu.assertEquals(time:critical(), true)
  local der = time:export()
  local t1 = ext.read_extension(der)
  assert(der == t1:export())

  assert(n1:data(asn1.new_string('CA:FALSE', asn1.OCTET_STRING)))
end
