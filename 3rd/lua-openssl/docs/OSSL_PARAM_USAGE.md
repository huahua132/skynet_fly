# OSSL_PARAM API Usage Guide

## Overview

Starting with OpenSSL 3.0, the OSSL_PARAM API is the modern way to access cryptographic key parameters. lua-openssl now supports this API while maintaining backward compatibility with OpenSSL 1.x.

## What is OSSL_PARAM?

OSSL_PARAM is OpenSSL 3.0's unified parameter system that replaces many legacy key access functions. It provides a consistent interface for accessing parameters across different key types (RSA, EC, DH, etc.).

## Supported Parameters

### RSA Key Parameters

The following RSA parameters are accessible via the param module:

```lua
local param = require("openssl").param

-- Available RSA parameters:
-- param.rsa.n   - Modulus (public)
-- param.rsa.e   - Public exponent
-- param.rsa.d   - Private exponent
-- param.rsa["rsa-factor1"]     - Prime p
-- param.rsa["rsa-factor2"]     - Prime q
-- param.rsa["rsa-exponent1"]   - dmp1 (d mod (p-1))
-- param.rsa["rsa-exponent2"]   - dmq1 (d mod (q-1))
-- param.rsa["rsa-coefficient1"] - iqmp (q^-1 mod p)
```

### KDF Parameters

KDF parameters continue to work as before. See `test/2.kdf.lua` for examples.

## Usage Examples

### Parsing RSA Key Parameters

```lua
local openssl = require("openssl")
local rsa = openssl.rsa

-- Generate an RSA key
local key = rsa.generate_key(2048)

-- Parse the key to access parameters
local params = key:parse()

-- Access parameters
print("Key size:", params.size, "bytes")
print("Key bits:", params.bits)

-- Access public parameters (always available)
print("Modulus n:", params.n)        -- BIGNUM object
print("Exponent e:", params.e)       -- BIGNUM object

-- Access private parameters (only for private keys)
if params.d then
  print("Private exponent d:", params.d)
  print("Prime p:", params.p)
  print("Prime q:", params.q)
  print("CRT exponent dmp1:", params.dmp1)
  print("CRT exponent dmq1:", params.dmq1)
  print("CRT coefficient iqmp:", params.iqmp)
end
```

### Checking Parameter Availability

```lua
local param = require("openssl").param

-- Check what RSA parameters are defined
for name, info in pairs(param.rsa) do
  print(string.format("Parameter: %s, Type: %d", name, info.type))
  if info.number_type then
    print(string.format("  Number type: %s", info.number_type))
  end
end
```

## Implementation Details

### OpenSSL 3.0+ Path

When running on OpenSSL 3.0 or later, `rsa:parse()` uses the modern `EVP_PKEY_get_bn_param()` API to extract parameters. This is the recommended approach for new code.

### OpenSSL 1.x Path

On OpenSSL 1.x, or when the PARAM API fails (e.g., for legacy keys), the implementation automatically falls back to the traditional `RSA_get0_key()`, `RSA_get0_factors()`, and `RSA_get0_crt_params()` functions.

### Compatibility

The dual-path implementation ensures:
- ✅ Works with OpenSSL 1.x (using legacy API)
- ✅ Works with OpenSSL 3.0+ (using PARAM API)
- ✅ Handles keys created with either API version
- ✅ No changes required to existing code
- ✅ Same behavior across versions

## Testing

The implementation includes comprehensive tests in `test/2.param.lua`:

```bash
# Run param tests
cd test
lua 2.param.lua
```

## Future Enhancements

The current implementation focuses on RSA parameters. Future updates may include:
- EC (Elliptic Curve) key parameters
- DH (Diffie-Hellman) parameters
- DSA parameters
- General-purpose OSSL_PARAM array creation from Lua

## References

- [OpenSSL 3.0 Migration Guide](https://www.openssl.org/docs/man3.0/man7/migration_guide.html)
- [OSSL_PARAM Documentation](https://www.openssl.org/docs/man3.0/man3/OSSL_PARAM.html)
- [lua-openssl ROADMAP](ROADMAP.md)
- [Task 2.5 Details](ROADMAP_CN.md#25-openssl-30-ossl_param-api-绑定)

## Contributing

To extend OSSL_PARAM support to other key types:

1. Add parameter definitions to `src/param.c` (similar to `rsa_params[]`)
2. Update `get_param_type()` to recognize the new parameters
3. Export parameters in `luaopen_param()`
4. Implement parameter access in the relevant module (e.g., `src/ec.c` for EC keys)
5. Add tests to verify functionality

See the RSA implementation as a reference example.
