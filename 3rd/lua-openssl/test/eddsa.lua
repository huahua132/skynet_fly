local lu = require("luaunit")
local openssl = require("openssl")
local pkey = openssl.pkey
local digest = openssl.digest
local helper = require("helper")

TestEdDSA = {}

function TestEdDSA:setUp()
  self.msg = "The quick brown fox jumps over the lazy dog"
end

function TestEdDSA:tearDown()
end

-- Test Ed25519 key generation
function TestEdDSA:testEd25519KeyGen()
  if not pkey.ED25519 or helper.libressl then
    lu.skip("Ed25519 not supported on this platform")
  end
  
  -- Test key generation via context
  local ctx = assert(pkey.ctx_new("ED25519"))
  local key = assert(ctx:keygen())
  
  -- Verify key properties
  assert(key:is_private())
  local info = key:parse()
  assert(info.type == "ED25519")
  assert(info.bits == 256) -- Ed25519 reports 256 bits in OpenSSL
end

-- Test Ed25519 signature and verification
function TestEdDSA:testEd25519SignVerify()
  if not pkey.ED25519 or helper.libressl then
    lu.skip("Ed25519 not supported on this platform")
  end
  
  -- Generate key
  local ctx = assert(pkey.ctx_new("ED25519"))
  local key = assert(ctx:keygen())
  
  -- Sign message
  local sig = assert(pkey.sign(key, self.msg))
  assert(#sig > 0)
  
  -- Verify signature with private key
  assert(pkey.verify(key, self.msg, sig))
  
  -- Get public key and verify
  local pubkey = assert(pkey.get_public(key))
  assert(not pubkey:is_private())
  assert(pkey.verify(pubkey, self.msg, sig))
  
  -- Verify wrong message fails
  assert(not pkey.verify(pubkey, "wrong message", sig))
end

-- Test Ed25519 digest-based signing
function TestEdDSA:testEd25519DigestSign()
  if not pkey.ED25519 or helper.libressl then
    lu.skip("Ed25519 not supported on this platform")
  end
  
  -- Generate key
  local ctx = assert(pkey.ctx_new("ED25519"))
  local key = assert(ctx:keygen())
  
  -- Sign using digest context
  local sctx = assert(digest.signInit(nil, key))
  local sig = assert(sctx:sign(self.msg))
  
  -- Verify using digest context
  local vctx = assert(digest.verifyInit(nil, key))
  assert(vctx:verify(sig, self.msg))
end

-- Test Ed25519 PEM export/import
function TestEdDSA:testEd25519PEMExport()
  if not pkey.ED25519 or helper.libressl then
    lu.skip("Ed25519 not supported on this platform")
  end
  
  -- Generate key
  local ctx = assert(pkey.ctx_new("ED25519"))
  local key = assert(ctx:keygen())
  
  -- Export private key
  local pem = assert(key:export("pem"))
  assert(type(pem) == "string")
  assert(pem:match("^%-%-%-%-%-BEGIN"))
  
  -- Import private key
  local key2 = assert(pkey.read(pem, true, "pem"))
  assert(key2:is_private())
  
  -- Verify keys are equivalent by signing/verifying
  local sig = assert(pkey.sign(key, self.msg))
  assert(pkey.verify(key2, self.msg, sig))
  
  -- Export public key
  local pubkey = assert(pkey.get_public(key))
  local pub_pem = assert(pubkey:export("pem"))
  assert(type(pub_pem) == "string")
  assert(pub_pem:match("^%-%-%-%-%-BEGIN PUBLIC KEY"))
  
  -- Import public key (false = public key, not private)
  local pubkey2 = assert(pkey.read(pub_pem, false, "pem"))
  assert(not pubkey2:is_private())
  assert(pkey.verify(pubkey2, self.msg, sig))
end

-- Test Ed25519 DER export/import
function TestEdDSA:testEd25519DERExport()
  if not pkey.ED25519 or helper.libressl then
    lu.skip("Ed25519 not supported on this platform")
  end
  
  -- Generate key
  local ctx = assert(pkey.ctx_new("ED25519"))
  local key = assert(ctx:keygen())
  
  -- Export in DER format
  local der = assert(key:export("der"))
  assert(type(der) == "string")
  assert(#der > 0)
  
  -- Import from DER
  local key2 = assert(pkey.read(der, true, "der"))
  assert(key2:is_private())
  
  -- Verify keys work
  local sig = assert(pkey.sign(key, self.msg))
  assert(pkey.verify(key2, self.msg, sig))
end

-- Test Ed448 key generation
function TestEdDSA:testEd448KeyGen()
  if not pkey.ED448 or helper.libressl then
    lu.skip("Ed448 not supported on this platform")
  end
  
  -- Test key generation via context
  local ctx = assert(pkey.ctx_new("ED448"))
  local key = assert(ctx:keygen())
  
  -- Verify key properties
  assert(key:is_private())
  local info = key:parse()
  assert(info.type == "ED448")
  assert(info.bits == 456) -- Ed448 reports 456 bits in OpenSSL
end

-- Test Ed448 signature and verification
function TestEdDSA:testEd448SignVerify()
  if not pkey.ED448 or helper.libressl then
    lu.skip("Ed448 not supported on this platform")
  end
  
  -- Generate key
  local ctx = assert(pkey.ctx_new("ED448"))
  local key = assert(ctx:keygen())
  
  -- Sign message
  local sig = assert(pkey.sign(key, self.msg))
  assert(#sig > 0)
  
  -- Verify signature
  assert(pkey.verify(key, self.msg, sig))
  
  -- Get public key and verify
  local pubkey = assert(pkey.get_public(key))
  assert(not pubkey:is_private())
  assert(pkey.verify(pubkey, self.msg, sig))
  
  -- Verify wrong message fails
  assert(not pkey.verify(pubkey, "wrong message", sig))
end

-- Test Ed448 digest-based signing
function TestEdDSA:testEd448DigestSign()
  if not pkey.ED448 or helper.libressl then
    lu.skip("Ed448 not supported on this platform")
  end
  
  -- Generate key
  local ctx = assert(pkey.ctx_new("ED448"))
  local key = assert(ctx:keygen())
  
  -- Sign using digest context
  local sctx = assert(digest.signInit(nil, key))
  local sig = assert(sctx:sign(self.msg))
  
  -- Verify using digest context
  local vctx = assert(digest.verifyInit(nil, key))
  assert(vctx:verify(sig, self.msg))
end

-- Test Ed448 PEM export/import
function TestEdDSA:testEd448PEMExport()
  if not pkey.ED448 or helper.libressl then
    lu.skip("Ed448 not supported on this platform")
  end
  
  -- Generate key
  local ctx = assert(pkey.ctx_new("ED448"))
  local key = assert(ctx:keygen())
  
  -- Export and import private key
  local pem = assert(key:export("pem"))
  assert(type(pem) == "string")
  local key2 = assert(pkey.read(pem, true, "pem"))
  assert(key2:is_private())
  
  -- Verify keys work
  local sig = assert(pkey.sign(key, self.msg))
  assert(pkey.verify(key2, self.msg, sig))
  
  -- Export and import public key
  local pubkey = assert(pkey.get_public(key))
  local pub_pem = assert(pubkey:export("pem"))
  local pubkey2 = assert(pkey.read(pub_pem, false, "pem"))  -- false = public key
  assert(not pubkey2:is_private())
  assert(pkey.verify(pubkey2, self.msg, sig))
end

-- Test Ed25519 with empty message
function TestEdDSA:testEd25519EmptyMessage()
  if not pkey.ED25519 or helper.libressl then
    lu.skip("Ed25519 not supported on this platform")
  end
  
  local ctx = assert(pkey.ctx_new("ED25519"))
  local key = assert(ctx:keygen())
  
  -- Sign and verify empty string
  local sig = assert(pkey.sign(key, ""))
  assert(pkey.verify(key, "", sig))
end

-- Test Ed25519 with large message
function TestEdDSA:testEd25519LargeMessage()
  if not pkey.ED25519 or helper.libressl then
    lu.skip("Ed25519 not supported on this platform")
  end
  
  local ctx = assert(pkey.ctx_new("ED25519"))
  local key = assert(ctx:keygen())
  
  -- Create a large message (1MB)
  local large_msg = string.rep("a", 1024 * 1024)
  
  -- Sign and verify
  local sig = assert(pkey.sign(key, large_msg))
  assert(pkey.verify(key, large_msg, sig))
end

-- Test multiple signatures with same key
function TestEdDSA:testEd25519MultipleSignatures()
  if not pkey.ED25519 or helper.libressl then
    lu.skip("Ed25519 not supported on this platform")
  end
  
  local ctx = assert(pkey.ctx_new("ED25519"))
  local key = assert(ctx:keygen())
  
  -- Sign multiple messages
  local messages = {"message1", "message2", "message3"}
  local signatures = {}
  
  for i, msg in ipairs(messages) do
    signatures[i] = assert(pkey.sign(key, msg))
  end
  
  -- Verify all signatures
  for i, msg in ipairs(messages) do
    assert(pkey.verify(key, msg, signatures[i]))
  end
  
  -- Verify cross-verification fails
  assert(not pkey.verify(key, messages[1], signatures[2]))
end

os.exit(lu.LuaUnit.run())
