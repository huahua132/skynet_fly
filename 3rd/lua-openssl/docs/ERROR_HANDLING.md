# Error Handling Guidelines for lua-openssl Contributors

## Overview

This document describes the error handling patterns and best practices for lua-openssl development. Following these guidelines ensures consistent, predictable error handling behavior and prevents resource leaks.

## Core Principles

### 1. Input Validation with Exceptions

API input parameters should use Lua's standard error checking functions to validate arguments:

```c
// Example: Validate argument types
luaL_argcheck(L, condition, arg_position, "error message");
luaL_checkstring(L, arg_position);
luaL_checkinteger(L, arg_position);
```

**When to use:** For validating function arguments (wrong type, out of range, etc.)

**Behavior:** Throws a Lua error and aborts the current operation.

### 2. Runtime Errors Return Failure Values

During API processing, if errors occur, prefer returning error information instead of throwing exceptions:

```c
// Example: Return error via openssl_pushresult
int ret = EVP_SomeOperation(ctx, ...);
if (ret == 1) {
    // Success path
    PUSH_OBJECT(result, "openssl.type");
    return 1;
} else {
    // Error path - free resources then return error
    EVP_CTX_free(ctx);
    return openssl_pushresult(L, ret);
}
```

**When to use:** For runtime errors from OpenSSL operations (failed crypto operations, invalid data, etc.)

**Behavior:** Returns `nil, error_message, error_code` to Lua, allowing the caller to handle the error.

**Why:** This follows Lua conventions where errors that might reasonably occur during normal operation should be returned as values, not exceptions.

### 3. Non-Recoverable Errors Use Exceptions

For operations that don't need to return a value and encounter unrecoverable errors:

```c
// Example: Memory allocation failure
buffer = OPENSSL_malloc(size);
if (buffer == NULL) {
    EVP_CTX_free(ctx);  // Clean up first!
    return luaL_error(L, "Memory allocation failed");
}
```

**When to use:** For truly exceptional conditions (out of memory, corrupted internal state).

**Behavior:** Throws a Lua error and aborts the current operation.

## Resource Management

### Critical Rule: Always Free Resources on Error Paths

Every allocated resource MUST be freed on all error paths:

```c
// ❌ WRONG - Memory leak on error path
EVP_MD_CTX *ctx = EVP_MD_CTX_new();
if (ctx) {
    ret = EVP_DigestInit_ex(ctx, md, e);
    if (ret == 1) {
        PUSH_OBJECT(ctx, "openssl.evp_digest_ctx");
    } else {
        // BUG: ctx is not freed!
        ret = openssl_pushresult(L, ret);
    }
}
return ret;

// ✅ CORRECT - Resource freed on all paths
EVP_MD_CTX *ctx = EVP_MD_CTX_new();
if (ctx) {
    ret = EVP_DigestInit_ex(ctx, md, e);
    if (ret == 1) {
        PUSH_OBJECT(ctx, "openssl.evp_digest_ctx");
    } else {
        EVP_MD_CTX_free(ctx);  // Free resource before returning error
        ret = openssl_pushresult(L, ret);
    }
}
return ret;
```

### Common Resource Types and Cleanup Functions

| Resource Type | Allocation | Cleanup |
|--------------|------------|---------|
| EVP_MD_CTX | `EVP_MD_CTX_new()` | `EVP_MD_CTX_free(ctx)` |
| EVP_CIPHER_CTX | `EVP_CIPHER_CTX_new()` | `EVP_CIPHER_CTX_free(ctx)` |
| EVP_PKEY_CTX | `EVP_PKEY_CTX_new()` | `EVP_PKEY_CTX_free(ctx)` |
| HMAC_CTX | `HMAC_CTX_new()` | `HMAC_CTX_free(ctx)` |
| EVP_MAC_CTX | `EVP_MAC_CTX_new()` | `EVP_MAC_CTX_free(ctx)` |
| BIO | `BIO_new()` | `BIO_free(bio)` |
| X509 | `X509_new()` | `X509_free(cert)` |
| EVP_PKEY | `EVP_PKEY_new()` | `EVP_PKEY_free(pkey)` |
| Memory | `malloc()` / `OPENSSL_malloc()` | `free()` / `OPENSSL_free()` |

## The openssl_pushresult Function

Located in `src/misc.c`, this function standardizes error reporting:

```c
int openssl_pushresult(lua_State *L, int result)
{
  if (result >= 1) {
    lua_pushboolean(L, 1);
    return 1;
  } else {
    unsigned long val = ERR_get_error();
    lua_pushnil(L);
    if (val) {
      lua_pushstring(L, ERR_reason_error_string(val));
      lua_pushinteger(L, val);
    } else {
      lua_pushstring(L, "UNKNOWN ERROR");
      lua_pushnil(L);
    }
    return 3;
  }
}
```

**Returns:**
- On success (result >= 1): `true` (1 return value)
- On failure: `nil, error_message, error_code` (3 return values)

## Common Patterns

### Pattern 1: Context Creation and Initialization

```c
static int openssl_function(lua_State *L)
{
  const EVP_MD *md = get_digest(L, 1, NULL);
  EVP_MD_CTX   *ctx = EVP_MD_CTX_new();
  int           ret = 0;

  if (ctx) {
    ret = EVP_DigestInit_ex(ctx, md, NULL);
    if (ret == 1) {
      PUSH_OBJECT(ctx, "openssl.evp_digest_ctx");
    } else {
      EVP_MD_CTX_free(ctx);  // ⚠️ Critical: Free on error
      ret = openssl_pushresult(L, ret);
    }
  }
  return ret;
}
```

### Pattern 2: Multi-Step Operations

```c
static int openssl_function(lua_State *L)
{
  EVP_CIPHER_CTX *c = EVP_CIPHER_CTX_new();
  char           *buffer = NULL;
  int             ret = 0;

  if (!c) return 0;

  ret = EVP_EncryptInit_ex(c, cipher, NULL, key, iv);
  if (ret == 1) {
    buffer = OPENSSL_malloc(size);
    if (!buffer) {
      EVP_CIPHER_CTX_free(c);  // Free c before error
      return luaL_error(L, "Memory allocation failed");
    }
    
    ret = EVP_EncryptUpdate(c, buffer, &len, input, input_len);
    if (ret == 1) {
      ret = EVP_EncryptFinal_ex(c, buffer + len, &len2);
      if (ret == 1) {
        lua_pushlstring(L, buffer, len + len2);
      }
    }
    OPENSSL_free(buffer);  // Always free buffer
  }
  
  EVP_CIPHER_CTX_free(c);  // Always free context
  return (ret == 1) ? 1 : openssl_pushresult(L, ret);
}
```

### Pattern 3: Early Returns on Success

```c
static int openssl_function(lua_State *L)
{
  EVP_PKEY_CTX *ctx = EVP_PKEY_CTX_new(pkey, engine);
  
  if (EVP_PKEY_encrypt_init(ctx) == 1) {
    if (EVP_PKEY_CTX_set_rsa_padding(ctx, padding) == 1) {
      byte *buf = malloc(clen);
      if (EVP_PKEY_encrypt(ctx, buf, &clen, data, dlen) == 1) {
        lua_pushlstring(L, (const char *)buf, clen);
        free(buf);
        EVP_PKEY_CTX_free(ctx);
        return 1;  // Early return on success
      }
      free(buf);
    }
  }
  EVP_PKEY_CTX_free(ctx);  // Cleanup for all error paths
  return 0;
}
```

## Testing Error Paths

### Manual Testing

Test error paths by providing invalid inputs:

```lua
-- Test invalid digest algorithm
local result, err, code = openssl.digest.new("invalid_algorithm")
assert(result == nil)
assert(type(err) == "string")
assert(type(code) == "number" or code == nil)

-- Test with nil key
local result, err = openssl.hmac.new("sha256", nil)
assert(result == nil)
assert(err ~= nil)
```

### Memory Leak Detection

Use Valgrind or AddressSanitizer to detect leaks:

```bash
# Build with AddressSanitizer
make clean && make asan

# Build for Valgrind
make clean && make valgrind
```

Both should report zero memory leaks for proper implementations.

## Checklist for Code Review

When reviewing error handling code, verify:

- [ ] All allocated resources have corresponding free calls
- [ ] Error paths free resources before returning
- [ ] Input validation uses `luaL_argcheck` or similar
- [ ] Runtime errors use `openssl_pushresult` 
- [ ] Truly exceptional errors use `luaL_error`
- [ ] Early returns don't skip cleanup code
- [ ] Multi-step operations clean up partial state on failure
- [ ] Memory allocations check for NULL
- [ ] Success paths don't leak resources

## References

- `src/misc.c` - Implementation of `openssl_pushresult`
- `src/digest.c` - Examples of proper digest context handling
- `src/cipher.c` - Examples of proper cipher context handling
- `src/pkey.c` - Examples of proper key context handling

## Version History

- 2025-01-10: Initial version - Document current error handling patterns
