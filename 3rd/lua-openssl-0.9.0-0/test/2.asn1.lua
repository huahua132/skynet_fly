local lu = require 'luaunit'
local openssl = require 'openssl'
local asn1, hex, base64 = openssl.asn1, openssl.hex, openssl.base64

local pem =
  "MHcCAQEEINUs3GRVhC8h1y84gcW89XB9cyjUifwO3ZEH/Redb7w8oAoGCCqBHM9VAYItoUQDQgAE" ..
    "9YFSq5ZO6I+YXsIpYFzCYTcgtotrg6UW5xX8+e8arpoU5SsojLjRG1PA028kbi139zZlH2Gh/JPNiMEzRClIVg=="

local ss = base64(pem, false)
local d = {}
local first = false
local function asn1parse(s, off, last, indent)
  off = off or 1
  last = last or #s
  indent = indent or 0
  local tab = '  '
  local tag, cls, start, stop, cons
  cons, tag, cls = pcall(asn1.get_object, s, off, last)
  if not tag then
    assert(type(cls)=='string')
    return
  end

  tag, cls, start, stop, cons = asn1.get_object(s, off, last)
  assert(tag, string.format('%d-%d', off, last))

  if first then
    print(string.format('%sTAG=%s CLS=%s START=%s STOP=%s, %s',
                        string.rep(tab, indent),
                        asn1.tostring(tag, 'tag'),
                        asn1.tostring(cls, 'class'),
                        start, stop,
                        cons and "CONS" or "PRIM"))
    assert(asn1.tostring(tag, 'tag') == asn1.tostring(tag))
  end
  if cons then
    table.insert(d, asn1.put_object(tag, cls, stop - start + 1, true))
    stop = asn1parse(s, start, stop, indent + 1)
  else
    if first then
      print(string.format('%sVAL:%s', string.rep(tab, indent + 1),
                          hex(string.sub(s, start, stop))))
    end
    table.insert(d, asn1.put_object(tag, cls, string.sub(s, start, stop)))
  end

  while stop < last do stop = asn1parse(s, stop + 1, last, indent) end
  return stop
end

TestAsn1_2 = {}
function TestAsn1_2.testParse()

  assert(#ss > 0)
  -- fire error
  lu.assertErrorMsgEquals(
    "2.asn1.lua:24: bad argument #2 to 'get_object' (start out of length of asn1 string)",
    asn1parse, ss, 0)
  lu.assertErrorMsgEquals(
    "2.asn1.lua:24: bad argument #2 to 'get_object' (start out of length of asn1 string)",
    asn1parse, ss, #ss)
  lu.assertErrorMsgEquals(
    "2.asn1.lua:24: bad argument #3 to 'get_object' (stop out of length of asn1 string)",
    asn1parse, ss, 1, #ss+1)

  d = {}
  asn1parse(ss)
  local s1 = table.concat(d, '')

  lu.assertEquals(ss, s1)
  first = false
end
