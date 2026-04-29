local lu = require("luaunit")
local openssl = require("openssl")
local digest = require("openssl").digest
local cipher = require("openssl").cipher
local helper = require("helper")

-- Only run these tests on OpenSSL 3.0+
if not helper.openssl3 then
  print("Skipping fetchable API tests - OpenSSL 3.0+ required")
  return
end

TestDigestFetch = {}

function TestDigestFetch:setUp()
  self.msg = "test message for digest"
end

function TestDigestFetch:tearDown() end

function TestDigestFetch:testFetchBasic()
  -- Test basic fetch without provider
  local md = digest.fetch('SHA256')
  lu.assertNotNil(md)
  
  -- Test that fetched object works like regular digest
  local result = md:digest(self.msg)
  lu.assertNotNil(result)
  lu.assertEquals(#result, 32) -- SHA256 produces 32 bytes
  
  -- Compare with traditional get method
  local md_traditional = digest.get('SHA256')
  local result_traditional = md_traditional:digest(self.msg)
  lu.assertEquals(result, result_traditional)
end

function TestDigestFetch:testFetchWithDefaultProvider()
  -- Test fetch with explicit default provider
  local md = digest.fetch('SHA256', {provider = 'default'})
  lu.assertNotNil(md)
  
  -- Verify it's from the default provider
  local provider_name = md:get_provider_name()
  lu.assertNotNil(provider_name)
  lu.assertEquals(provider_name, 'default')
  
  -- Test digest functionality
  local result = md:digest(self.msg)
  lu.assertNotNil(result)
  lu.assertEquals(#result, 32)
end

function TestDigestFetch:testFetchDifferentAlgorithms()
  -- Test different digest algorithms
  local algorithms = {
    {name = 'SHA1', size = 20},
    {name = 'SHA256', size = 32},
    {name = 'SHA512', size = 64},
  }
  
  for _, alg in ipairs(algorithms) do
    local md = digest.fetch(alg.name)
    if md then
      local result = md:digest(self.msg)
      lu.assertEquals(#result, alg.size, "Failed for " .. alg.name)
    end
  end
end

function TestDigestFetch:testFetchNonExistentProvider()
  -- Test fetching with a non-existent provider
  local md, err = digest.fetch('SHA256', {provider = 'nonexistent'})
  lu.assertNil(md)
  lu.assertNotNil(err)
  lu.assertTrue(string.find(err, 'provider') ~= nil)
end

function TestDigestFetch:testFetchedDigestInfo()
  local md = digest.fetch('SHA256')
  lu.assertNotNil(md)
  
  -- Test info method
  local info = md:info()
  lu.assertNotNil(info)
  lu.assertNotNil(info.name)
  lu.assertEquals(info.size, 32)
  lu.assertNotNil(info.block_size)
end

function TestDigestFetch:testFetchedDigestContext()
  local md = digest.fetch('SHA256')
  lu.assertNotNil(md)
  
  -- Test creating context and updating
  local ctx = md:new()
  lu.assertNotNil(ctx)
  
  lu.assertTrue(ctx:update("test"))
  lu.assertTrue(ctx:update(" message"))
  local result = ctx:final(true)
  lu.assertNotNil(result)
  lu.assertEquals(#result, 32)
end

TestCipherFetch = {}

function TestCipherFetch:setUp()
  self.msg = "test message for cipher encryption"
  self.key = string.rep("k", 32) -- 256-bit key
  self.iv = string.rep("i", 16)  -- 128-bit IV
end

function TestCipherFetch:tearDown() end

function TestCipherFetch:testFetchBasic()
  -- Test basic fetch without provider
  local c = cipher.fetch('AES-256-CBC')
  lu.assertNotNil(c)
  
  -- Test that fetched object works
  local encrypted = c:encrypt(self.msg, self.key, self.iv)
  lu.assertNotNil(encrypted)
  lu.assertTrue(#encrypted > 0)
  
  -- Decrypt and verify
  local decrypted = c:decrypt(encrypted, self.key, self.iv)
  lu.assertEquals(decrypted, self.msg)
end

function TestCipherFetch:testFetchWithDefaultProvider()
  -- Test fetch with explicit default provider
  local c = cipher.fetch('AES-256-CBC', {provider = 'default'})
  lu.assertNotNil(c)
  
  -- Verify it's from the default provider
  local provider_name = c:get_provider_name()
  lu.assertNotNil(provider_name)
  lu.assertEquals(provider_name, 'default')
  
  -- Test encryption functionality
  local encrypted = c:encrypt(self.msg, self.key, self.iv)
  lu.assertNotNil(encrypted)
end

function TestCipherFetch:testFetchDifferentAlgorithms()
  -- Test different cipher algorithms
  local algorithms = {
    'AES-128-CBC',
    'AES-256-CBC',
  }
  
  for _, alg in ipairs(algorithms) do
    local c = cipher.fetch(alg)
    if c then
      -- Just test that we can get info
      local info = c:info()
      lu.assertNotNil(info)
      lu.assertNotNil(info.name)
    end
  end
end

function TestCipherFetch:testFetchNonExistentProvider()
  -- Test fetching with a non-existent provider
  local c, err = cipher.fetch('AES-256-CBC', {provider = 'nonexistent'})
  lu.assertNil(c)
  lu.assertNotNil(err)
  lu.assertTrue(string.find(err, 'provider') ~= nil)
end

function TestCipherFetch:testFetchedCipherInfo()
  local c = cipher.fetch('AES-256-CBC')
  lu.assertNotNil(c)
  
  -- Test info method
  local info = c:info()
  lu.assertNotNil(info)
  lu.assertNotNil(info.name)
  lu.assertEquals(info.key_length, 32) -- 256 bits / 8
  lu.assertEquals(info.iv_length, 16)  -- 128 bits / 8
end

function TestCipherFetch:testFetchedCipherContext()
  local c = cipher.fetch('AES-256-CBC')
  lu.assertNotNil(c)
  
  -- Test creating context and encrypting
  local ctx = c:encrypt_new(self.key, self.iv)
  lu.assertNotNil(ctx)
  
  local encrypted = ctx:update(self.msg) .. ctx:final()
  lu.assertNotNil(encrypted)
  lu.assertTrue(#encrypted > 0)
  
  -- Decrypt and verify
  local dctx = c:decrypt_new(self.key, self.iv)
  local decrypted = dctx:update(encrypted) .. dctx:final()
  lu.assertEquals(decrypted, self.msg)
end

function TestCipherFetch:testCompatibilityWithTraditional()
  -- Ensure fetched cipher produces same results as traditional get
  local fetched = cipher.fetch('AES-256-CBC')
  local traditional = cipher.get('AES-256-CBC')
  
  local encrypted1 = fetched:encrypt(self.msg, self.key, self.iv)
  local encrypted2 = traditional:encrypt(self.msg, self.key, self.iv)
  
  -- Both should decrypt to the same message
  local decrypted1 = fetched:decrypt(encrypted1, self.key, self.iv)
  local decrypted2 = traditional:decrypt(encrypted2, self.key, self.iv)
  
  lu.assertEquals(decrypted1, self.msg)
  lu.assertEquals(decrypted2, self.msg)
end

TestProviderIntegration = {}

function TestProviderIntegration:testListProviders()
  -- Test that we can list available providers
  local provider = require('openssl').provider
  local providers = provider.list()
  lu.assertNotNil(providers)
  lu.assertTrue(#providers > 0)
  
  -- Default provider should be available
  local has_default = false
  for _, name in ipairs(providers) do
    if name == 'default' then
      has_default = true
      break
    end
  end
  lu.assertTrue(has_default)
end

function TestProviderIntegration:testFetchWithLoadedProvider()
  -- Load a provider explicitly
  local provider = require('openssl').provider
  local default_provider = provider.load('default')
  lu.assertNotNil(default_provider)
  
  -- Now fetch an algorithm
  local md = digest.fetch('SHA256', {provider = 'default'})
  lu.assertNotNil(md)
  
  local provider_name = md:get_provider_name()
  lu.assertEquals(provider_name, 'default')
end
