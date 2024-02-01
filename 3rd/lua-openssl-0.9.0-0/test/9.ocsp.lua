local lu = require 'luaunit'
local openssl = require 'openssl'
local helper = require 'helper'
local ocsp = openssl.ocsp
if ocsp == nil then
  print('Skip test srp')
  return
end

TestOCSP = {}

function TestOCSP:setUp()
  self.ca = helper.get_ca()
  self.alicedn = {{commonName = 'Alice'},  {C = 'CN'}}
  self.bobdn = {{commonName = 'Bob'},  {C = 'CN'}}
  self.ocspdn = {{commonName = 'OCSP'},  {C = 'CN'}}
end

function TestOCSP:tearDown()
end

function TestOCSP:testAll()
  local req, pkey = helper.new_req(self.alicedn)
  local cert = self.ca:sign(req)
  self.alice = {key = pkey,  cert = cert, id = assert(ocsp.certid_new(cert, self.ca.cacert))}

  cert, pkey = assert(helper.sign(self.bobdn))
  local sn = cert:serial(false)
  self.bob = {key = pkey,  cert = cert, id = assert(ocsp.certid_new(sn, self.ca.cacert))}
  assert(type(self.bob.id:info())=='table')

  local oreq = ocsp.request_new()
  assert(oreq)
  local one = assert(oreq:add(self.alice.id))
  one = assert(oreq:add(self.bob.id))
  assert(oreq:is_signed()==false)

  assert(type(oreq:parse())=='table')

  local ocert, okey = helper.sign(self.ocspdn)

  assert(type(oreq:export(true)))

  assert(oreq:add_ext(openssl.x509.extension.new_extension({
    object = 'subjectAltName',
    value = "IP:192.168.0.1"
  })))
  assert(type(oreq:export(true))=='string')
  assert(type(oreq:parse().extensions)=='table')

  local der = assert(oreq:export(false))
  assert(type(der)=='string')

  -- avoid resign a ocsp request object
  oreq = assert(ocsp.request_read(der, false))
  assert(oreq:sign(ocert, okey))
  oreq = assert(ocsp.request_read(der, false))
  assert(oreq:sign(ocert, okey, {self.ca.cert}))
  oreq = assert(ocsp.request_read(der, false))
  assert(oreq:sign(ocert, okey, {self.ca.cert}, 0))
  oreq = assert(ocsp.request_read(der, false))
  assert(oreq:sign(ocert, okey, { self.ca.cert}, 0, 'sha256'))
  der = oreq:export(true)
  assert(type(der)=='string')

  assert(type(oreq:parse())=='table')

  oreq = ocsp.request_read(der, true)
  assert(oreq)
  local t = oreq:parse()
  assert(type(t)=='table')

  --OCSP_SINGLERESP_add1_ext_i2d(single, NID_invalidity_date, invtm, 0, 0);
  --OCSP_SINGLERESP_add1_ext_i2d(single, NID_hold_instruction_code, inst, 0, 0);
  local sn1 = tostring(self.bob.cert:serial())
  local sn2 = tostring(self.alice.cert:serial())
  local basic = assert(ocsp.basic_new())

  assert(basic:add(self.alice.id, ocsp.GOOD, ocsp.NOSTATUS, nil))
  local single = assert(basic:add(self.bob.id, ocsp.REVOKED, ocsp.UNSPECIFIED, os.time()))
  assert(single:add_ext(openssl.x509.extension.new_extension({
    object = 'subjectAltName',
    value = "IP:192.168.0.1"
  })))
  assert(type(single:info())=='table')

  assert(basic:add_ext(openssl.x509.extension.new_extension({
    object = 'subjectAltName',
    value = "IP:192.168.0.1"
  })))
  assert(basic:copy_nonce(oreq))
  assert(basic:sign(ocert, okey))
  assert(type(basic:info())=='table')

  resp = assert(basic:response())

  der = assert(resp:export(false))
  resp = ocsp.response_read(der, false)

  assert(resp:export(true))
  assert(resp:export(false))

  local t= resp:parse()
  assert(type(t)=='table')
end

