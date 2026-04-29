local lu = require 'luaunit'
local helper = require('helper')
local openssl = require('openssl')

-- Please read https://www.openssl.org/docs/manmaster/man3/EVP_EncryptInit.html
-- AEAD INTERFACE

local supports = openssl.cipher.list()

local function run_ccm(evp)
    --#aadcipher:key:iv:plaintext:ciphertext:aad:tag:0/1(decrypt/encrypt)
    --c17a32514eb6103f3249e076d4c871dc97e04b286699e54491dc18f6d734d4c0:2024931d73bca480c24a24ece6b6c2bf

    --aes-256-ccm:
    --1bde3251d41a8b5ea013c195ae128b218b3e0306376357077ef1c1c78548b92e:
    --5b8e40746f6b98e00f1d13ff41:
    --53bd72a97089e312422bf72e242377b3c6ee3e2075389b999c4ef7f28bd2b80a:
    --9a5fcccdb4cf04e7293d2775cc76a488f042382d949b43b7d6bb2b9864786726:
    --c17a32514eb6103f3249e076d4c871dc97e04b286699e54491dc18f6d734d4c0:
    --2024931d73bca480c24a24ece6b6c2bf
    local info = evp:info()
    local k = openssl.random(info.key_length)
    local m = openssl.random(info.key_length)
    local i = openssl.random(13)
    local tn = 12
    local tag = nil

    --encrypt
    local e = evp:encrypt_new()
    assert(e:ctrl(openssl.cipher.EVP_CTRL_GCM_SET_IVLEN, #i))
    assert(e:init(k, i))
    e:padding(false)

    local c = assert(e:update(m))
    assert(#c==#m)
    c = c .. e:final()
    assert(#c==#m)
    -- Get the tag
    tag = assert(e:ctrl(openssl.cipher.EVP_CTRL_GCM_GET_TAG, tn))
    assert(#tag==tn)

    --decrypt
    e = evp:decrypt_new()
    assert(e:ctrl(openssl.cipher.EVP_CTRL_GCM_SET_IVLEN, #i))
    assert(e:ctrl(openssl.cipher.EVP_CTRL_GCM_SET_TAG, tag))
    assert(e:init(k, i))
    e:padding(false)

    local r = assert(e:update(c))
    assert(#r==#c)
    return (r==m)
end

local function run_aead(evp, alg)
    local info = evp:info()
    local k = openssl.random(info.key_length)
    local m = openssl.random(info.key_length)
    local i = openssl.random(info.iv_length)
    local tn = 16
    local tag = tn

    --encrypt
    local e = evp:encrypt_new()
    assert(e:ctrl(openssl.cipher.EVP_CTRL_GCM_SET_IVLEN, #i))
    assert(e:init(k, i))
    e:padding(false)

    local c = assert(e:update(m))
    c = c .. e:final()
    assert(#c==#m, alg)
    -- Get the tag
    tag = assert(e:ctrl(openssl.cipher.EVP_CTRL_GCM_GET_TAG, tag))
    assert(#tag==tn)

    --decrypt
    e = evp:decrypt_new()
    assert(e:ctrl(openssl.cipher.EVP_CTRL_GCM_SET_IVLEN, #i))
    assert(e:init(k, i))
    e:padding(false)

    local r = assert(e:update(c))
    assert(e:ctrl(openssl.cipher.EVP_CTRL_GCM_SET_TAG, tag))
    r = r .. assert(e:final())
    assert(#r==#c)
    return (r==m)
end

local function run_xts(evp)
    local info = evp:info()
    local k = openssl.random(info.key_length)
    local m = openssl.random(info.key_length)
    local i = openssl.random(info.iv_length)

    local e = evp:new (true, k, i, false)
    local c = e:update(m) .. e:final()

    local d = evp:new(false, k, i, false)
    local r = d:update(c) .. d:final()
    return (r==m)
end

local function run_basic(evp, alg)
    local info = evp:info()
    local k = openssl.random(info.key_length)
    local m = openssl.random(info.block_size)
    local i = nil
    if info.iv_length > 0 then
        i = openssl.random(info.iv_length)
    end

    local e = evp:new (true, k, i, false)
    local c = e:update(m) .. e:final()
    assert(#c==#m)

    local d = evp:new(false, k, i, false)
    local r = d:update(c) .. d:final()
    return (r==m)
end

local function run(alg)
    local evp= openssl.cipher.get(alg)
    assert(evp, alg)
    local mode = alg:sub(-3, -1)

    if mode=='ccm' then
        return run_ccm(evp)
    elseif mode=='gcm' then
        return run_aead(evp, alg)
    elseif mode=='ocb' then
        return run_aead(evp, alg)
    elseif mode=='xts' then
        return run_xts(evp)
    else
        return run_basic(evp, alg)
    end
end

function testAESMode()
  for _,v in pairs(supports) do
      if(v:match('^aes.-%-...%-...$')) then
          assert(run(v), "fail to run " .. v)
      end
  end
end
