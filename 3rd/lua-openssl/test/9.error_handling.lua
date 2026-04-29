-- Test error handling and resource cleanup
-- This test verifies that error paths properly return error information
-- and don't leak resources

local lu = require("luaunit")
local openssl = require("openssl")

TestErrorHandling = {}

function TestErrorHandling:testDigestInvalidAlgorithm()
  -- Test that invalid digest algorithm throws error or returns nil
  local result, err = pcall(function()
    return openssl.digest.new("invalid_algorithm_xyz")
  end)
  -- get_digest throws luaL_argerror for invalid algorithm
  lu.assertEquals(result, false)
  lu.assertNotEquals(err, nil)
  lu.assertEquals(type(err), "string")
end

function TestErrorHandling:testDigestWithBadEngine()
  -- Test digest with invalid engine parameter
  -- This should trigger luaL_argcheck or return error
  local result, err = pcall(function()
    return openssl.digest.new("sha256", "not_an_engine")
  end)
  -- Should either fail with pcall (luaL_argcheck) or return nil
  if result == false then
    lu.assertNotEquals(err, nil)
  else
    lu.assertEquals(result, nil)
  end
end

function TestErrorHandling:testHmacWithNilKey()
  -- Test HMAC with nil key should fail gracefully
  local result, err = pcall(function()
    return openssl.hmac.new("sha256", nil)
  end)
  -- Should fail during parameter checking
  lu.assertEquals(result, false)
  lu.assertNotEquals(err, nil)
end

function TestErrorHandling:testHmacWithEmptyKey()
  -- Test HMAC with empty key
  local result, err, code = openssl.hmac.new("sha256", "")
  -- Empty key is valid, should succeed
  if result then
    lu.assertNotEquals(result, nil)
  else
    -- Or it may return error depending on OpenSSL version
    lu.assertEquals(result, nil)
    lu.assertNotEquals(err, nil)
  end
end

function TestErrorHandling:testSignInitWithNilPkey()
  -- Test signInit with invalid pkey
  local result, err = pcall(function()
    return openssl.digest.signInit("sha256", "not_a_pkey")
  end)
  -- Should fail during parameter checking
  lu.assertEquals(result, false)
  lu.assertNotEquals(err, nil)
end

function TestErrorHandling:testVerifyInitWithNilPkey()
  -- Test verifyInit with invalid pkey
  local result, err = pcall(function()
    return openssl.digest.verifyInit("sha256", "not_a_pkey")
  end)
  -- Should fail during parameter checking
  lu.assertEquals(result, false)
  lu.assertNotEquals(err, nil)
end

function TestErrorHandling:testCipherInvalidAlgorithm()
  -- Test cipher with invalid algorithm
  local result, err = pcall(function()
    return openssl.cipher.get("invalid_cipher_xyz")
  end)
  if result == false then
    lu.assertNotEquals(err, nil)
  else
    -- get() may return nil for invalid algorithm
    lu.assertEquals(result, nil)
  end
end

function TestErrorHandling:testPushResultPattern()
  -- Test that functions using openssl_pushresult return proper error format
  -- Try to create digest with malformed name
  local md = openssl.digest.get("sha256")
  lu.assertNotEquals(md, nil)
  
  -- Try digest operation with bad parameters
  local result, err, code = pcall(function()
    return md:digest(nil)  -- nil input should fail
  end)
  -- Should either fail with pcall or return nil, err, code
  lu.assertEquals(result, false)
end

function TestErrorHandling:testResourceCleanupOnError()
  -- This test verifies resources are cleaned up even on error
  -- We can't directly test for leaks here, but we can verify error handling works
  
  -- Test multiple failed operations in a row
  for i = 1, 100 do
    local result, err = pcall(function()
      return openssl.digest.new("invalid_alg_" .. i)
    end)
    -- Each should fail with luaL_argerror
    lu.assertEquals(result, false)
  end
  
  -- Force garbage collection to clean up any leaked objects
  collectgarbage("collect")
  collectgarbage("collect")
end

function TestErrorHandling:testMultipleContexts()
  -- Test creating multiple contexts to ensure proper cleanup
  local contexts = {}
  
  -- Create several valid contexts
  for i = 1, 10 do
    local ctx = openssl.digest.new("sha256")
    lu.assertNotEquals(ctx, nil)
    table.insert(contexts, ctx)
  end
  
  -- Clear references and collect garbage
  contexts = nil
  collectgarbage("collect")
  collectgarbage("collect")
  
  -- Try creating more contexts after cleanup
  for i = 1, 10 do
    local ctx = openssl.digest.new("sha256")
    lu.assertNotEquals(ctx, nil)
  end
end

function TestErrorHandling:testErrorMessageFormat()
  -- Verify error messages are useful when operations fail
  -- Create a digest context and try to use it incorrectly
  local ctx = openssl.digest.new("sha256")
  lu.assertNotEquals(ctx, nil)
  
  -- Update with valid data should work
  local result = ctx:update("test data")
  lu.assertTrue(result)
  
  -- Finalize to get result
  local hash = ctx:final()
  lu.assertNotEquals(hash, nil)
  
  -- Try to update after final - this should fail
  local result2, err = ctx:update("more data")
  -- This may succeed or fail depending on OpenSSL version
  -- Main point is it doesn't crash
  lu.assertTrue(result2 == true or result2 == nil or result2 == false)
end

-- Run the tests if this file is executed directly
if arg and arg[0]:match("error_handling%.lua$") then
  os.exit(lu.LuaUnit.run())
end

return TestErrorHandling
