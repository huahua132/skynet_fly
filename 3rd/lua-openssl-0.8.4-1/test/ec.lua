local lu = require 'luaunit'
local openssl = require 'openssl'
local pkey = openssl.pkey
local unpack = unpack or table.unpack

TestEC = {}

function TestEC:testCompat()
  local factor = {
    alg = "ec",
    ec_name = 415,
    x = assert(openssl.base64('fBEMZtz9qAf25p5F3bPHT2mhSE0gPo3Frajpqd18s8c=',
                              false)),
    y = assert(openssl.base64('DfRImG5RveXRV2+ZkB+cLGqAakf9kHZDpyuDVZfvyMY=',
                              false)),
    d = assert(openssl.base64('H+M5UMX0YRJK6ZLCvf3xxzsWFfVxvVZ+YNGaofSM30I=',
                              false))
  }
  local ec = assert(pkey.new(factor))

  local pem = assert(ec:export('pem'))
  lu.assertEquals(pem, [[
-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgH+M5UMX0YRJK6ZLC
vf3xxzsWFfVxvVZ+YNGaofSM30KhRANCAAR8EQxm3P2oB/bmnkXds8dPaaFITSA+
jcWtqOmp3Xyzxw30SJhuUb3l0VdvmZAfnCxqgGpH/ZB2Q6crg1WX78jG
-----END PRIVATE KEY-----
]])

  factor.x, factor.y = nil, nil
  ec = assert(pkey.new(factor))
  assert(pem, ec:export('pem'))
end

function TestEC:TestEC()
  local nec = {'ec',  'prime256v1'}
  local ec = pkey.new(unpack(nec))
  local t = ec:parse().ec:parse('pem') -- make basic table
  lu.assertEquals(type(t.curve_name), 'number')
  lu.assertStrContains(t.x.version, 'bn library')
  lu.assertStrContains(t.y.version, 'bn library')
  lu.assertStrContains(t.d.version, 'bn library')

  local k1 = pkey.get_public(ec)
  assert(not k1:is_private())
  t = k1:parse()
  assert(t.bits == 256)
  assert(t.type == 'EC')
  assert(t.size == 72)
  local r = t.ec
  t = r:parse(true) -- make basic table
  lu.assertEquals(type(t.curve_name), 'number')
  lu.assertStrContains(t.x.version, 'bn library')
  lu.assertStrContains(t.y.version, 'bn library')
  lu.assertEquals(t.d, nil)
  t = r:parse()
  lu.assertStrContains(tostring(t.pub_key), 'openssl.ec_point')
  lu.assertStrContains(tostring(t.group), 'openssl.ec_group')
  local x, y = t.group:affine_coordinates(t.pub_key)
  lu.assertStrContains(x.version, 'bn library')
  lu.assertStrContains(y.version, 'bn library')
  local ec2p = {
    alg = 'ec',
    ec_name = t.group:parse().curve_name,
    x = x,
    y = y
  }
  local ec2 = pkey.new(ec2p)
  assert(not ec2:is_private())

  ec2p.d = ec:parse().ec:parse().priv_key
  local ec2priv = pkey.new(ec2p)
  assert(ec2priv:is_private())

  assert(openssl.ec.group(ec:parse().ec, 4, 1))
  assert(openssl.ec.group(ec2, 4, 1))
end

function TestEC:TestPrime256v1()
  local nec = {'ec',  'prime256v1'}
  local key1 = pkey.new(unpack(nec))
  local key2 = pkey.new(unpack(nec))
  local ec1 = key1:parse().ec
  local ec2 = key2:parse().ec
  local secret1 = ec1:compute_key(ec2)
  local secret2 = ec2:compute_key(ec1)
  assert(secret1 == secret2)

  local pub1 = pkey.get_public(key1)
  local pub2 = pkey.get_public(key2)
  pub1 = pub1:parse().ec
  pub2 = pub2:parse().ec

  secret1 = ec1:compute_key(pub2)
  secret2 = ec2:compute_key(pub1)
  assert(secret1 == secret2)
end

if openssl.ec then
  local function ECConversionForm(form, flag)
    local grp, pnt = openssl.ec.group('prime256v1', form, flag)
    assert(grp:asn1_flag() == flag)
    assert(grp:point_conversion_form() == form)

    local oct = grp:point2oct(pnt)
    if form=='uncompressed' or form=='hybrid' then
      assert(#oct==65)
    elseif form == 'compressed' then
      assert(#oct==33)
    else
      error(form)
    end

    local pnt1 = grp:oct2point(oct)
    assert(grp:point_equal(pnt, pnt1))

    assert(grp:point_conversion_form('compressed'))
    oct = grp:point2oct(pnt)
    assert(#oct==33)
    oct = grp:point2oct(pnt, 'compressed')
    assert(#oct==33)
    local pnt2 = grp:oct2point(oct, 'compressed')
    assert(grp:point_equal(pnt2, pnt1))

    local bn = grp:point2bn(pnt)
    pnt2 = grp:bn2point(bn)
    assert(grp:point_equal(pnt2, pnt1))

    bn = grp:point2bn(pnt, 'compressed')
    pnt2 = grp:bn2point(bn)
    assert(grp:point_equal(pnt2, pnt1))

    local hex = grp:point2hex(pnt)
    pnt2 = grp:hex2point(hex)
    assert(grp:point_equal(pnt2, pnt1))

    local hex = grp:point2hex(pnt, 'compressed')
    pnt2 = grp:hex2point(hex)
    assert(grp:point_equal(pnt2, pnt1))

    local ec = grp:generate_key()
    local t = ec:parse()
    assert(type(t)=='table')
    local grp1 = ec:group()

    assert(grp1:asn1_flag('explicit'))
    assert(grp1:point_conversion_form('hybrid'))
    assert(grp==grp1)

    local der = ec:do_sign('abcd')
    assert(#der>=68 and #der <= 72)
    assert(ec:do_verify('abcd', der))

    local dgst = openssl.random(32)
    der = ec:sign(dgst, 'sha256')
    assert(#der>=68 and #der <= 72)
    assert(ec:verify(dgst, der, 'sha256'))

    der = ec:export()
    assert(type(der)=='string')
    local ec1 = openssl.ec.read(der)
    assert(ec1:set_method(openssl.engine('openssl')))
    assert(ec1:conv_form('hybrid'))
    assert(ec1:conv_form()=='hybrid')
    assert(ec1:enc_flags('explicit'))
    assert(ec1:enc_flags()=='explicit')
    assert(ec1:check())
    assert(ec1:export())

    local x, y = ec:do_sign('abcd', false)
    assert(ec:do_verify('abcd', x, y))

    local msg = openssl.random(32)

    local sig = ec:do_sign(msg)
    assert(ec:do_verify(msg, sig))

    pnt = assert(grp:point_new())
    pnt1 = assert(grp:point_dup(pnt))
    assert(grp:point_equal(pnt, pnt1))

    local factor = {
      alg = "ec",
      ec_name = 415,
      x = assert(openssl.base64('fBEMZtz9qAf25p5F3bPHT2mhSE0gPo3Frajpqd18s8c=',
                                false)),
      y = assert(openssl.base64('DfRImG5RveXRV2+ZkB+cLGqAakf9kHZDpyuDVZfvyMY=',
                                false)),
      d = assert(openssl.base64('H+M5UMX0YRJK6ZLCvf3xxzsWFfVxvVZ+YNGaofSM30I=',
                                false))
    }
    grp:affine_coordinates(pnt, openssl.bn.text(factor.x), openssl.bn.text(factor.y))
    pnt1:copy(pnt)
    assert(grp:point_equal(pnt, pnt1))
  end

  function TestEC:TestConversionForm()
    local lc = openssl.ec.list()
    assert(type(lc)=='table')
    ECConversionForm("uncompressed", "named_curve")
    ECConversionForm("uncompressed", "explicit")
    ECConversionForm("compressed", "named_curve")
    ECConversionForm("compressed", "explicit")
    ECConversionForm("hybrid", "named_curve")
    ECConversionForm("hybrid", "explicit")
  end

  function TestEC:TestIssue262()
    local grp = openssl.ec.group('prime256v1', "compressed", "named_curve")
    local ec = grp:generate_key()

    local dgst = openssl.random(32)
    local der = ec:sign(dgst, 'sha256')
    local der2 = der:sub(1, 20)

    assert(ec:verify(dgst, der, 'sha256')) -- this is true
    lu.assertErrorMsgEquals("bad argument #4 to '?' (invalid digest)", ec.verify, ec, dgst .. "x", der, 'sha256')
    lu.assertErrorMsgEquals("bad argument #4 to '?' (invalid digest)", ec.verify, ec, dgst, der, 'sha1')
    assert(ec:verify(dgst, der2, 'sha256')==nil)
  end
end

