local lu = require 'luaunit'

local openssl = require 'openssl'
local mac = require'openssl'.mac
if not mac then
  return
end

TestMAC = {}
function TestMAC:setUp()
  self.msg = '\x00\x01\x02\x03\x04\x05\x06\x07\x08\x09\x0A\x0B\x0C\x0D\x0E\x0F'
  self.alg = 'aes-128-cbc'
  self.key = '\x0F\x0E\x0D\x0C\x0B\x0A\x00\x08\x07\x06\x05\x04\x03\x02\x01\x00'
end

function TestMAC:tearDown()
end

function TestMAC:testCMAC()
  local a, b ,c, err

  openssl.clear_error()
  a, err = mac.ctx(self.alg, self.key)
  if a then
    b = a:final(self.msg)
    lu.assertEquals(b, '21a805600f5a650854142d7ec00a4224')

    c = a:final(self.msg, true)
    assert(c, openssl.hex(b))
  else
    print("Bugs, " .. err)
  end

end
