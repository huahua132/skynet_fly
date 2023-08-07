local openssl = require 'openssl'
local rsa = require'openssl'.rsa
local helper = require'helper'

local function checkRSA(r, c)
  local t = r:parse()
  for _,v in pairs(t) do
    if type(v)=='userdata' then
      if (c)  then print(_, v:bits()) end
      if _=='q' or _=='p' or _=='dmp1' or _=='dmq1' or _=='iqmp' then
        if (v:bits() ~= t.bits/2) then
          print(_, v:bits(), t.bits/2)
          return false
        end
      elseif _=='d' and v:bits() ~= t.bits then
        print(_, v:bits(), t.bits)
        return false
      elseif (_~='e' and v:bits()+7 < t.bits) then
        print(_, v:bits(), t.bits)
        return false
      end
    end
  end
  return true
end

TestRSA = {}
function TestRSA:TestRSA()
  local k = rsa.generate_key(2048)
  --repeat
  --  k= rsa.generate_key(2048)
  --until checkRSA(k)

  assert(k:isprivate())

  local t = k:parse()
  assert(t.bits == 2048)
  assert(t.size == 256)

  if rsa.encrypt then
    assert(k:size()==256)

    local padding = {
      "sslv23",
      "pkcs1",
      'x931',
      'pss',
      "oaep",
      "no"
    }

    k:set_engine(openssl.engine('openssl'))

    for _=1, #padding+1 do
      local pad = padding[_]
      local msg = string.char(0) .. openssl.random(pad=='no' and 255 or 200)

      local out, raw
      if pad~='oaep' and pad~='sslv23' and pad~='pss' then
        local n = openssl.bn.text(msg)
        assert(n:bits() <  t.n:bits())
        out = assert(rsa.encrypt(k, msg, pad, true), pad)
        raw = assert(k:decrypt(out, pad, false))
        assert(msg == raw)
      end

      if pad~='sslv23' and pad~='x931' and pad~='pss' then
        out = assert(rsa.encrypt(k,msg, pad, false), pad)
        raw = assert(k:decrypt(out, pad, true))
        assert(msg == raw)
      end

      msg = openssl.random(32)
      out = assert(rsa.sign(k, msg, 'sha256'))
      assert(k:verify(msg, out, 'sha256'))
    end
  end

  local der = k:export()
  assert(rsa.read(der))

  der = k:export(false)
  k = rsa.read(der, false)
  assert(not k:isprivate())
end

function TestRSA:TestPad_pkcs1()
  if helper.libressl then
    print("\tskip")
    return
  end
  local msg = openssl.random(128)
  local padded = rsa.padding_add(msg, 'pkcs1', 256, true)
  local raw = rsa.padding_check(padded, 'pkcs1', 256, true)
  assert(msg==raw)

  padded = rsa.padding_add(msg,'pkcs1', 256, false)
  raw = rsa.padding_check(padded, 'pkcs1', 256, false)
  assert(msg==raw)
end

function TestRSA:TestPad_none()
  local msg = openssl.random(256)
  local padded = rsa.padding_add(msg,'no', 256)
  local raw = rsa.padding_check(padded, 'no', 256)
  assert(msg==raw)
end

function TestRSA:TestPad_oaep()
  local msg = openssl.random(128)
  local padded = rsa.padding_add(msg,'oaep', 256)
  local raw = rsa.padding_check(padded, 'oaep', 256)
  assert(msg==raw)

  padded = rsa.padding_add(msg,'oaep', 256, 'abcd')
  raw = rsa.padding_check(padded, 'oaep', 256, 'abcd')
  assert(msg==raw)

  padded = rsa.padding_add(msg,'oaep', 256, 'abcd', 'sha1')
  raw = rsa.padding_check(padded, 'oaep', 256, 'abcd', 'sha1')
  assert(msg==raw)

  padded = rsa.padding_add(msg,'oaep', 256, 'abcd', 'sha256')
  raw = rsa.padding_check(padded, 'oaep', 256, 'abcd', 'sha256')
  assert(msg==raw)
end

function TestRSA:TestOAEP_encrypt()
  local k = rsa.generate_key(2048)
  assert(k:isprivate())

  local t = k:parse()
  assert(t.bits == 2048)
  assert(t.size == 256)

  local msg = openssl.random(128)
  local padded = rsa.padding_add(msg,'oaep', 256)

  local encrypted = assert(rsa.encrypt(k, padded, 'no', false)) -- Public Encrypt
  local plain = assert(k:decrypt(encrypted, 'no', true))  -- Private Decrypt

  assert(plain==padded)
  local raw = rsa.padding_check(padded, 'oaep', 256)
  assert(msg==raw)

end
