local lu = require('luaunit')
local openssl = require('openssl')

-- Check if provider module is available (OpenSSL 3.0+ and not LibreSSL)
if not openssl.provider then
  return
end

-- Additional check: verify provider module is actually functional
assert(not openssl.provider._error)

local provider = openssl.provider

TestProvider = {}

function TestProvider:setUp()
  -- Clean up any previously loaded test providers
  collectgarbage('collect')
end

function TestProvider:tearDown()
  collectgarbage('collect')
end

function TestProvider:test_load_default_provider()
  local prov = provider.load('default')

  lu.assertNotNil(prov, "Should load default provider")
  lu.assertEquals(type(prov), 'userdata', "Provider should be userdata")
  -- Avoid memory leak by unloading
  prov:unload()
end

function TestProvider:test_provider_name()
  local prov = provider.load('default')
  lu.assertNotNil(prov, "Should load default provider")

  local name = prov:name()
  lu.assertNotNil(name, "Provider should have a name")
  lu.assertEquals(name, 'default', "Name should be 'default'")
  -- Avoid memory leak by unloading
  prov:unload()
end

function TestProvider:test_provider_available()
  local prov = provider.load('default')
  lu.assertNotNil(prov, "Should load default provider")

  local available = prov:available()
  lu.assertTrue(available, "Default provider should be available")
  -- Avoid memory leak by unloading
  prov:unload()
end

function TestProvider:test_provider_get_params()
  local prov = provider.load('default')
  lu.assertNotNil(prov, "Should load default provider")

  -- Try to get some common parameters
  local params = prov:get_params({'name', 'version', 'buildinfo'})
  lu.assertNotNil(params, "Should return params table")
  lu.assertEquals(type(params), 'table', "Params should be a table")
  -- Avoid memory leak by unloading
  prov:unload()
end

function TestProvider:test_provider_self_test()
  local prov = provider.load('default')
  lu.assertNotNil(prov, "Should load default provider")

  local result = prov:self_test()
  lu.assertNotNil(result, "Self-test should return a result")
  lu.assertEquals(type(result), 'boolean', "Self-test result should be boolean")
  -- Avoid memory leak by unloading
  prov:unload()
end

function TestProvider:test_load_legacy_provider()
  -- Legacy provider might not be available on all systems
  local prov, err = provider.load('legacy')

  if prov then
    lu.assertNotNil(prov, "Legacy provider loaded")
    local name = prov:name()
    lu.assertEquals(name, 'legacy', "Name should be 'legacy'")

    -- Test unload
    local unload_result = prov:unload()
    lu.assertNotNil(unload_result, "Unload should return a result")
    -- Avoid memory leak by unloading
    prov:unload()
  else
    print("⚠ Legacy provider not available on this system")
    print("  Error:", err or "unknown")
  end
end

function TestProvider:test_load_fips_provider()
  -- FIPS provider might not be available on all systems
  local prov, err = provider.load('fips')

  if prov then
    lu.assertNotNil(prov, "FIPS provider loaded")
    local name = prov:name()
    lu.assertEquals(name, 'fips', "Name should be 'fips'")

    -- Test FIPS self-test
    local self_test = prov:self_test()
    assert(self_test, "FIPS provider self-test should pass")
    -- Avoid memory leak by unloading
    prov:unload()
  end
end

function TestProvider:test_provider_get()
  -- Default provider should already be loaded
  local prov = provider.get('default')

  if prov then
    lu.assertNotNil(prov, "Should get default provider")
    local name = prov:name()
    lu.assertEquals(name, 'default', "Name should be 'default'")
    -- Avoid memory leak by unloading
    prov:unload()
  end
end

function TestProvider:test_provider_list()
  local providers = provider.list()

  lu.assertNotNil(providers, "Should return providers list")
  lu.assertEquals(type(providers), 'table', "Providers should be a table")
  lu.assertTrue(#providers > 0, "Should have at least one provider")
end

function TestProvider:test_provider_tostring()
  local prov = provider.load('default')
  lu.assertNotNil(prov, "Should load default provider")

  local str = tostring(prov)
  lu.assertNotNil(str, "tostring should return a value")
  lu.assertTrue(string.find(str, 'openssl.provider') ~= nil,
                "String should contain 'openssl.provider'")
  lu.assertTrue(string.find(str, 'default') ~= nil,
                "String should contain provider name")

  -- Avoid memory leak by unloading
  prov:unload()
end

function TestProvider:test_load_with_retain()
  local prov = provider.load('default', true)

  lu.assertNotNil(prov, "Should load default provider with retain")
  local name = prov:name()
  lu.assertEquals(name, 'default', "Name should be 'default'")
  -- Avoid memory leak by unloading
  prov:unload()
end

function TestProvider:test_load_invalid_provider()
  local prov, err = provider.load('nonexistent_provider_xyz')

  lu.assertNil(prov, "Should not load non-existent provider")
  lu.assertTrue(type(err) == 'string', "Error message should be a string")
end

function TestProvider:test_multiple_providers()
  local prov1 = provider.load('default')
  local prov2 = provider.load('default')

  lu.assertNotNil(prov1, "First load should succeed")
  lu.assertNotNil(prov2, "Second load should succeed")

  -- Both should be usable
  lu.assertEquals(prov1:name(), 'default', "First provider name")
  lu.assertEquals(prov2:name(), 'default', "Second provider name")
  -- Avoid memory leak by unloading
  prov1:unload()
  prov2:unload()
end

function TestProvider:test_provider_with_digest()
  local prov = provider.load('default')
  lu.assertNotNil(prov, "Should load default provider")

  -- Test that digest operations work with loaded provider
  local digest = openssl.digest.get('sha256')
  lu.assertNotNil(digest, "Should get sha256 digest")

  local data = "Hello, OpenSSL Provider!"
  local hash = digest:digest(data)
  lu.assertNotNil(hash, "Should compute hash")
  lu.assertEquals(#hash, 32, "SHA256 should produce 32 bytes")
  -- Avoid memory leak by unloading
  prov:unload()
end

function TestProvider:test_provider_with_cipher()
  local prov = provider.load('default')
  lu.assertNotNil(prov, "Should load default provider")

  -- Test that cipher operations work with loaded provider
  local cipher = openssl.cipher.get('aes-256-cbc')
  lu.assertNotNil(cipher, "Should get aes-256-cbc cipher")

  local key = string.rep('k', 32)  -- 256-bit key
  local iv = string.rep('i', 16)   -- 128-bit IV
  local plaintext = "Secret message with provider"

  local ciphertext = cipher:encrypt(plaintext, key, iv)
  lu.assertNotNil(ciphertext, "Should encrypt")

  local decrypted = cipher:decrypt(ciphertext, key, iv)
  lu.assertEquals(decrypted, plaintext, "Decrypted should match plaintext")
  -- Avoid memory leak by unloading
  prov:unload()
end

-- Test suite for OpenSSL 3.0+ specific features
TestProviderAdvanced = {}

function TestProviderAdvanced:test_base_provider()
  local prov, err = provider.load('base')
  assert(type(prov) == 'userdata', "Null provider should be userdata")
  assert(type(err) == 'nil', err)
  -- Avoid memory leak by unloading
  prov:unload()
end

function TestProviderAdvanced:test_null_provider()
  local prov, err = assert(provider.load('null'))
  assert(type(prov) == 'userdata', "Null provider should be userdata")
  assert(type(err) == 'nil', err)
  -- Avoid memory leak by unloading
  prov:unload()
end

-- Performance test
TestProviderPerformance = {}

function TestProviderPerformance:test_provider_load_performance()
  local iterations = 100
  local start_time = os.clock()

  for i = 1, iterations do
    local prov = provider.load('default')
    if prov then
      prov:unload()
    end
  end

  local end_time = os.clock()
  local elapsed = end_time - start_time
  local avg_time = elapsed / iterations * 1000  -- Convert to milliseconds

  -- On Windows, os.clock() may have low precision, so we only check if elapsed time is reasonable (not too long)
  -- We don't assert that elapsed > 0 since it may round to 0 for fast operations on Windows
  assert(elapsed < 100, "Total time should be reasonable")
  if elapsed > 0 then
    lu.assertTrue(avg_time < 100, "Average load time should be reasonable")
  end
end
