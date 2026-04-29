local lu = require("luaunit")
local openssl = require("openssl")
local group = openssl.ec.group
local bn = openssl.bn

TestGroup = {}

function TestGroup:setUp()
  -- Set up common test groups
  self.p256 = group.new('prime256v1')
  self.secp384r1 = group.new('secp384r1')
  assert(not self.p256 ~= self.secp384r1, "Groups should be different")
end

function TestGroup:testNew()
  -- Test creating group from curve name
  local g = group.new('prime256v1')
  lu.assertNotNil(g)

  -- Test creating group from NID
  local g2 = group.new(415) -- NID for prime256v1
  lu.assertNotNil(g2)

  -- Test invalid curve name
  lu.assertNil(group.new('invalid_curve'))
end

function TestGroup:testDup()
  local g = self.p256
  local g2 = g:dup()
  lu.assertNotNil(g2)
  lu.assertTrue(g:equal(g2))
end

function TestGroup:testGenerator()
  local g = self.p256
  local gen = g:generator()
  lu.assertNotNil(gen)
  -- Generator should be a valid EC point
  lu.assertEquals(type(gen), 'userdata')
end

function TestGroup:testOrder()
  local g = self.p256
  local order = g:order()
  lu.assertNotNil(order)
  -- Order should be a BIGNUM
  lu.assertEquals(type(order), 'userdata')
  lu.assertStrContains(bn.version, "bn library")
  -- Prime256v1 order should be 256 bits
  lu.assertTrue(order:bits() > 255 and order:bits() <= 256)
end

function TestGroup:testCofactor()
  local g = self.p256
  local cofactor = g:cofactor()
  lu.assertNotNil(cofactor)
  -- Prime256v1 has cofactor 1
  lu.assertTrue(cofactor:isone())
end

function TestGroup:testDegree()
  local g = self.p256
  local degree = g:degree()
  lu.assertEquals(degree, 256)

  local g2 = self.secp384r1
  lu.assertEquals(g2:degree(), 384)
end

function TestGroup:testCurveName()
  local g = self.p256
  local nid = g:curve_name()
  lu.assertNotNil(nid)
  lu.assertEquals(type(nid), 'number')
  lu.assertEquals(nid, 415) -- NID for prime256v1
end

function TestGroup:testAsn1Flag()
  local g = self.p256

  -- Get current flag
  local flag_str, flag_num = g:asn1_flag()
  lu.assertNotNil(flag_str)
  lu.assertNotNil(flag_num)

  -- Set flag by string
  local g2 = g:asn1_flag('explicit')
  lu.assertEquals(g2, g) -- Should return self
  local new_flag = g:asn1_flag()
  lu.assertEquals(new_flag, 'explicit')

  -- Set flag by number
  g:asn1_flag(1)
  local flag = g:asn1_flag()
  lu.assertEquals(flag, 'named_curve')
end

function TestGroup:testPointConversionForm()
  local g = self.p256

  -- Get current form
  local form_str, form_num = g:point_conversion_form()
  lu.assertNotNil(form_str)
  lu.assertNotNil(form_num)

  -- Set form by string
  g:point_conversion_form('compressed')
  local new_form = g:point_conversion_form()
  lu.assertEquals(new_form, 'compressed')

  g:point_conversion_form('uncompressed')
  local form = g:point_conversion_form()
  lu.assertEquals(form, 'uncompressed')

  g:point_conversion_form('hybrid')
  form = g:point_conversion_form()
  lu.assertEquals(form, 'hybrid')
end

function TestGroup:testCurve()
  local g = self.p256
  local curve = g:curve()

  lu.assertNotNil(curve)
  lu.assertNotNil(curve.p)
  lu.assertNotNil(curve.a)
  lu.assertNotNil(curve.b)

  -- All should be BIGNUMs
  lu.assertEquals(type(curve.p), 'userdata')
  lu.assertEquals(type(curve.a), 'userdata')
  lu.assertEquals(type(curve.b), 'userdata')
end

function TestGroup:testSeed()
  local g = self.p256
  local seed = g:seed()
  -- Seed may or may not be present depending on the curve
  -- Just verify it returns something (string or nil)
  if seed then
    lu.assertEquals(type(seed), 'string')
  end
end

function TestGroup:testParse()
  local g = self.p256
  local info = g:parse()

  lu.assertNotNil(info)
  lu.assertNotNil(info.generator)
  lu.assertNotNil(info.order)
  lu.assertNotNil(info.cofactor)
  lu.assertNotNil(info.degree)
  lu.assertEquals(info.degree, 256)
  lu.assertNotNil(info.curve_name)
  lu.assertEquals(info.curve_name, 415)
  lu.assertNotNil(info.asn1_flag)
  lu.assertNotNil(info.conversion_form)
  lu.assertNotNil(info.curve)
  lu.assertNotNil(info.curve.p)
  lu.assertNotNil(info.curve.a)
  lu.assertNotNil(info.curve.b)
end

function TestGroup:testEqual()
  local g1 = group.new('prime256v1')
  local g2 = group.new('prime256v1')
  local g3 = group.new('secp384r1')

  lu.assertTrue(g1:equal(g2))
  lu.assertFalse(g1:equal(g3))

  -- Test __eq metamethod
  lu.assertTrue(g1 == g2)
  lu.assertFalse(g1 == g3)
end

function TestGroup:testList()
  local curves = group.list()
  lu.assertNotNil(curves)
  lu.assertEquals(type(curves), 'table')

  -- Check that some well-known curves are present
  lu.assertNotNil(curves['prime256v1'])
  lu.assertNotNil(curves['secp384r1'])
  lu.assertNotNil(curves['secp521r1'])

  -- Values should be description strings
  lu.assertEquals(type(curves['prime256v1']), 'string')
end

function TestGroup:testToString()
  local g = self.p256
  local str = tostring(g)
  lu.assertNotNil(str)
  lu.assertStrContains(str, 'ec_group')
end

function TestGroup:testMultipleCurves()
  -- Test various well-known curves
  local curves = {
    'prime256v1',
    'secp256k1',
    'secp384r1',
    'secp521r1'
  }

  for _, name in ipairs(curves) do
    local g = group.new(name)
    lu.assertNotNil(g, "Failed to create group for " .. name)

    -- Verify basic properties
    local order = g:order()
    lu.assertNotNil(order)
    lu.assertTrue(order:bits() > 0)

    local gen = g:generator()
    lu.assertNotNil(gen)
  end
end

function TestGroup:testPointMethods()
  local g = self.p256
  local p1 = g:point_new()
  lu.assertNotNil(p1)
  lu.assertTrue(g:is_at_infinity(p1))

  local gen = g:generator()
  local p2 = g:point_dup(gen)
  lu.assertNotNil(p2)
  lu.assertTrue(g:point_equal(gen, p2))

  -- 不同点比较
  local inf = g:point_new()
  lu.assertFalse(g:point_equal(gen, inf))
end

function TestGroup:testGenerateKey()
  local g = self.p256
  local key = g:generate_key()
  lu.assertNotNil(key)
  lu.assertEquals(type(key), 'userdata')
end
