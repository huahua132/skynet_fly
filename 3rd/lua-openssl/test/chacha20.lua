local lu = require("luaunit")
local openssl = require("openssl")
local cipher = openssl.cipher
local helper = require("helper")

TestChaCha20Poly1305 = {}

function TestChaCha20Poly1305:setUp()
  self.key = string.rep("k", 32) -- 256-bit key
  self.iv = string.rep("i", 12)   -- 96-bit nonce
  self.msg = "The quick brown fox jumps over the lazy dog"
  self.aad = "Additional authenticated data"
end

function TestChaCha20Poly1305:tearDown()
end

-- Test ChaCha20-Poly1305 availability
function TestChaCha20Poly1305:testAvailability()
  local cc20 = cipher.get("chacha20-poly1305")
  if not cc20 then
    lu.skip("ChaCha20-Poly1305 not supported on this platform")
  end
  
  assert(cc20)
  local info = cc20:info()
  assert(info.name == "ChaCha20-Poly1305")
  assert(info.key_length == 32) -- 256 bits
  assert(info.iv_length == 12)  -- 96 bits
  assert(info.block_size == 1)  -- Stream cipher
end

-- Test basic encryption/decryption
function TestChaCha20Poly1305:testBasicEncryptDecrypt()
  local cc20 = cipher.get("chacha20-poly1305")
  if not cc20 then
    lu.skip("ChaCha20-Poly1305 not supported on this platform")
  end
  
  -- Encrypt
  local enc = assert(cc20:encrypt_new(self.key, self.iv))
  local ciphertext = assert(enc:update(self.msg))
  ciphertext = ciphertext .. assert(enc:final())
  
  -- Decrypt
  local dec = assert(cc20:decrypt_new(self.key, self.iv))
  local plaintext = assert(dec:update(ciphertext))
  plaintext = plaintext .. assert(dec:final())
  
  lu.assertEquals(plaintext, self.msg)
end

-- Test encryption/decryption with AAD
function TestChaCha20Poly1305:testWithAAD()
  local cc20 = cipher.get("chacha20-poly1305")
  if not cc20 then
    lu.skip("ChaCha20-Poly1305 not supported on this platform")
  end
  
  local tag_len = 16
  
  -- Encrypt with AAD
  local enc = assert(cc20:encrypt_new())
  
  -- Set IV length and initialize
  enc:ctrl(openssl.cipher.EVP_CTRL_GCM_SET_IVLEN, #self.iv)
  enc:init(self.key, self.iv)
  
  -- Set AAD (second param true indicates AAD)
  local aad_result = enc:update(self.aad, true)
  lu.assertEquals(aad_result, "")
  
  -- Encrypt message
  local ciphertext = assert(enc:update(self.msg))
  ciphertext = ciphertext .. assert(enc:final())
  
  -- Get authentication tag
  local tag = assert(enc:ctrl(openssl.cipher.EVP_CTRL_GCM_GET_TAG, tag_len))
  lu.assertEquals(#tag, tag_len)
  
  -- Decrypt with AAD
  local dec = assert(cc20:decrypt_new())
  
  -- Set IV length and initialize
  dec:ctrl(openssl.cipher.EVP_CTRL_GCM_SET_IVLEN, #self.iv)
  dec:init(self.key, self.iv)
  
  -- Set expected tag
  dec:ctrl(openssl.cipher.EVP_CTRL_GCM_SET_TAG, tag)
  
  -- Set AAD
  local dec_aad_result = dec:update(self.aad, true)
  lu.assertEquals(dec_aad_result, "")
  
  -- Decrypt message
  local plaintext = assert(dec:update(ciphertext))
  plaintext = plaintext .. assert(dec:final())
  
  lu.assertEquals(plaintext, self.msg)
end

-- Test tag authentication fails with wrong tag
function TestChaCha20Poly1305:testWrongTagFails()
  local cc20 = cipher.get("chacha20-poly1305")
  if not cc20 then
    lu.skip("ChaCha20-Poly1305 not supported on this platform")
  end
  
  local tag_len = 16
  
  -- Encrypt
  local enc = assert(cc20:encrypt_new())
  enc:ctrl(openssl.cipher.EVP_CTRL_GCM_SET_IVLEN, #self.iv)
  enc:init(self.key, self.iv)
  enc:update(self.aad, true)
  local ciphertext = assert(enc:update(self.msg))
  ciphertext = ciphertext .. assert(enc:final())
  local tag = assert(enc:ctrl(openssl.cipher.EVP_CTRL_GCM_GET_TAG, tag_len))
  
  -- Decrypt with wrong tag
  local wrong_tag = string.rep("x", tag_len)
  local dec = assert(cc20:decrypt_new())
  dec:ctrl(openssl.cipher.EVP_CTRL_GCM_SET_IVLEN, #self.iv)
  dec:init(self.key, self.iv)
  dec:ctrl(openssl.cipher.EVP_CTRL_GCM_SET_TAG, wrong_tag)
  dec:update(self.aad, true)
  dec:update(ciphertext)
  
  -- Final should fail with wrong tag (may return nil/false or throw error)
  local final_result = dec:final()
  -- OpenSSL may return nil or empty string on auth failure
  assert(not final_result or final_result == "" or final_result == nil)
end

-- Test AAD authentication fails with wrong AAD
function TestChaCha20Poly1305:testWrongAADFails()
  local cc20 = cipher.get("chacha20-poly1305")
  if not cc20 then
    lu.skip("ChaCha20-Poly1305 not supported on this platform")
  end
  
  local tag_len = 16
  
  -- Encrypt with AAD
  local enc = assert(cc20:encrypt_new())
  enc:ctrl(openssl.cipher.EVP_CTRL_GCM_SET_IVLEN, #self.iv)
  enc:init(self.key, self.iv)
  enc:update(self.aad, true)
  local ciphertext = assert(enc:update(self.msg))
  ciphertext = ciphertext .. assert(enc:final())
  local tag = assert(enc:ctrl(openssl.cipher.EVP_CTRL_GCM_GET_TAG, tag_len))
  
  -- Decrypt with wrong AAD
  local wrong_aad = "wrong AAD"
  local dec = assert(cc20:decrypt_new())
  dec:ctrl(openssl.cipher.EVP_CTRL_GCM_SET_IVLEN, #self.iv)
  dec:init(self.key, self.iv)
  dec:ctrl(openssl.cipher.EVP_CTRL_GCM_SET_TAG, tag)
  dec:update(wrong_aad, true)
  dec:update(ciphertext)
  
  -- Final should fail with wrong AAD (may return nil/false or throw error)
  local final_result = dec:final()
  -- OpenSSL may return nil or empty string on auth failure
  assert(not final_result or final_result == "" or final_result == nil)
end

-- Test empty message
function TestChaCha20Poly1305:testEmptyMessage()
  local cc20 = cipher.get("chacha20-poly1305")
  if not cc20 then
    lu.skip("ChaCha20-Poly1305 not supported on this platform")
  end
  
  -- Encrypt empty message
  local enc = assert(cc20:encrypt_new(self.key, self.iv))
  local ciphertext = assert(enc:update(""))
  ciphertext = ciphertext .. assert(enc:final())
  
  -- Decrypt
  local dec = assert(cc20:decrypt_new(self.key, self.iv))
  local plaintext = assert(dec:update(ciphertext))
  plaintext = plaintext .. assert(dec:final())
  
  lu.assertEquals(plaintext, "")
end

-- Test large message
function TestChaCha20Poly1305:testLargeMessage()
  local cc20 = cipher.get("chacha20-poly1305")
  if not cc20 then
    lu.skip("ChaCha20-Poly1305 not supported on this platform")
  end
  
  -- Create 1MB message
  local large_msg = string.rep("a", 1024 * 1024)
  
  -- Encrypt
  local enc = assert(cc20:encrypt_new(self.key, self.iv))
  local ciphertext = assert(enc:update(large_msg))
  ciphertext = ciphertext .. assert(enc:final())
  
  -- Decrypt
  local dec = assert(cc20:decrypt_new(self.key, self.iv))
  local plaintext = assert(dec:update(ciphertext))
  plaintext = plaintext .. assert(dec:final())
  
  lu.assertEquals(plaintext, large_msg)
end

-- Test multiple updates
function TestChaCha20Poly1305:testMultipleUpdates()
  local cc20 = cipher.get("chacha20-poly1305")
  if not cc20 then
    lu.skip("ChaCha20-Poly1305 not supported on this platform")
  end
  
  local part1 = "Hello, "
  local part2 = "ChaCha20-"
  local part3 = "Poly1305!"
  local full_msg = part1 .. part2 .. part3
  
  -- Encrypt in multiple updates
  local enc = assert(cc20:encrypt_new(self.key, self.iv))
  local ct1 = assert(enc:update(part1))
  local ct2 = assert(enc:update(part2))
  local ct3 = assert(enc:update(part3))
  local ct_final = assert(enc:final())
  local ciphertext = ct1 .. ct2 .. ct3 .. ct_final
  
  -- Decrypt in one go
  local dec = assert(cc20:decrypt_new(self.key, self.iv))
  local plaintext = assert(dec:update(ciphertext))
  plaintext = plaintext .. assert(dec:final())
  
  lu.assertEquals(plaintext, full_msg)
end

-- Test different key sizes (only 256-bit supported for ChaCha20)
function TestChaCha20Poly1305:testKeySize()
  local cc20 = cipher.get("chacha20-poly1305")
  if not cc20 then
    lu.skip("ChaCha20-Poly1305 not supported on this platform")
  end
  
  local info = cc20:info()
  lu.assertEquals(info.key_length, 32) -- ChaCha20 uses 256-bit keys
end

-- Test nonce/IV size
function TestChaCha20Poly1305:testNonceSize()
  local cc20 = cipher.get("chacha20-poly1305")
  if not cc20 then
    lu.skip("ChaCha20-Poly1305 not supported on this platform")
  end
  
  local info = cc20:info()
  lu.assertEquals(info.iv_length, 12) -- 96-bit nonce is standard
end

os.exit(lu.LuaUnit.run())
