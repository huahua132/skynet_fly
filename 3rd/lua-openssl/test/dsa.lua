local openssl = require("openssl")
local dsa = require("openssl").dsa
local helper = require("helper")

TestDSA = {}
function TestDSA:Testdsa()
  local k = dsa.generate_key(1024)

  local t = k:parse()
  assert(t.bits == 1024)

  if openssl.engine then
    local eng = openssl.engine("openssl")
    if eng then
      k:set_engine(eng)
    end
  end
end
