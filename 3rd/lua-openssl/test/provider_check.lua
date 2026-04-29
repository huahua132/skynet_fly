#!/usr/bin/env lua
-- Quick test to verify provider module availability
local openssl = require('openssl')

print("\n" .. string.rep("=", 70))
print("OpenSSL Provider Module Availability Test")
print(string.rep("=", 70))

-- Get version info
local ver_str, lua_ver, ssl_ver = openssl.version()
local ver_num, lua_num, ssl_num = openssl.version(true)

print("\nVersion Information:")
print("  Lua version:     " .. lua_ver)
print("  OpenSSL version: " .. ssl_ver)
print("  Version number:  " .. string.format("0x%08X", ssl_num))

-- Check if this is LibreSSL
local is_libressl = string.match(ssl_ver, "LibreSSL") ~= nil
print("  LibreSSL:        " .. (is_libressl and "Yes" or "No"))

-- Check if provider module is available
print("\nProvider Module Status:")
if openssl.provider then
  if openssl.provider._error then
    print("  Status:          Available (stub)")
    print("  Error:           " .. openssl.provider._error)
  else
    print("  Status:          Available and functional")
    print("  Module type:     " .. type(openssl.provider))

    -- Try to list providers
    local ok, result = pcall(function() return openssl.provider.list() end)
    if ok and result then
      print("  Available providers:")
      for i, name in ipairs(result) do
        print("    " .. i .. ". " .. name)
      end
    end
  end
else
  print("  Status:          Not available")
  print("  Reason:          Requires OpenSSL 3.0+ (not LibreSSL)")
end

-- Version compatibility check
print("\nCompatibility Check:")
if ssl_num >= 0x30000000 and not is_libressl then
  print("  ✓ OpenSSL 3.0+ detected - Provider API should be available")
elseif is_libressl then
  print("  ⚠ LibreSSL detected - Provider API not supported")
else
  print("  ⚠ OpenSSL < 3.0 detected - Provider API not available")
end

print(string.rep("=", 70) .. "\n")
