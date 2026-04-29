# KDF Module Usage Guide

The KDF (Key Derivation Function) module in lua-openssl provides access to various key derivation algorithms available in OpenSSL 3.0+.

## Table of Contents

1. [Overview](#overview)
2. [Basic Usage](#basic-usage)
3. [Available KDF Algorithms](#available-kdf-algorithms)
4. [Detailed Examples](#detailed-examples)
5. [Best Practices](#best-practices)

## Overview

Key Derivation Functions (KDFs) are cryptographic algorithms that derive one or more secret keys from a secret value such as a master key, password, or passphrase. They are essential for:

- Password-based encryption
- Key agreement protocols
- Deriving multiple keys from a single master key
- TLS/SSL key derivation
- SSH key derivation

## Basic Usage

### Checking Available KDFs

```lua
local openssl = require("openssl")
local kdf = require("openssl").kdf

-- List all available KDF algorithms
if kdf.iterator then
  kdf.iterator(function(k)
    print(k:name())
  end)
end
```

### Using a KDF (OpenSSL 3.0+)

```lua
-- Fetch a specific KDF algorithm
local pbkdf2 = kdf.fetch("PBKDF2")

-- Derive a key
local key = pbkdf2:derive({
  {
    name = "pass",
    data = "my_password",
  },
  {
    name = "salt",
    data = "random_salt",
  },
  {
    name = "digest",
    data = "SHA2-256",
  },
  {
    name = "iter",
    data = 100000,
  },
}, 32)  -- 32 bytes output length

print("Derived key: " .. openssl.hex(key))
```

### Legacy API (OpenSSL < 3.0)

```lua
-- For OpenSSL versions before 3.0
local key = kdf.derive(
  "my_password",  -- password
  "random_salt",  -- salt
  "sha256",       -- digest
  100000,         -- iterations
  32              -- key length
)
```

## Available KDF Algorithms

### Password-Based KDFs

#### PBKDF2 (Recommended for Password Hashing)

PBKDF2 (Password-Based Key Derivation Function 2) is widely used and standardized (RFC 2898).

```lua
local pbkdf2 = kdf.fetch("PBKDF2")

local key = pbkdf2:derive({
  {
    name = "pass",
    data = "user_password",
  },
  {
    name = "salt",
    data = openssl.random(16),  -- Generate random salt
  },
  {
    name = "digest",
    data = "SHA2-256",
  },
  {
    name = "iter",
    data = 100000,  -- Higher = more secure but slower
  },
}, 32)
```

**Recommended parameters:**
- Iterations: 100,000+ (OWASP recommendation as of 2023)
- Salt: 16+ bytes of random data
- Digest: SHA2-256 or SHA2-512

#### SCRYPT (High Security)

SCRYPT is designed to be more resistant to hardware brute-force attacks by requiring significant memory.

```lua
local scrypt = kdf.fetch("SCRYPT")

local key = scrypt:derive({
  {
    name = "pass",
    data = "user_password",
  },
  {
    name = "salt",
    data = openssl.random(16),
  },
  {
    name = "n",
    data = 32768,  -- CPU/memory cost (power of 2)
  },
  {
    name = "r",
    data = 8,      -- Block size
  },
  {
    name = "p",
    data = 1,      -- Parallelization factor
  },
}, 32)
```

**Recommended parameters:**
- N: 32768 or higher (power of 2)
- r: 8
- p: 1
- Salt: 16+ bytes of random data

#### Argon2 (OpenSSL 3.2+)

Argon2 is the winner of the Password Hashing Competition (PHC) and is recommended for new applications. It comes in three variants:
- **ARGON2ID**: Recommended for most use cases (hybrid approach)
- **ARGON2I**: Data-independent, resistant to side-channel attacks
- **ARGON2D**: Data-dependent, faster but vulnerable to side-channel attacks

```lua
-- Argon2id is recommended for password hashing
local argon2id = kdf.fetch("ARGON2ID")
if not argon2id then
  -- Argon2 not available (requires OpenSSL 3.2+)
  -- Fall back to SCRYPT or PBKDF2
end

local key = argon2id:derive({
  {
    name = "pass",
    data = "user_password",
  },
  {
    name = "salt",
    data = openssl.random(16),  -- Minimum 8 bytes
  },
  {
    name = "lanes",
    data = 4,      -- Parallelism (p in Argon2 spec)
  },
  {
    name = "memcost",
    data = 65536,  -- Memory cost in KB (64 MB)
  },
  {
    name = "iter",
    data = 3,      -- Time cost (iterations)
  },
  {
    name = "threads",
    data = 4,      -- Number of threads to use
  },
}, 32)
```

**Optional parameters:**
- `ad`: Associated data (additional context)
- `secret`: Secret key for keyed hashing

```lua
-- Using optional parameters
local secret_key = openssl.random(16)  -- Generate a secret key

local key = argon2id:derive({
  {
    name = "pass",
    data = "user_password",
  },
  {
    name = "salt",
    data = openssl.random(16),
  },
  {
    name = "ad",
    data = "context info",  -- Associated data
  },
  {
    name = "secret",
    data = secret_key,      -- Optional secret key
  },
  {
    name = "lanes",
    data = 4,
  },
  {
    name = "memcost",
    data = 65536,
  },
  {
    name = "iter",
    data = 3,
  },
  {
    name = "threads",
    data = 4,
  },
}, 32)
```

**Recommended parameters (OWASP 2024):**
- Memory (memcost): 65536 KB (64 MB) or higher
- Iterations (iter): 3 or higher
- Parallelism (lanes/threads): 4 or match your CPU cores
- Salt: 16+ bytes of random data

**Note:** Argon2 requires OpenSSL 3.2 or later. Check availability:
```lua
local argon2 = kdf.fetch("ARGON2ID")
if argon2 then
  print("Argon2 is available")
else
  print("Argon2 not available, using fallback KDF")
end
```

#### PKCS12KDF

Used in PKCS#12 files for password-based encryption.

```lua
local pkcs12kdf = kdf.fetch("PKCS12KDF")

local key = pkcs12kdf:derive({
  {
    name = "pass",
    data = "password",
  },
  {
    name = "salt",
    data = openssl.random(16),
  },
  {
    name = "digest",
    data = "SHA2-256",
  },
  {
    name = "id",
    data = 1,  -- 1=key, 2=IV, 3=MAC
  },
  {
    name = "iter",
    data = 10000,
  },
}, 32)
```

### Key Agreement KDFs

#### HKDF (HMAC-based KDF)

HKDF is a modern KDF based on HMAC, suitable for deriving multiple keys from shared secrets.

```lua
local hkdf = kdf.fetch("HKDF")

-- Derive encryption and MAC keys from a master key
local master_key = "shared_master_secret"

-- Derive encryption key
local enc_key = hkdf:derive({
  {
    name = "digest",
    data = "SHA2-256",
  },
  {
    name = "key",
    data = master_key,
  },
  {
    name = "salt",
    data = openssl.random(16),
  },
  {
    name = "info",
    data = "encryption key",  -- Context-specific info
  },
}, 32)

-- Derive MAC key
local mac_key = hkdf:derive({
  {
    name = "digest",
    data = "SHA2-256",
  },
  {
    name = "key",
    data = master_key,
  },
  {
    name = "salt",
    data = openssl.random(16),
  },
  {
    name = "info",
    data = "mac key",
  },
}, 32)
```

#### X963KDF

ANSI X9.63 KDF, commonly used with ECDH key agreement.

```lua
local x963kdf = kdf.fetch("X963KDF")

local key = x963kdf:derive({
  {
    name = "digest",
    data = "SHA2-256",
  },
  {
    name = "secret",
    data = ecdh_shared_secret,  -- From ECDH key exchange
  },
  {
    name = "info",
    data = "application context",
  },
}, 32)
```

#### SSKDF (Single-Step KDF)

Single-step key derivation function for key agreement protocols.

```lua
local sskdf = kdf.fetch("SSKDF")

local key = sskdf:derive({
  {
    name = "digest",
    data = "SHA2-256",
  },
  {
    name = "key",
    data = shared_secret,
  },
  {
    name = "info",
    data = "context information",
  },
}, 32)
```

### Protocol-Specific KDFs

#### TLS1-PRF

TLS 1.0/1.1/1.2 Pseudo-Random Function for key derivation.

```lua
local tls1prf = kdf.fetch("TLS1-PRF")

local key = tls1prf:derive({
  {
    name = "digest",
    data = "SHA2-256",
  },
  {
    name = "secret",
    data = master_secret,
  },
  {
    name = "seed",
    data = "key expansion" .. client_random .. server_random,
  },
}, 32)
```

#### KBKDF (Key-Based KDF)

Counter or feedback mode KDF for deriving keys from other keys.

```lua
local kbkdf = kdf.fetch("KBKDF")

local key = kbkdf:derive({
  {
    name = "digest",
    data = "SHA2-256",
  },
  {
    name = "key",
    data = base_key,
  },
  {
    name = "salt",
    data = context_info,
  },
  {
    name = "mode",
    data = "COUNTER",  -- or "FEEDBACK"
  },
  {
    name = "mac",
    data = "HMAC",
  },
}, 32)
```

## Detailed Examples

### Example 1: Password Storage

```lua
local openssl = require("openssl")
local kdf = require("openssl").kdf

-- Hash a password for storage
function hash_password(password)
  local pbkdf2 = kdf.fetch("PBKDF2")
  local salt = openssl.random(16)
  
  local hash = pbkdf2:derive({
    {
      name = "pass",
      data = password,
    },
    {
      name = "salt",
      data = salt,
    },
    {
      name = "digest",
      data = "SHA2-256",
    },
    {
      name = "iter",
      data = 100000,
    },
  }, 32)
  
  -- Store both salt and hash
  return {
    salt = openssl.hex(salt),
    hash = openssl.hex(hash),
    iterations = 100000,
  }
end

-- Verify a password
function verify_password(password, stored)
  local pbkdf2 = kdf.fetch("PBKDF2")
  
  local hash = pbkdf2:derive({
    {
      name = "pass",
      data = password,
    },
    {
      name = "salt",
      data = openssl.hex(stored.salt, true),  -- decode hex
    },
    {
      name = "digest",
      data = "SHA2-256",
    },
    {
      name = "iter",
      data = stored.iterations,
    },
  }, 32)
  
  return openssl.hex(hash) == stored.hash
end

-- Usage
local stored = hash_password("secret123")
print("Password hash:", stored.hash)
print("Verification:", verify_password("secret123", stored))  -- true
print("Wrong password:", verify_password("wrong", stored))     -- false
```

### Example 2: Deriving Multiple Keys from Master Key

```lua
local openssl = require("openssl")
local kdf = require("openssl").kdf

function derive_keys(master_key, salt)
  local hkdf = kdf.fetch("HKDF")
  
  -- Derive encryption key
  local enc_key = hkdf:derive({
    {
      name = "digest",
      data = "SHA2-256",
    },
    {
      name = "key",
      data = master_key,
    },
    {
      name = "salt",
      data = salt,
    },
    {
      name = "info",
      data = "AES-256 encryption key",
    },
  }, 32)
  
  -- Derive IV
  local iv = hkdf:derive({
    {
      name = "digest",
      data = "SHA2-256",
    },
    {
      name = "key",
      data = master_key,
    },
    {
      name = "salt",
      data = salt,
    },
    {
      name = "info",
      data = "AES-256 IV",
    },
  }, 16)
  
  -- Derive MAC key
  local mac_key = hkdf:derive({
    {
      name = "digest",
      data = "SHA2-256",
    },
    {
      name = "key",
      data = master_key,
    },
    {
      name = "salt",
      data = salt,
    },
    {
      name = "info",
      data = "HMAC-SHA256 key",
    },
  }, 32)
  
  return {
    encryption_key = enc_key,
    iv = iv,
    mac_key = mac_key,
  }
end

-- Usage
local master = openssl.random(32)
local salt = openssl.random(16)
local keys = derive_keys(master, salt)
print("Encryption key:", openssl.hex(keys.encryption_key))
print("IV:", openssl.hex(keys.iv))
print("MAC key:", openssl.hex(keys.mac_key))
```

### Example 3: Using KDF Context for Multiple Derivations

```lua
local openssl = require("openssl")
local kdf = require("openssl").kdf

-- Create a reusable context
local pbkdf2 = kdf.fetch("PBKDF2")
local ctx = pbkdf2:new()

local passwords = {"user1_pass", "user2_pass", "user3_pass"}
local hashes = {}

for i, password in ipairs(passwords) do
  local hash = ctx:derive({
    {
      name = "pass",
      data = password,
    },
    {
      name = "salt",
      data = openssl.random(16),
    },
    {
      name = "digest",
      data = "SHA2-256",
    },
    {
      name = "iter",
      data = 100000,
    },
  }, 32)
  
  hashes[i] = openssl.hex(hash)
  
  -- Reset context for next derivation
  ctx:reset()
end

print("Derived hashes:")
for i, hash in ipairs(hashes) do
  print(string.format("  User %d: %s", i, hash))
end
```

## Best Practices

### Security Recommendations

1. **Always use random salts**: Never reuse salts across different passwords or keys.
   ```lua
   local salt = openssl.random(16)  -- Generate fresh salt each time
   ```

2. **Use appropriate iteration counts**: Higher iterations = more security but slower.
   - PBKDF2: Minimum 100,000 iterations (OWASP 2023)
   - SCRYPT: N=32768 or higher

3. **Choose strong hash functions**: Use SHA2-256 or SHA2-512, avoid MD5 or SHA1.

4. **Store salt with hash**: You'll need the salt to verify passwords later.

5. **Use HKDF for deriving multiple keys**: Don't reuse the same key for different purposes.

### Performance Considerations

1. **Balance security and performance**:
   ```lua
   -- For user-facing applications (login)
   -- Use reasonable iterations to avoid UX issues
   local iterations = 100000  -- ~100ms on modern CPU
   
   -- For high-security offline data
   -- Use higher iterations or SCRYPT
   local iterations = 500000  -- ~500ms
   ```

2. **Consider SCRYPT for high security**:
   - More resistant to hardware attacks
   - Requires tuning for your hardware
   - Test on target system

3. **Reuse contexts when possible**:
   ```lua
   local ctx = kdf_algo:new()
   -- Derive multiple keys
   ctx:reset()  -- Reset for next derivation
   ```

### Error Handling

```lua
local pbkdf2 = kdf.fetch("PBKDF2")
if not pbkdf2 then
  error("PBKDF2 not available (OpenSSL < 3.0?)")
end

local key, err = pbkdf2:derive(params, length)
if not key then
  error("Key derivation failed: " .. tostring(err))
end
```

### Compatibility

- **OpenSSL 3.0+**: Full KDF API with all algorithms
- **OpenSSL 1.x**: Legacy `kdf.derive()` function with PBKDF2 only

Check OpenSSL version:
```lua
local openssl = require("openssl")
local version = openssl.version(true)
print("OpenSSL version:", version)

if kdf.fetch then
  print("Using modern KDF API")
else
  print("Using legacy KDF API")
end
```

## Additional Resources

- OpenSSL KDF Documentation: https://www.openssl.org/docs/man3.0/man7/EVP_KDF.html
- OpenSSL Argon2 Documentation (3.2+): https://docs.openssl.org/3.3/man7/EVP_KDF-ARGON2/
- OWASP Password Storage Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html
- RFC 2898 (PBKDF2): https://tools.ietf.org/html/rfc2898
- RFC 7914 (SCRYPT): https://tools.ietf.org/html/rfc7914
- RFC 5869 (HKDF): https://tools.ietf.org/html/rfc5869
- RFC 9106 (Argon2): https://tools.ietf.org/html/rfc9106
