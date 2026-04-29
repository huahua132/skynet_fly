local lu = require 'luaunit'
local openssl = require 'openssl'
local helper = require 'helper'

local asn1, ts, csr = openssl.asn1, openssl.ts, openssl.x509.req

local policy_oid = '1.2.3.4.100'
local policy_obj = assert(asn1.new_object(policy_oid))
local policies = {
  assert(asn1.new_object('1.1.3')),  assert(asn1.new_object('1.1.4'))
}
local obja = assert(asn1.new_object({
  oid = '1.2.3.4.5.6',
  sn = '1.2.3.4.5.6_sn',
  ln = '1.2.3.4.5.6_ln'
}))
local objb = assert(asn1.new_object({
  oid = '1.2.3.4.5.7',
  sn = '1.2.3.4.5.7_sn',
  ln = '1.2.3.4.5.7_ln'
}))
assert(policies)
assert(obja)
assert(objb)

local function get_timezone()
  local now = os.time()
  return os.difftime(now, os.time(os.date("!*t", now)))
end

local function notAfter(a, b)
  a = a:sub(1, -2)
  b = b:sub(1, -2)
  return a <= b
end

local function createQuery(self, policy_id, nonce, cert_req, extensions)
  local req = assert(openssl.ts.req_new())
  local msg = openssl.ts.ts_msg_imprint_new(self.hash, self.alg)
  assert(msg:msg())
  assert(msg:algo())
  lu.assertIsTable(msg:totable())
  local ano = assert(msg:dup())
  ano = assert(msg:export())
  ano = openssl.ts.ts_msg_imprint_read(ano)
  assert(req:msg_imprint(msg))
  local m = req:msg_imprint()
  assert(msg:export()==m:export())
  if cert_req ~= nil then
    assert(req:cert_req(cert_req))
  else
    cert_req = false
  end
  if policy_id then assert(req:policy_id(policy_id)) end
  if nonce then assert(req:nonce(nonce)) end
  if extensions then assert(req:extensions(extensions)) end

  local der = assert(req:export())
  local ano = assert(ts.req_read(der))
  local t = ano:info()
  lu.assertIsTable(t)
  lu.assertEquals(t.version, 1)
  lu.assertEquals(t.msg_imprint.hashed_msg, self.hash)
  lu.assertEquals(t.msg_imprint.hash_algo:tostring(), self.alg)
  lu.assertEquals(cert_req, t.cert_req)
  if nonce then
    lu.assertEquals(t.nonce:totext(), nonce:totext())
  else
    lu.assertEquals(nil, t.nonce)
  end
  if policy_id then
    assert(policy_id:equals(t.policy_id))
    assert(policy_id:equals(ano:policy_id()))
    assert(policy_id:data(), t.policy_id:data())
    assert(ano:policy_id():data(), t.policy_id:data())
  end
  if extensions then assert(req:extensions()) end
  return req
end

local function createTsa(self)
  -- setUp private key and certificate
  local ca = {}
  self.ca = ca
  ca.dn = {{commonName = 'CA'},  {C = 'CN'}}
  ca.pkey = assert(openssl.pkey.new())
  local subject = assert(openssl.x509.name.new(ca.dn))

  local exts = {
    openssl.x509.extension.new_extension(
      {object = 'basicConstraints',  value = 'CA:TRUE'}),
    openssl.x509.extension.new_extension(
      {object = 'keyUsage',  value = 'cRLSign, keyCertSign'}),
  }

  local attrs = {
    {
      object = 'basicConstraints',
      type = asn1.OCTET_STRING,
      value = 'CA:TRUE'
    }
  }

  ca.req = assert(csr.new(subject))
  if (exts) then
    ca.req:extensions(exts)
  end
  if (attrs) then
    ca.req:attribute(attrs)
  end
  assert(ca.req:sign(ca.pkey))
  ca.cert = assert(ca.req:to_x509(ca.pkey))

  local extensions = {
    openssl.x509.extension.new_extension(
      {object = 'extendedKeyUsage',  value = 'timeStamping',  critical = true})
  }

  local tsa = {}
  self.tsa = tsa
  tsa.dn = {{commonName = 'tsa'},  {C = 'CN'}}
  tsa.pkey = assert(openssl.pkey.new())
  subject = openssl.x509.name.new(tsa.dn)

  tsa.req = csr.new(subject, tsa.pkey)
  lu.assertEquals(type(tsa.req:parse()), 'table')

  tsa.cert = openssl.x509.new(1, tsa.req)
  assert(tsa.cert:validat(os.time(), os.time() + 3600 * 24 * 365))
  assert(tsa.cert:extensions(extensions))
  assert(tsa.cert:sign(ca.pkey, ca.cert))

  lu.assertEquals(type(tsa.cert:parse()), 'table')

  ca.store = openssl.x509.store.new({ca.cert})
  assert(tsa.cert:check(ca.store, nil, 'timestamp_sign'))
  self.tsa = tsa
  return tsa
end

local function createRespCtx(self, serial_cb, time_cb)
  local tsa = self.tsa
  local req_ctx = assert(ts.resp_ctx_new(tsa.cert, tsa.pkey, self.policy_id))
  assert(req_ctx:md({'md5',  'sha1'}))

  if serial_cb then req_ctx:set_serial_cb(serial_cb, self) end

  if time_cb then req_ctx:set_time_cb(time_cb, self) end
  assert(req_ctx:md('sha256')==true)
  assert(req_ctx:accuracy(1, 1, 1))
  return req_ctx
end

local function signReq(self, req_ctx, req, sn, now)
  local res = req_ctx:sign(req:export())
  local t = assert(res:status_info())

  lu.assertIsTable(t)
  local status = t.status:tonumber()
  if status ~= 0 then
    assert(t.failure_info or helper.libressl)
    assert(#t>0)
    return
  end

  assert(t.status:tostring() == '0')
  assert(#t == 0)
  assert(not t.failure_info)

  local token = res:token()
  lu.assertIsUserdata(token)

  local tst = res:tst_info()
  lu.assertIsUserdata(tst)

  sn = sn or '01'
  lu.assertEquals(sn, tst:serial():tohex())
  lu.assertEquals(1, tst:version())
  lu.assertEquals(tst:ordering(), false)
  lu.assertEquals(self.policy_id:txt(true), tst:policy_id():txt(true))

  if not now then
    now = os.time()
    local timezone = get_timezone()
    now = os.date('%Y%m%d%H%M%SZ', now - timezone + 1)
  end
  assert(notAfter(tst:time():tostring(), now))

  if req:nonce() then
    lu.assertIsString(tst:nonce():tostring())
    lu.assertEquals(req:nonce(), tst:nonce())
  end

  res = res:dup()
  res = assert(openssl.ts.resp_read(res:export()))
  assert(type(res:tst_info())=='userdata')
  local vry = assert(req:to_verify_ctx())
  vry:store(self.ca.store)
  local flags = vry:flags(0, true)
  assert(vry:flags(9))
  assert(9==vry:flags(0, true))
  vry:flags(flags)
  assert(vry:verify(res:token()))

  vry = assert(ts.verify_ctx_new())
  vry:imprint(self.hash)
  vry:store(self.ca.store)
  assert(vry:verify(res:export()))

  vry = assert(ts.verify_ctx_new())
  vry:data(self.dat)
  vry:store(self.ca.store)
  assert(vry:verify(res))

  vry = assert(ts.verify_ctx_new())
  vry:imprint(self.hash)
  vry:data(self.dat)
  vry:store(self.ca.store)
  assert(vry:verify(res))

  vry = assert(ts.verify_ctx_new(req:export()))
  vry:imprint(self.hash)
  vry:data(self.dat)
  vry:store(self.ca.store)
  assert(vry:verify(res))

  vry = assert(ts.verify_ctx_new(req))
  vry:imprint(self.hash)
  vry:data(self.dat)
  vry:store(self.ca.store)
  assert(vry:verify(res))

  return res
end

TestTS = {}

function TestTS:setUp()
  math.randomseed(os.time())
  self.msg = openssl.random(32)
  self.alg = 'sha1'
  self.hash = assert(openssl.digest.digest(self.alg, self.msg, true))
  self.nonce = openssl.bn.text(openssl.random(16))
  self.digest = 'sha1WithRSAEncryption'
  self.md = openssl.digest.get('sha1WithRSAEncryption')
  self.policy_id = policy_obj

  local der = policy_obj:i2d()
  assert(der)
  local ano = openssl.asn1.new_object()
  assert(ano:d2i(der))
  assert(ano:equals(policy_obj))

  local timeStamping = asn1.new_type('timeStamping')
  self.timeStamping = timeStamping:i2d()
  self.cafalse = openssl.asn1.new_string('CA:FALSE', asn1.OCTET_STRING)

  self.dat = openssl.random(256)
  assert(createTsa(self))
end

function TestTS:testBasic()
  local req = createQuery(self)
  assert(req:add_ext(openssl.x509.extension.new_extension({
    object = 'subjectAltName',
    value = "IP:192.168.0.1"
  })))
  assert(req:msg_imprint())
  req = assert(req:dup())

  local req_ctx = createRespCtx(self)
  local res = req_ctx:sign(req:export())
  assert(res)
  assert(req_ctx:signer(self.tsa.cert, self.tsa.pkey))
  assert(req_ctx:certs({self.ca.cert, self.tsa.cert}))
  assert(req_ctx:default_policy(policy_obj))
  assert(req_ctx:policies(policies))
  assert(req_ctx:accuracy(1, 1, 1))
  assert(req_ctx:clock_precision_digits(20))
  req_ctx:add_flags(openssl.ts.VFY_SIGNATURE)
  req_ctx:tst_info()
  req_ctx:tst_info(false, "version")
  req_ctx:tst_info(true, "version")
  req_ctx:tst_info(false, "version")
  req_ctx:request()
  lu.assertEquals(false, req:cert_req())

  signReq(self, req_ctx, req)
  assert(req:dup():export()==req:export())
  assert(req:version(2))
  assert(req:version()==2)
end

function TestTS:testPloicyId()
  local req = createQuery(self, self.policy_id, nil, true)
  local req_ctx = createRespCtx(self)
  signReq(self, req_ctx, req)
end

function TestTS:testCertReq()
  local req = createQuery(self, nil, nil, true)
  local req_ctx = createRespCtx(self)
  assert(req:cert_req())
  signReq(self, req_ctx, req)
end

function TestTS:testNonce()
  local req = createQuery(self, nil, self.nonce)
  local req_ctx = createRespCtx(self)
  assert(req:nonce())
  signReq(self, req_ctx, req)
end

function TestTS:testExtensions()
  local extensions = nil
  local req = createQuery(self, nil, nil, extensions)
  local req_ctx = createRespCtx(self)
  signReq(self, req_ctx, req)
end

function TestTS:testSerialCallback()
  local req = createQuery(self)

  local serial_cb = function(this)
    self.sn = 0x7fffffff;
    return this.sn
  end
  local req_ctx = createRespCtx(self, serial_cb)
  signReq(self, req_ctx, req, '7FFFFFFF')
end

function TestTS:testAccuracy()
  local sec, mil, mic = 100000, 10, 1
  local accuracy = openssl.ts.ts_accuracy_new(sec, mil, mic)
  assert(accuracy:seconds()==sec)
  assert(accuracy:seconds(sec+1))
  assert(accuracy:seconds()==sec+1)
  assert(accuracy:millis()==mil)
  assert(accuracy:millis(mil+1))
  assert(accuracy:millis()==mil+1)
  assert(accuracy:micros()==mic)
  assert(accuracy:micros(mic+1))
  assert(accuracy:micros()==mic+1)
  local dup = assert(accuracy:dup())
  local ano = assert(dup:export())
  ano = assert(openssl.ts.ts_accuracy_read(ano))
  dup, ano = dup:totable(), ano:totable()
  lu.assertEquals(dup, ano)
  accuracy = openssl.ts.ts_accuracy_new(sec)
  accuracy = accuracy:totable()
  lu.assertEquals(accuracy, {seconds=sec, millis=0, micros=0})
end

function TestTS:testTimeCallback()
  local req = createQuery(self)

  local time_cb = function(this)
    self.time = 0x7fffffff;
    return this.time
  end
  local req_ctx = createRespCtx(self, nil, time_cb)
  local res = signReq(self, req_ctx, req, nil, '20380119031407Z')
  local t = assert(res:status_info())
  lu.assertIsTable(t)

  assert(t.status:tostring() == '0')
  assert(#t == 0)
  assert(not t.failure_info)
  assert(res:dup():export()==res:export())

  local tst = res:tst_info()
  assert(tst:version()==1)
  assert(tst.policy_id)
  assert(tst:policy_id():txt()=="1.2.3.4.100")
  assert(tst:msg_imprint())
  assert(tst:serial():tostring())
  assert(tst:time():tostring())
  assert(tst:accuracy())
  assert(tst:ordering()==false)
  local sec, mil, mic = 100000, 10, 1
  local accuracy = openssl.ts.ts_accuracy_new(sec, mil, mic)
  tst:accuracy(accuracy)

  tst:nonce()
  tst:tsa()
  tst:extensions()

end

