local lu = require("luaunit")
local openssl = require("openssl")
local group = openssl.ec.group
local point = openssl.ec.point
local bn = openssl.bn

TestPoint = {}

function TestPoint:setUp()
  -- Set up common test group
  self.g = group.new('prime256v1')
end

function TestPoint:testNew()
  local g = self.g
  local p = point.new(g)
  lu.assertNotNil(p)

  -- New point should be at infinity
  lu.assertTrue(point.is_at_infinity(g, p))
end

function TestPoint:testDup()
  local g = self.g
  local gen = g:generator()
  local p2 = point.dup(g, gen)

  lu.assertNotNil(p2)
  lu.assertTrue(point.equal(g, gen, p2))
end

function TestPoint:testCopy()
  local g = self.g
  local gen = g:generator()
  local p = point.new(g)

  p:copy(gen)
  lu.assertTrue(point.equal(g, p, gen))
end

function TestPoint:testSetToInfinity()
  local g = self.g
  local gen = g:generator()

  lu.assertFalse(point.is_at_infinity(g, gen))

  point.set_to_infinity(g, gen)
  lu.assertTrue(point.is_at_infinity(g, gen))
end

function TestPoint:testIsAtInfinity()
  local g = self.g
  local p = point.new(g)

  lu.assertTrue(point.is_at_infinity(g, p))

  -- Get generator (not at infinity)
  local gen = g:generator()
  lu.assertFalse(point.is_at_infinity(g, gen))
end

function TestPoint:testIsOnCurve()
  local g = self.g
  local gen = g:generator()

  -- Generator should be on the curve
  lu.assertTrue(point.is_on_curve(g, gen))

  -- Point at infinity should also be "on the curve"
  local p = point.new(g)
  lu.assertTrue(point.is_on_curve(g, p))
end

function TestPoint:testEqual()
  local g = self.g
  local gen = g:generator()
  local p = point.dup(g, gen)

  lu.assertTrue(point.equal(g, gen, p))

  -- Point at infinity
  local inf1 = point.new(g)
  local inf2 = point.new(g)
  lu.assertTrue(point.equal(g, inf1, inf2))

  -- Different points
  lu.assertFalse(point.equal(g, gen, inf1))
end

function TestPoint:testAffineCoordinates()
  local g = self.g
  local gen = g:generator()

  -- Get coordinates
  local x, y = point.affine_coordinates(g, gen)
  lu.assertNotNil(x)
  lu.assertNotNil(y)
  lu.assertEquals(type(x), 'userdata')
  lu.assertEquals(type(y), 'userdata')

  -- Create a new point and set coordinates
  local p = point.new(g)
  point.affine_coordinates(g, p, x, y)

  -- Verify it equals the generator
  lu.assertTrue(point.equal(g, p, gen))
end

function TestPoint:testAdd()
  local g = self.g
  local gen = g:generator()

  -- Add generator to itself
  local p = point.add(g, gen, gen)
  lu.assertNotNil(p)
  lu.assertTrue(point.is_on_curve(g, p))

  -- Adding point to infinity should return the point
  local inf = point.new(g)
  local p2 = point.add(g, gen, inf)
  lu.assertTrue(point.equal(g, p2, gen))
end

function TestPoint:testDbl()
  local g = self.g
  local gen = g:generator()

  -- Double the generator
  local p = point.dbl(g, gen)
  lu.assertNotNil(p)
  lu.assertTrue(point.is_on_curve(g, p))

  -- Should equal generator + generator
  local p2 = point.add(g, gen, gen)
  lu.assertTrue(point.equal(g, p, p2))
end

function TestPoint:testInvert()
  local g = self.g
  local gen = g:generator()

  -- Invert the generator
  local neg_gen = point.dup(g, gen)
  point.invert(g, neg_gen)

  lu.assertTrue(point.is_on_curve(g, neg_gen))

  -- Adding point and its inverse should give infinity
  local inf = point.add(g, gen, neg_gen)
  lu.assertTrue(point.is_at_infinity(g, inf))
end

function TestPoint:testMul()
  local g = self.g
  local gen = g:generator()

  -- Multiply by scalar
  local n = bn.number(2)
  local p = point.mul(g, gen, n)

  lu.assertNotNil(p)
  lu.assertTrue(point.is_on_curve(g, p))

  -- Should equal doubling
  local p2 = point.dbl(g, gen)
  lu.assertTrue(point.equal(g, p, p2))

  -- Multiply by order should give infinity
  local order = g:order()
  local inf = point.mul(g, gen, order)
  lu.assertTrue(point.is_at_infinity(g, inf))
end

function TestPoint:testMulWithNumber()
  local g = self.g
  local gen = g:generator()

  -- Multiply by number
  local p = point.mul(g, gen, 3)
  lu.assertNotNil(p)
  lu.assertTrue(point.is_on_curve(g, p))

  -- Should equal gen + gen + gen
  local p2 = point.add(g, gen, gen)
  p2 = point.add(g, p2, gen)
  lu.assertTrue(point.equal(g, p, p2))
end

function TestPoint:testOct2Point()
  local g = self.g
  local gen = g:generator()

  -- Convert to octet string
  local oct = point.point2oct(g, gen)
  lu.assertNotNil(oct)
  lu.assertEquals(type(oct), 'string')

  -- Convert back to point
  local p = point.oct2point(g, oct)
  lu.assertNotNil(p)
  lu.assertTrue(point.equal(g, p, gen))
end

function TestPoint:testPoint2Oct()
  local g = self.g
  local gen = g:generator()

  -- Test different conversion forms
  local forms = {'compressed', 'uncompressed', 'hybrid'}

  for _, form in ipairs(forms) do
    local oct = point.point2oct(g, gen, form)
    lu.assertNotNil(oct, "Failed for form " .. form)
    lu.assertEquals(type(oct), 'string')

    -- Convert back and verify
    local p = point.oct2point(g, oct)
    lu.assertTrue(point.equal(g, p, gen))
  end
end

function TestPoint:testBn2Point()
  local g = self.g
  local gen = g:generator()

  -- Convert to BIGNUM
  local bn_val = point.point2bn(g, gen)
  lu.assertNotNil(bn_val)

  -- Convert back to point
  local p = point.bn2point(g, bn_val)
  lu.assertNotNil(p)
  lu.assertTrue(point.equal(g, p, gen))
end

function TestPoint:testPoint2Bn()
  local g = self.g
  local gen = g:generator()

  -- Test different conversion forms
  local forms = {'compressed', 'uncompressed'}

  for _, form in ipairs(forms) do
    local bn_val = point.point2bn(g, gen, form)
    lu.assertNotNil(bn_val, "Failed for form " .. form)

    -- Convert back and verify
    local p = point.bn2point(g, bn_val)
    lu.assertTrue(point.equal(g, p, gen))
  end
end

function TestPoint:testHex2Point()
  local g = self.g
  local gen = g:generator()

  -- Convert to hex
  local hex = point.point2hex(g, gen)
  lu.assertNotNil(hex)
  lu.assertEquals(type(hex), 'string')

  -- Convert back to point
  local p = point.hex2point(g, hex)
  lu.assertNotNil(p)
  lu.assertTrue(point.equal(g, p, gen))
end

function TestPoint:testPoint2Hex()
  local g = self.g
  local gen = g:generator()

  -- Test different conversion forms
  local forms = {'compressed', 'uncompressed', 'hybrid'}

  for _, form in ipairs(forms) do
    local hex = point.point2hex(g, gen, form)
    lu.assertNotNil(hex, "Failed for form " .. form)
    lu.assertEquals(type(hex), 'string')

    -- Convert back and verify
    local p = point.hex2point(g, hex)
    lu.assertTrue(point.equal(g, p, gen))
  end
end

function TestPoint:testToString()
  local g = self.g
  local p = point.new(g)
  local str = tostring(p)

  lu.assertNotNil(str)
  lu.assertStrContains(str, 'ec_point')
end

function TestPoint:testScalarMultiplication()
  local g = self.g
  local gen = g:generator()

  -- Test various scalar multiplications
  for i = 1, 5 do
    local n = bn.number(i)
    local p = point.mul(g, gen, n)

    lu.assertNotNil(p)
    lu.assertTrue(point.is_on_curve(g, p))

    -- Verify by adding repeatedly
    local expected = point.dup(g, gen)
    for j = 2, i do
      expected = point.add(g, expected, gen)
    end

    lu.assertTrue(point.equal(g, p, expected))
  end
end

function TestPoint:testPointAdditionCommutative()
  local g = self.g
  local gen = g:generator()
  local two_gen = point.mul(g, gen, 2)
  local three_gen = point.mul(g, gen, 3)

  -- Test commutativity: P + Q = Q + P
  local p1 = point.add(g, two_gen, three_gen)
  local p2 = point.add(g, three_gen, two_gen)

  lu.assertTrue(point.equal(g, p1, p2))
end

function TestPoint:testPointMulWithNegNumber()
  local g = self.g

  local gen = g:generator()
  local negGen = point.mul(g, gen, -1)
  local should_be_zero = point.add(g, gen, negGen)
  assert(point.is_at_infinity(g, should_be_zero))
  local s = g:point2hex(should_be_zero)
  assert("00" == s or "0" == s, s)
end

function TestPoint:testPointAdditionAssociative()
  local g = self.g
  local gen = g:generator()
  local two_gen = point.mul(g, gen, 2)
  local three_gen = point.mul(g, gen, 3)

  -- Test associativity: (P + Q) + R = P + (Q + R)
  local p1 = point.add(g, gen, two_gen)
  p1 = point.add(g, p1, three_gen)

  local p2 = point.add(g, two_gen, three_gen)
  p2 = point.add(g, gen, p2)

  lu.assertTrue(point.equal(g, p1, p2))
end

