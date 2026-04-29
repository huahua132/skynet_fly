/***
cipher module do encrypt or decrypt base on OpenSSL EVP API.

@module cipher
@usage
  cipher = require('openssl').cipher
@treturn various return value
*/
#include "openssl.h"
#include "private.h"

/***
list all support cipher algs

@function list
@tparam[opt] boolean alias include alias names for cipher alg, default true
@treturn[table] all cipher methods
*/
static int openssl_cipher_list(lua_State *L)
{
  int alias = lua_isnone(L, 1) ? 1 : lua_toboolean(L, 1);
  lua_newtable(L);
  OBJ_NAME_do_all_sorted(
    OBJ_NAME_TYPE_CIPHER_METH, alias ? openssl_add_method_or_alias : openssl_add_method, L);
  return 1;
}

/***
get EVP_CIPHER cipher algorithm object

This function retrieves a cipher algorithm object by name, NID, or ASN1 object.
The returned object can be used with cipher.new() to create a cipher context.

@function get
@tparam string|integer|openssl.asn1_object alg algorithm name, NID, or ASN1 object
@treturn[1] openssl.evp_cipher cipher algorithm object
@treturn[2] nil if algorithm not found
@treturn[2] string error message
@see cipher.new
@see cipher.fetch
@usage
  local cipher = require('openssl').cipher

  -- Get cipher by name
  local aes_256_cbc = cipher.get('AES-256-CBC')

  -- Get cipher by NID
  local aes_256_cbc_nid = cipher.get(423)  -- NID for AES-256-CBC

  -- Use with cipher.new()
  local ctx = cipher.new(aes_256_cbc, 'key', 'iv', true)  -- true for encryption
  local encrypted = ctx:update('data')
  encrypted = encrypted .. ctx:final()
*/
static int openssl_cipher_get(lua_State *L)
{
  const EVP_CIPHER *cipher = get_cipher(L, 1, NULL);

  PUSH_OBJECT((void *)cipher, "openssl.evp_cipher");
  return 1;
}

#if (OPENSSL_VERSION_NUMBER >= 0x30000000L) && !defined(LIBRESSL_VERSION_NUMBER)
/***
fetch evp_cipher object with provider support (OpenSSL 3.0+)

@function fetch
@tparam string alg algorithm name (e.g., 'AES-256-CBC', 'ChaCha20-Poly1305')
@tparam[opt] table options optional table with 'provider' and 'properties' fields
@treturn openssl.evp_cipher cipher object mapping EVP_CIPHER in openssl or nil on failure
@treturn string error message if failed

@usage
  -- Fetch with default provider
  local aes = cipher.fetch('AES-256-CBC')

  -- Fetch from specific provider
  local fips_aes = cipher.fetch('AES-256-CBC', {provider = 'fips', properties = 'fips=yes'})

@see evp_cipher
*/
static int openssl_cipher_fetch(lua_State *L)
{
  const char *algorithm = luaL_checkstring(L, 1);
  const char *provider = NULL;
  const char *properties = NULL;
  OSSL_LIB_CTX *libctx = NULL;  /* NULL means default context */
  EVP_CIPHER *cipher = NULL;

  /* Parse optional options table */
  if (lua_istable(L, 2)) {
    lua_getfield(L, 2, "provider");
    if (lua_isstring(L, -1)) {
      provider = lua_tostring(L, -1);
    }
    lua_pop(L, 1);

    lua_getfield(L, 2, "properties");
    if (lua_isstring(L, -1)) {
      properties = lua_tostring(L, -1);
    }
    lua_pop(L, 1);
  }

  /* If provider is specified, check if it's available */
  if (provider != NULL) {
    if (!OSSL_PROVIDER_available(libctx, provider)) {
      lua_pushnil(L);
      lua_pushfstring(L, "provider '%s' is not available", provider);
      return 2;
    }
  }

  /* Fetch the algorithm */
  cipher = EVP_CIPHER_fetch(libctx, algorithm, properties);

  if (cipher != NULL) {
    PUSH_OBJECT(cipher, "openssl.evp_cipher");
    /* Mark this as a fetched object that needs to be freed */
    lua_pushboolean(L, 1);
    lua_rawsetp(L, LUA_REGISTRYINDEX, cipher);
    return 1;
  }

  return openssl_pushresult(L, 0);
}

/***
get provider name for a cipher (OpenSSL 3.0+)

@function get_provider_name
@treturn[1] string provider name
@treturn[2] nil if cipher has no provider or provider has no name
*/
static int openssl_cipher_get_provider_name(lua_State *L)
{
  EVP_CIPHER *cipher = CHECK_OBJECT(1, EVP_CIPHER, "openssl.evp_cipher");
  const OSSL_PROVIDER *prov = EVP_CIPHER_get0_provider(cipher);

  if (prov != NULL) {
    const char *name = OSSL_PROVIDER_get0_name(prov);
    if (name != NULL) {
      lua_pushstring(L, name);
      return 1;
    }
  }

  lua_pushnil(L);
  return 1;
}

/***
free a fetched evp_cipher object (OpenSSL 3.0+)

@function __gc
@treturn nil always returns nil
*/
static int openssl_cipher_gc(lua_State *L)
{
  EVP_CIPHER *cipher = CHECK_OBJECT(1, EVP_CIPHER, "openssl.evp_cipher");

  /* Check if this is a fetched object that needs to be freed */
  lua_rawgetp(L, LUA_REGISTRYINDEX, cipher);
  if (lua_toboolean(L, -1)) {
    /* This is a fetched object, free it */
    EVP_CIPHER_free(cipher);
    /* Remove the marker */
    lua_pushnil(L);
    lua_rawsetp(L, LUA_REGISTRYINDEX, cipher);
  }
  lua_pop(L, 1);

  return 0;
}
#endif

static void
set_key_iv(const char *key,
           size_t      key_len,
           char       *evp_key,
           const char *iv,
           size_t      iv_len,
           char       *evp_iv)
{
  if (key) {
    key_len = EVP_MAX_KEY_LENGTH > key_len ? key_len : EVP_MAX_KEY_LENGTH;
    memcpy(evp_key, key, key_len);
  }
  if (iv_len > 0 && iv) {
    iv_len = EVP_MAX_IV_LENGTH > iv_len ? iv_len : EVP_MAX_IV_LENGTH;
    memcpy(evp_iv, iv, iv_len);
  }
}

/***
quick encrypt

@function encrypt
@tparam string|integer|asn1_object alg alg name, nid or object identity
@tparam string input data to encrypt
@tparam string key secret key
@tparam[opt] string iv
@tparam[opt] boolean pad true for padding default
@tparam[opt] openssl.engine engine custom crypto engine
@treturn string result encrypt data
*/
static int openssl_evp_encrypt(lua_State *L)
{
  const EVP_CIPHER *cipher = get_cipher(L, 1, NULL);
  size_t            input_len = 0;
  const char       *input = luaL_checklstring(L, 2, &input_len);
  size_t            key_len = 0;
  const char       *key = luaL_optlstring(L, 3, NULL, &key_len); /* can be NULL */
  size_t            iv_len = 0;
  const char       *iv = luaL_optlstring(L, 4, NULL, &iv_len); /* can be NULL */
  int               pad = lua_isnone(L, 5) ? 1 : lua_toboolean(L, 5);
  ENGINE           *e = lua_isnoneornil(L, 6) ? NULL : CHECK_OBJECT(6, ENGINE, "openssl.engine");

  EVP_CIPHER_CTX *c = EVP_CIPHER_CTX_new();

  int   output_len = 0;
  int   len = 0;
  char *buffer = NULL;
  char  evp_key[EVP_MAX_KEY_LENGTH] = { 0 };
  char  evp_iv[EVP_MAX_IV_LENGTH] = { 0 };
  int   ret = 0;

  set_key_iv(key, key_len, evp_key, iv, iv_len, evp_iv);

  ret = EVP_EncryptInit_ex(
    c, cipher, e, (const byte *)evp_key, iv_len > 0 ? (const byte *)evp_iv : NULL);
  if (ret == 1) {
    ret = EVP_CIPHER_CTX_set_padding(c, pad);
    if (ret == 1) {
      buffer = OPENSSL_malloc(input_len + EVP_CIPHER_CTX_block_size(c));
      if (buffer == NULL) {
        EVP_CIPHER_CTX_free(c);
        return luaL_error(L, "Memory allocation failed");
      }
      ret = EVP_EncryptUpdate(c, (byte *)buffer, &len, (const byte *)input, input_len);
      if (ret == 1) {
        output_len += len;
        ret = EVP_EncryptFinal_ex(c, (byte *)buffer + len, &len);
        if (ret == 1) {
          output_len += len;
          lua_pushlstring(L, buffer, output_len);
        }
      }
      OPENSSL_free(buffer);
    }
  }
  EVP_CIPHER_CTX_free(c);
  OPENSSL_cleanse(evp_key, sizeof(evp_key));
  OPENSSL_cleanse(evp_iv, sizeof(evp_iv));
  return (ret == 1) ? ret : openssl_pushresult(L, ret);
}

/***
quick decrypt

@function decrypt
@tparam string|integer|asn1_object alg name, nid or object identity
@tparam string input data to decrypt
@tparam string key secret key
@tparam[opt] string iv
@tparam[opt] boolean pad true for padding default
@tparam[opt] openssl.engine engine custom crypto engine
@treturn string result decrypt data
*/
static int openssl_evp_decrypt(lua_State *L)
{
  const EVP_CIPHER *cipher = get_cipher(L, 1, NULL);
  size_t            input_len = 0;
  const char       *input = luaL_checklstring(L, 2, &input_len);
  size_t            key_len = 0;
  const char       *key = luaL_optlstring(L, 3, NULL, &key_len); /* can be NULL */
  size_t            iv_len = 0;
  const char       *iv = luaL_optlstring(L, 4, NULL, &iv_len); /* can be NULL */
  int               pad = lua_isnone(L, 5) ? 1 : lua_toboolean(L, 5);
  ENGINE           *e = lua_isnoneornil(L, 6) ? NULL : CHECK_OBJECT(6, ENGINE, "openssl.engine");
  EVP_CIPHER_CTX   *c = EVP_CIPHER_CTX_new();

  int   output_len = 0;
  int   len = 0;
  char *buffer = NULL;
  char  evp_key[EVP_MAX_KEY_LENGTH] = { 0 };
  char  evp_iv[EVP_MAX_IV_LENGTH] = { 0 };
  int   ret;

  set_key_iv(key, key_len, evp_key, iv, iv_len, evp_iv);

  ret = EVP_DecryptInit_ex(
    c, cipher, e, key ? (const byte *)evp_key : NULL, iv_len > 0 ? (const byte *)evp_iv : NULL);
  if (ret == 1) {
    ret = EVP_CIPHER_CTX_set_padding(c, pad);
    if (ret == 1) {
      buffer = OPENSSL_malloc(input_len);
      if (buffer == NULL) {
        EVP_CIPHER_CTX_free(c);
        return luaL_error(L, "Memory allocation failed");
      }

      ret = EVP_DecryptUpdate(c, (byte *)buffer, &len, (const byte *)input, input_len);
      if (ret == 1) {
        output_len += len;
        len = input_len - len;
        ret = EVP_DecryptFinal_ex(c, (byte *)buffer + output_len, &len);
        if (ret == 1) {
          output_len += len;
          lua_pushlstring(L, buffer, output_len);
        }
      }
      OPENSSL_free(buffer);
    }
  }
  EVP_CIPHER_CTX_free(c);
  OPENSSL_cleanse(evp_key, sizeof(evp_key));
  OPENSSL_cleanse(evp_iv, sizeof(evp_iv));
  return (ret == 1) ? ret : openssl_pushresult(L, ret);
}

/***
quick encrypt or decrypt

@function cipher
@tparam string|integer|asn1_object alg alg name, nid or object identity
@tparam boolean encrypt true for encrypt,false for decrypt
@tparam string input data to encrypt or decrypt
@tparam string key secret key
@tparam[opt] string iv
@tparam[opt] boolean pad true for padding default
@tparam[opt] openssl.engine engine custom crypto engine
@treturn string result
*/
static int openssl_evp_cipher(lua_State *L)
{
  const EVP_CIPHER *cipher = get_cipher(L, 1, NULL);
  int               enc = lua_toboolean(L, 2);
  size_t            input_len = 0;
  const char       *input = luaL_checklstring(L, 3, &input_len);
  size_t            key_len = 0;
  const char       *key = luaL_checklstring(L, 4, &key_len);
  size_t            iv_len = 0;
  const char       *iv = luaL_optlstring(L, 5, NULL, &iv_len); /* can be NULL */

  int     pad = lua_isnone(L, 6) ? 1 : lua_toboolean(L, 6);
  ENGINE *e = lua_isnoneornil(L, 7) ? NULL : CHECK_OBJECT(7, ENGINE, "openssl.engine");

  EVP_CIPHER_CTX *c = EVP_CIPHER_CTX_new();

  int output_len = 0;
  int len = 0;

  char evp_key[EVP_MAX_KEY_LENGTH] = { 0 };
  char evp_iv[EVP_MAX_IV_LENGTH] = { 0 };

  int ret;

  set_key_iv(key, key_len, evp_key, iv, iv_len, evp_iv);

  ret = EVP_CipherInit_ex(
    c, cipher, e, (const byte *)evp_key, iv_len > 0 ? (const byte *)evp_iv : NULL, enc);
  if (ret == 1) {
    ret = EVP_CIPHER_CTX_set_padding(c, pad);
    if (ret == 1) {
      char *buffer;
      len = input_len + EVP_MAX_BLOCK_LENGTH;
      buffer = OPENSSL_malloc(len);
      ret = EVP_CipherUpdate(c, (byte *)buffer, &len, (const byte *)input, input_len);
      if (ret == 1) {
        output_len += len;
        len = input_len + EVP_MAX_BLOCK_LENGTH - len;
        ret = EVP_CipherFinal_ex(c, (byte *)buffer + output_len, &len);
        if (ret == 1) {
          output_len += len;
          lua_pushlstring(L, buffer, output_len);
        }
      }
      OPENSSL_free(buffer);
    }
  }
  EVP_CIPHER_CTX_free(c);
  OPENSSL_cleanse(evp_key, sizeof(evp_key));
  OPENSSL_cleanse(evp_iv, sizeof(evp_iv));
  return (ret == 1) ? ret : openssl_pushresult(L, ret);
}

typedef enum
{
  DO_CIPHER = 0,
  DO_ENCRYPT = 1,
  DO_DECRYPT = 2
} CIPHER_MODE;

/***
create EVP_CIPHER_CTX cipher context for encryption or decryption

This function creates a new cipher context for the specified algorithm.
The context can be used for encryption or decryption operations.

@function new
@tparam string|integer|openssl.asn1_object|openssl.evp_cipher alg algorithm name, NID, ASN1 object, or cipher object
@tparam boolean encrypt true for encryption, false for decryption
@tparam[opt] string key secret key (required for most ciphers)
@tparam[opt] string iv initialization vector (required for CBC mode)
@tparam[opt=true] boolean pad true for PKCS#7 padding
@tparam[opt] openssl.engine engine custom crypto engine
@treturn[1] openssl.evp_cipher_ctx cipher context object
@treturn[2] nil on error
@treturn[2] string error message
@see cipher.get
@see cipher.fetch
@usage
  local cipher = require('openssl').cipher

  -- Create AES-256-CBC encryption context
  local ctx = cipher.new('AES-256-CBC', true, '32_byte_key_here', '16_byte_iv_here')

  -- Create context from cipher object
  local aes = cipher.get('AES-256-CBC')
  local ctx2 = cipher.new(aes, false, 'key', 'iv')  -- decryption context

  -- Use without padding
  local ctx3 = cipher.new('AES-256-ECB', true, 'key', nil, false)  -- no padding
*/

static int openssl_cipher_new(lua_State *L)
{
  const EVP_CIPHER *cipher = get_cipher(L, 1, NULL);
  int               enc = lua_toboolean(L, 2);
  size_t            key_len = 0;
  const char       *key = luaL_optlstring(L, 3, NULL, &key_len);
  size_t            iv_len = 0;
  const char       *iv = luaL_optlstring(L, 4, NULL, &iv_len);
  int               pad = lua_isnone(L, 5) ? 1 : lua_toboolean(L, 5);
  ENGINE           *e = lua_isnoneornil(L, 6) ? NULL : CHECK_OBJECT(6, ENGINE, "openssl.engine");
  EVP_CIPHER_CTX   *c = NULL;
  int               ret = 0;

  char evp_key[EVP_MAX_KEY_LENGTH] = { 0 };
  char evp_iv[EVP_MAX_IV_LENGTH] = { 0 };

  set_key_iv(key, key_len, evp_key, iv, iv_len, evp_iv);

  c = EVP_CIPHER_CTX_new();
  ret = EVP_CipherInit_ex(c,
                          cipher,
                          e,
                          key ? (const byte *)evp_key : NULL,
                          iv_len > 0 ? (const byte *)evp_iv : NULL,
                          enc);
  if (ret == 1) {
    EVP_CIPHER_CTX_set_padding(c, pad);
    PUSH_OBJECT(c, "openssl.evp_cipher_ctx");
    lua_pushinteger(L, DO_CIPHER);
    lua_rawsetp(L, LUA_REGISTRYINDEX, c);
    return 1;
  }
  EVP_CIPHER_CTX_free(c);
  OPENSSL_cleanse(evp_key, sizeof(evp_key));
  OPENSSL_cleanse(evp_iv, sizeof(evp_iv));
  return openssl_pushresult(L, ret);
}

/***
get evp_cipher_ctx object for encrypt

@function encrypt_new
@tparam string|integer|asn1_object alg alg name, nid or object identity
@tparam string key secret key
@tparam[opt] string iv
@tparam[opt] openssl.engine engine custom crypto engine
@tparam[opt=true] boolean pad true for padding
@treturn evp_cipher_ctx cipher object mapping EVP_CIPHER_CTX in openssl

@see evp_cipher_ctx
*/

static int openssl_cipher_encrypt_new(lua_State *L)
{
  const EVP_CIPHER *cipher = get_cipher(L, 1, NULL);
  int               ret;
  size_t            key_len = 0;
  const char       *key = luaL_optlstring(L, 2, NULL, &key_len); /* can be NULL */
  size_t            iv_len = 0;
  const char       *iv = luaL_optlstring(L, 3, NULL, &iv_len); /* can be NULL */
  ENGINE           *e = lua_isnoneornil(L, 4) ? NULL : CHECK_OBJECT(4, ENGINE, "openssl.engine");
  int               pad = lua_isnone(L, 5) ? 1 : lua_toboolean(L, 5);

  EVP_CIPHER_CTX *c = NULL;

  char evp_key[EVP_MAX_KEY_LENGTH] = { 0 };
  char evp_iv[EVP_MAX_IV_LENGTH] = { 0 };

  set_key_iv(key, key_len, evp_key, iv, iv_len, evp_iv);

  c = EVP_CIPHER_CTX_new();
  ret = EVP_EncryptInit_ex(
    c, cipher, e, key ? (const byte *)evp_key : NULL, iv_len > 0 ? (const byte *)evp_iv : NULL);
  if (ret == 1) {
    EVP_CIPHER_CTX_set_padding(c, pad);
    PUSH_OBJECT(c, "openssl.evp_cipher_ctx");
    lua_pushinteger(L, DO_ENCRYPT);
    lua_rawsetp(L, LUA_REGISTRYINDEX, c);
    return 1;
  }
  EVP_CIPHER_CTX_free(c);
  OPENSSL_cleanse(evp_key, sizeof(evp_key));
  OPENSSL_cleanse(evp_iv, sizeof(evp_iv));
  return openssl_pushresult(L, ret);
}

/***
get evp_cipher_ctx object for decrypt

@function decrypt_new
@tparam string|integer|asn1_object alg alg name, nid or object identity
@tparam string key secret key
@tparam[opt] string iv
@tparam[opt] openssl.engine engine custom crypto engine
@tparam[opt=true] boolean pad true for padding
@treturn evp_cipher_ctx cipher object mapping EVP_CIPHER_CTX in openssl

@see evp_cipher_ctx
*/

static int openssl_cipher_decrypt_new(lua_State *L)
{
  const EVP_CIPHER *cipher = get_cipher(L, 1, NULL);
  size_t            key_len = 0;
  const char       *key = luaL_optlstring(L, 2, NULL, &key_len); /* can be NULL */
  size_t            iv_len = 0;
  const char       *iv = luaL_optlstring(L, 3, NULL, &iv_len); /* can be NULL */
  ENGINE           *e = lua_isnoneornil(L, 4) ? NULL : CHECK_OBJECT(4, ENGINE, "openssl.engine");
  int               pad = lua_isnone(L, 5) ? 1 : lua_toboolean(L, 5);
  EVP_CIPHER_CTX   *c = NULL;

  char evp_key[EVP_MAX_KEY_LENGTH] = { 0 };
  char evp_iv[EVP_MAX_IV_LENGTH] = { 0 };
  int  ret;

  set_key_iv(key, key_len, evp_key, iv, iv_len, evp_iv);

  c = EVP_CIPHER_CTX_new();
  ret = EVP_DecryptInit_ex(
    c, cipher, e, key ? (const byte *)evp_key : NULL, iv_len > 0 ? (const byte *)evp_iv : NULL);
  if (ret == 1) {
    EVP_CIPHER_CTX_set_padding(c, pad);
    PUSH_OBJECT(c, "openssl.evp_cipher_ctx");
    lua_pushinteger(L, DO_DECRYPT);
    lua_rawsetp(L, LUA_REGISTRYINDEX, c);
    return 1;
  }
  EVP_CIPHER_CTX_free(c);
  OPENSSL_cleanse(evp_key, sizeof(evp_key));
  OPENSSL_cleanse(evp_iv, sizeof(evp_iv));
  return openssl_pushresult(L, ret);
}

/***
openssl.evp_cipher object
@type evp_cipher
*/
/***
get infomation of evp_cipher object

@function info
@treturn table info keys include name,block_size,key_length,iv_length,flags,mode
*/
static int openssl_cipher_info(lua_State *L)
{
  EVP_CIPHER *cipher = CHECK_OBJECT(1, EVP_CIPHER, "openssl.evp_cipher");
  lua_newtable(L);
  AUXILIAR_SET(L, -1, "name", EVP_CIPHER_name(cipher), string);
  AUXILIAR_SET(L, -1, "block_size", EVP_CIPHER_block_size(cipher), integer);
  AUXILIAR_SET(L, -1, "key_length", EVP_CIPHER_key_length(cipher), integer);
  AUXILIAR_SET(L, -1, "iv_length", EVP_CIPHER_iv_length(cipher), integer);
  AUXILIAR_SET(L, -1, "flags", EVP_CIPHER_flags(cipher), integer);
  AUXILIAR_SET(L, -1, "mode", EVP_CIPHER_mode(cipher), integer);
  return 1;
}

/***
derive key

@function BytesToKey
@tparam string data derive data
@tparam string[opt] string salt salt will get strong security
@tparam ev_digest|string md digest method used to diver key, default with 'sha1'
@treturn string key
@treturn string iv
*/
static int openssl_evp_BytesToKey(lua_State *L)
{
  EVP_CIPHER   *c = CHECK_OBJECT(1, EVP_CIPHER, "openssl.evp_cipher");
  size_t        lsalt, lk;
  const char   *k = luaL_checklstring(L, 2, &lk);
  const char   *salt = luaL_optlstring(L, 3, NULL, &lsalt);
  const EVP_MD *m = get_digest(L, 4, "sha256");
  char          key[EVP_MAX_KEY_LENGTH], iv[EVP_MAX_IV_LENGTH];
  int           ret;
  if (salt != NULL && lsalt < PKCS5_SALT_LEN) {
    lua_pushfstring(L, "salt must not shorter than %d", PKCS5_SALT_LEN);
    luaL_argerror(L, 3, lua_tostring(L, -1));
  }

  ret = EVP_BytesToKey(c,
                       m,
                       (unsigned char *)salt,
                       (unsigned char *)k,
                       lk,
                       1,
                       (unsigned char *)key,
                       (unsigned char *)iv);
  if (ret > 1) {
    lua_pushlstring(L, key, EVP_CIPHER_key_length(c));
    lua_pushlstring(L, iv, EVP_CIPHER_iv_length(c));
    return 2;
  }
  return openssl_pushresult(L, ret);
}

/***
get evp_cipher_ctx to encrypt or decrypt

@function new
@tparam boolean encrypt true for encrypt,false for decrypt
@tparam string key secret key
@tparam[opt] string iv
@tparam[opt] boolean pad true for padding default
@tparam[opt] openssl.engine engine custom crypto engine
@treturn evp_cipher_ctx evp_cipher_ctx object

@see evp_cipher_ctx
*/

/***
get evp_cipher_ctx to encrypt

@function encrypt_new
@tparam string key secret key
@tparam[opt] string iv
@tparam[opt] boolean pad true for padding default
@tparam[opt] openssl.engine engine custom crypto engine
@treturn evp_cipher_ctx evp_cipher_ctx object

@see evp_cipher_ctx
*/

/***
get evp_cipher_ctx to decrypt

@function decrypt_new
@tparam string key secret key
@tparam[opt] string iv
@tparam[opt] boolean pad true for padding default
@tparam[opt] openssl.engine engine custom crypto engine
@treturn evp_cipher_ctx evp_cipher_ctx object

@see evp_cipher_ctx
*/

/***
do encrypt or decrypt

@function cipher
@tparam boolean encrypt true for encrypt,false for decrypt
@tparam string input data to encrypt or decrypt
@tparam string key secret key
@tparam[opt] string iv
@tparam[opt] boolean pad true for padding default
@tparam[opt] openssl.engine engine custom crypto engine
@treturn string result
*/

/***
do encrypt

@function encrypt
@tparam string input data to encrypt
@tparam string key secret key
@tparam[opt] string iv
@tparam[opt] boolean pad true for padding default
@tparam[opt] openssl.engine engine custom crypto engine
@treturn string result
*/

/***
do decrypt

@function decrypt
@tparam string input data to decrypt
@tparam string key secret key
@tparam[opt] string iv
@tparam[opt] boolean pad true for padding default
@tparam[opt] openssl.engine engine custom crypto engine
@treturn string result
*/

/* evp_cipher_ctx method */
/***
openssl.evp_cipher_ctx object
@type evp_cipher_ctx
*/

/***
init encrypt/decrypt cipher ctx

@function init
@tparam string key secret key
@tparam[opt] string iv
@treturn boolean result and followd by error reason
*/

static int openssl_evp_cipher_init(lua_State *L)
{
  EVP_CIPHER_CTX *c = CHECK_OBJECT(1, EVP_CIPHER_CTX, "openssl.evp_cipher_ctx");
  int             ret;
  CIPHER_MODE     mode = 0;
  size_t          key_len = 0;
  const char     *key = luaL_checklstring(L, 2, &key_len);
  size_t          iv_len = 0;
  const char     *iv = luaL_optlstring(L, 3, NULL, &iv_len); /* can be NULL */

  lua_rawgetp(L, LUA_REGISTRYINDEX, c);
  mode = lua_tointeger(L, -1);
  lua_pop(L, 1);

  char evp_key[EVP_MAX_KEY_LENGTH] = { 0 };
  char evp_iv[EVP_MAX_IV_LENGTH] = { 0 };

  set_key_iv(key, key_len, evp_key, iv, iv_len, evp_iv);

  ret = 0;
  if (mode == DO_CIPHER) {
    int enc = lua_toboolean(L, 4);
    ret = EVP_CipherInit_ex(c,
                            NULL,
                            NULL,
                            key ? (const byte *)evp_key : NULL,
                            iv_len > 0 ? (const byte *)evp_iv : NULL,
                            enc);
  } else if (mode == DO_ENCRYPT)
    ret = EVP_EncryptInit_ex(
      c, NULL, NULL, key ? (const byte *)evp_key : NULL, iv_len > 0 ? (const byte *)evp_iv : NULL);
  else if (mode == DO_DECRYPT)
    ret = EVP_DecryptInit_ex(
      c, NULL, NULL, key ? (const byte *)evp_key : NULL, iv_len > 0 ? (const byte *)evp_iv : NULL);
  else
    luaL_error(L, "never go here");
  OPENSSL_cleanse(evp_key, sizeof(evp_key));
  OPENSSL_cleanse(evp_iv, sizeof(evp_iv));
  return openssl_pushresult(L, ret);
}

/***
feed data or set AAD to do cipher

@function update
@tparam string data message or AAD
@tparam[opt=false] boolean isAAD indicate to set AAD
@treturn string partial results, and "" when set AAD
*/
static int openssl_evp_cipher_update(lua_State *L)
{
  size_t      inl;
  const char *in;
  int         outl;
  char       *out;
  CIPHER_MODE mode;
  int         ret, isAAD = 0;

  EVP_CIPHER_CTX *c = CHECK_OBJECT(1, EVP_CIPHER_CTX, "openssl.evp_cipher_ctx");
  in = luaL_checklstring(L, 2, &inl);
  isAAD = lua_isnoneornil(L, 3) ? 0 : lua_toboolean(L, 3);
  outl = isAAD ? 0 : inl + EVP_MAX_BLOCK_LENGTH;
  out = isAAD ? 0 : OPENSSL_malloc(outl);

  lua_rawgetp(L, LUA_REGISTRYINDEX, c);
  mode = lua_tointeger(L, -1);
  lua_pop(L, 1);

  ret = 0;
  if (mode == DO_CIPHER)
    ret = EVP_CipherUpdate(c, (byte *)out, &outl, (const byte *)in, inl);
  else if (mode == DO_ENCRYPT)
    ret = EVP_EncryptUpdate(c, (byte *)out, &outl, (const byte *)in, inl);
  else if (mode == DO_DECRYPT)
    ret = EVP_DecryptUpdate(c, (byte *)out, &outl, (const byte *)in, inl);
  else
    luaL_error(L, "never go here");

  if (ret == 1) {
    if (isAAD)
      lua_pushliteral(L, "");
    else
      lua_pushlstring(L, out, outl);
  } else
    ret = openssl_pushresult(L, ret);

  OPENSSL_free(out);

  return ret;
}

/***
get result of cipher

@function final
@treturn string result last result
*/
static int openssl_evp_cipher_final(lua_State *L)
{
  EVP_CIPHER_CTX *c = CHECK_OBJECT(1, EVP_CIPHER_CTX, "openssl.evp_cipher_ctx");
  char            out[EVP_MAX_BLOCK_LENGTH];
  int             outl = sizeof(out);
  CIPHER_MODE     mode;
  int             ret = 0;

  lua_rawgetp(L, LUA_REGISTRYINDEX, c);
  mode = lua_tointeger(L, -1);

  if (mode == DO_CIPHER)
    ret = EVP_CipherFinal_ex(c, (byte *)out, &outl);
  else if (mode == DO_ENCRYPT)
    ret = EVP_EncryptFinal_ex(c, (byte *)out, &outl);
  else if (mode == DO_DECRYPT)
    ret = EVP_DecryptFinal_ex(c, (byte *)out, &outl);
  else
    luaL_error(L, "never go here");
  lua_pop(L, 1);

  if (ret == 1) {
    lua_pushlstring(L, out, outl);
    return 1;
  }
  return openssl_pushresult(L, ret);
}

/***
get infomation of evp_cipher_ctx object

@function info
@treturn table info keys include block_size,key_length,iv_length,flags,mode,nid,type, evp_cipher
*/
static int openssl_cipher_ctx_info(lua_State *L)
{
  EVP_CIPHER_CTX *ctx = CHECK_OBJECT(1, EVP_CIPHER_CTX, "openssl.evp_cipher_ctx");
#if OPENSSL_VERSION_NUMBER > 0x30000000
  const EVP_CIPHER *cipher = EVP_CIPHER_CTX_get0_cipher(ctx);
#else
  const EVP_CIPHER *cipher = EVP_CIPHER_CTX_cipher(ctx);
#endif
  lua_newtable(L);
  AUXILIAR_SET(L, -1, "block_size", EVP_CIPHER_CTX_block_size(ctx), integer);
  AUXILIAR_SET(L, -1, "key_length", EVP_CIPHER_CTX_key_length(ctx), integer);
  AUXILIAR_SET(L, -1, "iv_length", EVP_CIPHER_CTX_iv_length(ctx), integer);
  AUXILIAR_SET(L, -1, "flags", EVP_CIPHER_flags(cipher), integer);
  AUXILIAR_SET(L, -1, "nid", EVP_CIPHER_CTX_nid(ctx), integer);
  AUXILIAR_SET(L, -1, "type", EVP_CIPHER_CTX_mode(ctx), integer);
  AUXILIAR_SET(L, -1, "mode", EVP_CIPHER_CTX_type(ctx), integer);

  AUXILIAR_SETOBJECT(L, cipher, "openssl.evp_cipher", -1, "cipher");
  return 1;
}

/***
set padding mode for cipher context
@function padding
@tparam boolean pad true to enable padding, false to disable
@treturn nil no return value
*/
static int openssl_cipher_ctx_padding(lua_State *L)
{
  int             pad;
  EVP_CIPHER_CTX *ctx = CHECK_OBJECT(1, EVP_CIPHER_CTX, "openssl.evp_cipher_ctx");
  luaL_checkany(L, 2);

  pad = lua_toboolean(L, 2);
  EVP_CIPHER_CTX_set_padding(ctx, pad);
  return 0;
}

/***
control cipher context with various parameters
@function ctrl
@tparam number type control command type
@tparam number|string arg control argument
@treturn boolean|string result depends on control type
*/
static int openssl_cipher_ctx_ctrl(lua_State *L)
{
  int             ret = 0;
  EVP_CIPHER_CTX *ctx = CHECK_OBJECT(1, EVP_CIPHER_CTX, "openssl.evp_cipher_ctx");
  int             type = luaL_checkint(L, 2);
  int             arg = 0;
  void           *ptr = NULL;

  switch (type) {
  case EVP_CTRL_INIT:
    ret = EVP_CIPHER_CTX_ctrl(ctx, type, 0, NULL);
    ret = openssl_pushresult(L, ret);
    break;
#if defined(EVP_CTRL_SET_KEY_LENGTH)
  /* NOTE: libressl 4.0.0 without EVP_CTRL_SET_KEY_LENGTH */
  case EVP_CTRL_SET_KEY_LENGTH:
#endif
  case EVP_CTRL_SET_RC2_KEY_BITS:
  case EVP_CTRL_SET_RC5_ROUNDS:
  case EVP_CTRL_GCM_SET_IVLEN:  // EVP_CTRL_CCM_SET_IVLEN
    arg = luaL_checkint(L, 3);
    ret = EVP_CIPHER_CTX_ctrl(ctx, type, arg, NULL);
    ret = openssl_pushresult(L, ret);
    break;
  case EVP_CTRL_GCM_SET_TAG:  // EVP_CTRL_CCM_SET_TAG
  {
    size_t sz = 0;
    luaL_argcheck(L, lua_isnumber(L, 3) || lua_isstring(L, 3), 3, "need integer or string");

    ptr = (void *)luaL_checklstring(L, 3, &sz);
    ret = EVP_CIPHER_CTX_ctrl(ctx, type, sz, ptr);

    ret = openssl_pushresult(L, ret);
    break;
  }
  case EVP_CTRL_GET_RC2_KEY_BITS:
  case EVP_CTRL_GET_RC5_ROUNDS:
    ret = EVP_CIPHER_CTX_ctrl(ctx, type, 0, &arg);
    if (ret == 1) {
      lua_pushinteger(L, arg);
      ret = 1;
    } else
      ret = openssl_pushresult(L, ret);
  case EVP_CTRL_GCM_GET_TAG:  // EVP_CTRL_CCM_GET_TAG
  {
    char buf[16];
    arg = luaL_checkint(L, 3);
    if (arg == 4 || arg == 6 || arg == 10 || arg == 12 || arg == 14 || arg == 16) {
      ret = EVP_CIPHER_CTX_ctrl(ctx, type, arg, buf);
      if (ret == 1) {
        lua_pushlstring(L, buf, arg);
        ret = 1;
      } else
        ret = openssl_pushresult(L, ret);
    } else
      luaL_argerror(L, 3, "invalid integer, must be 4, 6, 10, 12, 14 or 16");
    break;
  }
  /*
  EVP_CTRL_RAND_KEY
  EVP_CTRL_PBE_PRF_NID
  EVP_CTRL_COPY
  EVP_CTRL_GCM_SET_IV_FIXED
  EVP_CTRL_GCM_IV_GEN
  EVP_CTRL_CCM_SET_L
  EVP_CTRL_CCM_SET_MSGLEN
  EVP_CTRL_AEAD_TLS1_AAD
  EVP_CTRL_AEAD_SET_MAC_KEY
  EVP_CTRL_GCM_SET_IV_INV
  EVP_CTRL_TLS1_1_MULTIBLOCK_AAD
  EVP_CTRL_TLS1_1_MULTIBLOCK_ENCRYPT
  EVP_CTRL_TLS1_1_MULTIBLOCK_DECRYPT
  EVP_CTRL_TLS1_1_MULTIBLOCK_MAX_BUFSIZE
  */
  default:
    luaL_error(L, "not support");
  }
  return ret;
}

/***
release cipher context resources
@function __gc
@treturn number 0
*/
static int openssl_cipher_ctx_free(lua_State *L)
{
  EVP_CIPHER_CTX *ctx = CHECK_OBJECT(1, EVP_CIPHER_CTX, "openssl.evp_cipher_ctx");
  if (!ctx) return 0;
  lua_pushnil(L);
  lua_rawsetp(L, LUA_REGISTRYINDEX, ctx);
  EVP_CIPHER_CTX_free(ctx);
  FREE_OBJECT(1);
  return 0;
}

static luaL_Reg cipher_funs[] = {
  { "info",        openssl_cipher_info        },
  { "new",         openssl_cipher_new         },
  { "encrypt_new", openssl_cipher_encrypt_new },
  { "decrypt_new", openssl_cipher_decrypt_new },

  { "BytesToKey",  openssl_evp_BytesToKey     },

  { "encrypt",     openssl_evp_encrypt        },
  { "decrypt",     openssl_evp_decrypt        },
  { "cipher",      openssl_evp_cipher         },

#if (OPENSSL_VERSION_NUMBER >= 0x30000000L) && !defined(LIBRESSL_VERSION_NUMBER)
  { "get_provider_name", openssl_cipher_get_provider_name },
  { "__gc",        openssl_cipher_gc          },
#endif

  { "__tostring",  auxiliar_tostring          },

  { NULL,          NULL                       }
};

static luaL_Reg cipher_ctx_funs[] = {
  { "init",       openssl_evp_cipher_init    },
  { "update",     openssl_evp_cipher_update  },
  { "final",      openssl_evp_cipher_final   },
  { "info",       openssl_cipher_ctx_info    },
  { "close",      openssl_cipher_ctx_free    },
  { "ctrl",       openssl_cipher_ctx_ctrl    },
  { "padding",    openssl_cipher_ctx_padding },

  { "__gc",       openssl_cipher_ctx_free    },
  { "__tostring", auxiliar_tostring          },

  { NULL,         NULL                       }
};

static const luaL_Reg R[] = {
  { "list",        openssl_cipher_list        },
  { "get",         openssl_cipher_get         },
  { "encrypt",     openssl_evp_encrypt        },
  { "decrypt",     openssl_evp_decrypt        },
  { "cipher",      openssl_evp_cipher         },

  { "new",         openssl_cipher_new         },
  { "encrypt_new", openssl_cipher_encrypt_new },
  { "decrypt_new", openssl_cipher_decrypt_new },

#if (OPENSSL_VERSION_NUMBER >= 0x30000000L) && !defined(LIBRESSL_VERSION_NUMBER)
  { "fetch",       openssl_cipher_fetch       },
#endif

  { NULL,          NULL                       }
};

static LuaL_Enumeration evp_ctrls_code[] = {
  { "EVP_CTRL_INIT",                          EVP_CTRL_INIT                          },
#if defined(EVP_CTRL_SET_KEY_LENGTH)
  { "EVP_CTRL_SET_KEY_LENGTH",                EVP_CTRL_SET_KEY_LENGTH                },
#endif
  { "EVP_CTRL_GET_RC2_KEY_BITS",              EVP_CTRL_GET_RC2_KEY_BITS              },
  { "EVP_CTRL_SET_RC2_KEY_BITS",              EVP_CTRL_SET_RC2_KEY_BITS              },
  { "EVP_CTRL_GET_RC5_ROUNDS",                EVP_CTRL_GET_RC5_ROUNDS                },
  { "EVP_CTRL_SET_RC5_ROUNDS",                EVP_CTRL_SET_RC5_ROUNDS                },
  { "EVP_CTRL_RAND_KEY",                      EVP_CTRL_RAND_KEY                      },
  { "EVP_CTRL_PBE_PRF_NID",                   EVP_CTRL_PBE_PRF_NID                   },
  { "EVP_CTRL_COPY",                          EVP_CTRL_COPY                          },
  { "EVP_CTRL_GCM_SET_IVLEN",                 EVP_CTRL_GCM_SET_IVLEN                 },
  { "EVP_CTRL_GCM_GET_TAG",                   EVP_CTRL_GCM_GET_TAG                   },
  { "EVP_CTRL_GCM_SET_TAG",                   EVP_CTRL_GCM_SET_TAG                   },
  { "EVP_CTRL_GCM_SET_IV_FIXED",              EVP_CTRL_GCM_SET_IV_FIXED              },
  { "EVP_CTRL_GCM_IV_GEN",                    EVP_CTRL_GCM_IV_GEN                    },
  { "EVP_CTRL_CCM_SET_IVLEN",                 EVP_CTRL_GCM_SET_IVLEN                 },
  { "EVP_CTRL_CCM_GET_TAG",                   EVP_CTRL_CCM_GET_TAG                   },
  { "EVP_CTRL_CCM_SET_TAG",                   EVP_CTRL_CCM_SET_TAG                   },
  { "EVP_CTRL_CCM_SET_L",                     EVP_CTRL_CCM_SET_L                     },
  { "EVP_CTRL_CCM_SET_MSGLEN",                EVP_CTRL_CCM_SET_MSGLEN                },
  { "EVP_CTRL_AEAD_TLS1_AAD",                 EVP_CTRL_AEAD_TLS1_AAD                 },
  { "EVP_CTRL_AEAD_SET_MAC_KEY",              EVP_CTRL_AEAD_SET_MAC_KEY              },
  { "EVP_CTRL_GCM_SET_IV_INV",                EVP_CTRL_GCM_SET_IV_INV                },

#if OPENSSL_VERSION_NUMBER >= 0x10002000L && !defined(LIBRESSL_VERSION_NUMBER)
  { "EVP_CTRL_TLS1_1_MULTIBLOCK_AAD",         EVP_CTRL_TLS1_1_MULTIBLOCK_AAD         },
  { "EVP_CTRL_TLS1_1_MULTIBLOCK_ENCRYPT",     EVP_CTRL_TLS1_1_MULTIBLOCK_ENCRYPT     },
  { "EVP_CTRL_TLS1_1_MULTIBLOCK_DECRYPT",     EVP_CTRL_TLS1_1_MULTIBLOCK_DECRYPT     },
  { "EVP_CTRL_TLS1_1_MULTIBLOCK_MAX_BUFSIZE", EVP_CTRL_TLS1_1_MULTIBLOCK_MAX_BUFSIZE },
#endif

  { NULL,                                     -1                                     }
};

/***
EVP_CIPHER cipher algorithm object

This object represents an OpenSSL EVP_CIPHER cipher algorithm.
It can be obtained using cipher.get() or cipher.fetch().

@type openssl.evp_cipher
*/

/***
EVP_CIPHER_CTX cipher context object

This object represents an OpenSSL EVP_CIPHER_CTX cipher context.
It is created using cipher.new() and used for encryption/decryption operations.

@type openssl.evp_cipher_ctx
*/

int
luaopen_cipher(lua_State *L)
{
  auxiliar_newclass(L, "openssl.evp_cipher", cipher_funs);
  auxiliar_newclass(L, "openssl.evp_cipher_ctx", cipher_ctx_funs);

  lua_newtable(L);
  luaL_setfuncs(L, R, 0);
  auxiliar_enumerate(L, -1, evp_ctrls_code);

  return 1;
}
