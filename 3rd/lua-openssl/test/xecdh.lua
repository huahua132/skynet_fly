local lu = require("luaunit")
local openssl = require("openssl")
local pkey = openssl.pkey
local helper = require("helper")

TestXECDH = {}

function TestXECDH:setUp()
end

function TestXECDH:tearDown()
end

-- Test X25519 key generation
function TestXECDH:testX25519KeyGen()
  if not pkey.X25519 or helper.libressl then
    lu.skip("X25519 not supported on this platform")
  end
  
  -- Test key generation via context
  local ctx = assert(pkey.ctx_new("X25519"))
  local key = assert(ctx:keygen())
  
  -- Verify key properties
  assert(key:is_private())
  local info = key:parse()
  assert(info.type == "X25519")
  assert(info.bits == 253) -- X25519 reports 253 bits
  assert(info.size == 32) -- 32-byte shared secret
end

-- Test X25519 key exchange
function TestXECDH:testX25519KeyExchange()
  if not pkey.X25519 or helper.libressl then
    lu.skip("X25519 not supported on this platform")
  end
  
  -- Generate two keys
  local alice = assert(pkey.ctx_new("X25519"):keygen())
  local bob = assert(pkey.ctx_new("X25519"):keygen())
  
  -- Perform key exchange
  local alice_secret = assert(alice:derive(bob))
  local bob_secret = assert(bob:derive(alice))
  
  -- Secrets should match
  lu.assertEquals(alice_secret, bob_secret)
  lu.assertEquals(#alice_secret, 32) -- X25519 produces 32-byte secrets
end

-- Test X25519 with public keys
function TestXECDH:testX25519WithPublicKeys()
  if not pkey.X25519 or helper.libressl then
    lu.skip("X25519 not supported on this platform")
  end
  
  -- Generate keys
  local alice = assert(pkey.ctx_new("X25519"):keygen())
  local bob = assert(pkey.ctx_new("X25519"):keygen())
  
  -- Get public keys
  local alice_pub = assert(pkey.get_public(alice))
  local bob_pub = assert(pkey.get_public(bob))
  
  -- Verify public keys are not private
  assert(not alice_pub:is_private())
  assert(not bob_pub:is_private())
  
  -- Perform key exchange with public keys
  local alice_secret = assert(alice:derive(bob_pub))
  local bob_secret = assert(bob:derive(alice_pub))
  
  -- Secrets should match
  lu.assertEquals(alice_secret, bob_secret)
end

-- Test X25519 PEM export/import
function TestXECDH:testX25519PEMExport()
  if not pkey.X25519 or helper.libressl then
    lu.skip("X25519 not supported on this platform")
  end
  
  -- Generate key
  local key = assert(pkey.ctx_new("X25519"):keygen())
  
  -- Export private key
  local pem = assert(key:export("pem"))
  assert(type(pem) == "string")
  assert(pem:match("^%-%-%-%-%-BEGIN"))
  
  -- Import private key
  local key2 = assert(pkey.read(pem, true, "pem"))
  assert(key2:is_private())
  
  -- Verify keys are equivalent by deriving same secret
  local peer = assert(pkey.ctx_new("X25519"):keygen())
  local secret1 = assert(key:derive(peer))
  local secret2 = assert(key2:derive(peer))
  lu.assertEquals(secret1, secret2)
  
  -- Export and import public key
  local pubkey = assert(pkey.get_public(key))
  local pub_pem = assert(pubkey:export("pem"))
  assert(type(pub_pem) == "string")
  assert(pub_pem:match("^%-%-%-%-%-BEGIN PUBLIC KEY"))
  
  local pubkey2 = assert(pkey.read(pub_pem, false, "pem"))
  assert(not pubkey2:is_private())
end

-- Test X25519 DER export/import
function TestXECDH:testX25519DERExport()
  if not pkey.X25519 or helper.libressl then
    lu.skip("X25519 not supported on this platform")
  end
  
  -- Generate key
  local key = assert(pkey.ctx_new("X25519"):keygen())
  
  -- Export in DER format
  local der = assert(key:export("der"))
  assert(type(der) == "string")
  assert(#der > 0)
  
  -- Import from DER
  local key2 = assert(pkey.read(der, true, "der"))
  assert(key2:is_private())
  
  -- Verify keys work
  local peer = assert(pkey.ctx_new("X25519"):keygen())
  local secret1 = assert(key:derive(peer))
  local secret2 = assert(key2:derive(peer))
  lu.assertEquals(secret1, secret2)
end

-- Test X448 key generation
function TestXECDH:testX448KeyGen()
  if not pkey.X448 or helper.libressl then
    lu.skip("X448 not supported on this platform")
  end
  
  -- Test key generation via context
  local ctx = assert(pkey.ctx_new("X448"))
  local key = assert(ctx:keygen())
  
  -- Verify key properties
  assert(key:is_private())
  local info = key:parse()
  assert(info.type == "X448")
  assert(info.bits == 448) -- X448 reports 448 bits
  assert(info.size == 56) -- 56-byte shared secret
end

-- Test X448 key exchange
function TestXECDH:testX448KeyExchange()
  if not pkey.X448 or helper.libressl then
    lu.skip("X448 not supported on this platform")
  end
  
  -- Generate two keys
  local alice = assert(pkey.ctx_new("X448"):keygen())
  local bob = assert(pkey.ctx_new("X448"):keygen())
  
  -- Perform key exchange
  local alice_secret = assert(alice:derive(bob))
  local bob_secret = assert(bob:derive(alice))
  
  -- Secrets should match
  lu.assertEquals(alice_secret, bob_secret)
  lu.assertEquals(#alice_secret, 56) -- X448 produces 56-byte secrets
end

-- Test X448 with public keys
function TestXECDH:testX448WithPublicKeys()
  if not pkey.X448 or helper.libressl then
    lu.skip("X448 not supported on this platform")
  end
  
  -- Generate keys
  local alice = assert(pkey.ctx_new("X448"):keygen())
  local bob = assert(pkey.ctx_new("X448"):keygen())
  
  -- Get public keys
  local alice_pub = assert(pkey.get_public(alice))
  local bob_pub = assert(pkey.get_public(bob))
  
  -- Perform key exchange with public keys
  local alice_secret = assert(alice:derive(bob_pub))
  local bob_secret = assert(bob:derive(alice_pub))
  
  -- Secrets should match
  lu.assertEquals(alice_secret, bob_secret)
end

-- Test X448 PEM export/import
function TestXECDH:testX448PEMExport()
  if not pkey.X448 or helper.libressl then
    lu.skip("X448 not supported on this platform")
  end
  
  -- Generate key
  local key = assert(pkey.ctx_new("X448"):keygen())
  
  -- Export and import private key
  local pem = assert(key:export("pem"))
  assert(type(pem) == "string")
  local key2 = assert(pkey.read(pem, true, "pem"))
  assert(key2:is_private())
  
  -- Verify keys work
  local peer = assert(pkey.ctx_new("X448"):keygen())
  local secret1 = assert(key:derive(peer))
  local secret2 = assert(key2:derive(peer))
  lu.assertEquals(secret1, secret2)
  
  -- Export and import public key
  local pubkey = assert(pkey.get_public(key))
  local pub_pem = assert(pubkey:export("pem"))
  local pubkey2 = assert(pkey.read(pub_pem, false, "pem"))
  assert(not pubkey2:is_private())
end

-- Test multiple X25519 key exchanges
function TestXECDH:testX25519MultipleExchanges()
  if not pkey.X25519 or helper.libressl then
    lu.skip("X25519 not supported on this platform")
  end
  
  -- Generate three keys
  local alice = assert(pkey.ctx_new("X25519"):keygen())
  local bob = assert(pkey.ctx_new("X25519"):keygen())
  local charlie = assert(pkey.ctx_new("X25519"):keygen())
  
  -- Perform multiple exchanges
  local alice_bob = assert(alice:derive(bob))
  local bob_alice = assert(bob:derive(alice))
  local alice_charlie = assert(alice:derive(charlie))
  local charlie_alice = assert(charlie:derive(alice))
  local bob_charlie = assert(bob:derive(charlie))
  local charlie_bob = assert(charlie:derive(bob))
  
  -- Verify pairs match
  lu.assertEquals(alice_bob, bob_alice)
  lu.assertEquals(alice_charlie, charlie_alice)
  lu.assertEquals(bob_charlie, charlie_bob)
  
  -- Verify different pairs produce different secrets
  assert(alice_bob ~= alice_charlie)
  assert(alice_bob ~= bob_charlie)
  assert(alice_charlie ~= bob_charlie)
end

-- Test X25519 deterministic key exchange
function TestXECDH:testX25519Deterministic()
  if not pkey.X25519 or helper.libressl then
    lu.skip("X25519 not supported on this platform")
  end
  
  -- Generate keys
  local alice = assert(pkey.ctx_new("X25519"):keygen())
  local bob = assert(pkey.ctx_new("X25519"):keygen())
  
  -- Perform exchange multiple times
  local secret1 = assert(alice:derive(bob))
  local secret2 = assert(alice:derive(bob))
  local secret3 = assert(alice:derive(bob))
  
  -- All secrets should be identical (deterministic)
  lu.assertEquals(secret1, secret2)
  lu.assertEquals(secret2, secret3)
end

os.exit(lu.LuaUnit.run())
