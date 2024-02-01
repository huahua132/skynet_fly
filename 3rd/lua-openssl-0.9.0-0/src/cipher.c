/***
cipher module do encrypt or decrypt base on OpenSSL EVP API.

@module cipher
@usage
  cipher = require('openssl').cipher
*/
#include "openssl.h"
#include "private.h"

/***
list all support cipher algs

@function list
@tparam[opt] boolean alias include alias names for cipher alg, default true
@treturn[table] all cipher methods
*/
static LUA_FUNCTION(openssl_cipher_list)
{
  int alias = lua_isnone(L, 1) ? 1 : lua_toboolean(L, 1);
  lua_newtable(L);
  OBJ_NAME_do_all_sorted(OBJ_NAME_TYPE_CIPHER_METH, alias ? openssl_add_method_or_alias : openssl_add_method, L);
  return 1;
}

/***
get evp_cipher object

@function get
@tparam string|integer|asn1_object alg name, nid or object identity
@treturn evp_cipher cipher object mapping EVP_MD in openssl

@see evp_cipher
*/
static LUA_FUNCTION(openssl_cipher_get)
{
  if (!lua_isuserdata(L, 1))
  {
    const EVP_CIPHER* cipher = get_cipher(L, 1, NULL);

    if (cipher)
      PUSH_OBJECT((void*)cipher, "openssl.evp_cipher");
    else
      lua_pushnil(L);
  }
  else
  {
    luaL_argcheck(L, auxiliar_getclassudata(L, "openssl.evp_cipher", 1), 1, "only accept openssl.evp_cipher object");
    lua_pushvalue(L, 1);
  }
  return 1;
}

/***
quick encrypt

@function encrypt
@tparam string|integer|asn1_object alg name, nid or object identity
@tparam string input data to encrypt
@tparam string key secret key
@tparam[opt] string iv
@tparam[opt] boolean pad true for padding default
@tparam[opt] engine engine custom crypto engine
@treturn string result encrypt data
*/
static LUA_FUNCTION(openssl_evp_encrypt)
{
  const EVP_CIPHER* cipher  = get_cipher(L, 1, NULL);
  if (cipher)
  {
    size_t input_len = 0;
    const char *input = luaL_checklstring(L, 2, &input_len);
    size_t key_len = 0;
    const char *key = luaL_optlstring(L, 3, NULL, &key_len); /* can be NULL */
    size_t iv_len = 0;
    const char *iv = luaL_optlstring(L, 4, NULL, &iv_len);   /* can be NULL */
    int pad = lua_isnone(L, 5) ? 1 : lua_toboolean(L, 5);
    ENGINE *e = lua_isnoneornil(L, 6) ? NULL : CHECK_OBJECT(6, ENGINE, "openssl.engine");

    EVP_CIPHER_CTX *c = EVP_CIPHER_CTX_new();

    int output_len = 0;
    int len = 0;
    char *buffer = NULL;
    char evp_key[EVP_MAX_KEY_LENGTH] = {0};
    char evp_iv[EVP_MAX_IV_LENGTH] = {0};
    int ret = 0;

    if (key)
    {
      key_len = EVP_MAX_KEY_LENGTH > key_len ? key_len : EVP_MAX_KEY_LENGTH;
      memcpy(evp_key, key, key_len);
    }
    if (iv_len > 0 && iv)
    {
      iv_len = EVP_MAX_IV_LENGTH > iv_len ? iv_len : EVP_MAX_IV_LENGTH;
      memcpy(evp_iv, iv, iv_len);
    }

    ret = EVP_EncryptInit_ex(c, cipher, e,
                             (const byte*)evp_key,
                             iv_len > 0 ? (const byte*)evp_iv : NULL);
    if (ret == 1)
    {
      ret = EVP_CIPHER_CTX_set_padding(c, pad);
      if (ret == 1)
      {
        buffer = OPENSSL_malloc(input_len + EVP_CIPHER_CTX_block_size(c));
        ret = EVP_EncryptUpdate(c, (byte*) buffer, &len, (const byte*)input, input_len);
        if ( ret == 1 )
        {
          output_len += len;
          ret = EVP_EncryptFinal_ex(c, (byte*)buffer + len, &len);
          if (ret == 1)
          {
            output_len += len;
            lua_pushlstring(L,  buffer, output_len);
          }
        }
        OPENSSL_free(buffer);
      }
    }
    EVP_CIPHER_CTX_free(c);
    return (ret == 1) ? ret : openssl_pushresult(L, ret);
  }
  else
    luaL_error(L, "argument #1 is not a valid cipher algorithm or openssl.evp_cipher object");
  return 0;
}

/***
quick decrypt

@function decrypt
@tparam string|integer|asn1_object alg name, nid or object identity
@tparam string input data to decrypt
@tparam string key secret key
@tparam[opt] string iv
@tparam[opt] boolean pad true for padding default
@tparam[opt] engine engine custom crypto engine
@treturn string result decrypt data
*/
static LUA_FUNCTION(openssl_evp_decrypt)
{
  const EVP_CIPHER* cipher = get_cipher(L, 1, NULL);
  if (cipher)
  {
    size_t input_len = 0;
    const char *input = luaL_checklstring(L, 2, &input_len);
    size_t key_len = 0;
    const char *key = luaL_optlstring(L, 3, NULL, &key_len); /* can be NULL */
    size_t iv_len = 0;
    const char *iv = luaL_optlstring(L, 4, NULL, &iv_len); /* can be NULL */
    int pad = lua_isnone(L, 5) ? 1 : lua_toboolean(L, 5);
    ENGINE *e = lua_isnoneornil(L, 6) ? NULL : CHECK_OBJECT(6, ENGINE, "openssl.engine");
    EVP_CIPHER_CTX *c = EVP_CIPHER_CTX_new();

    int output_len = 0;
    int len = 0;
    char *buffer = NULL;
    char evp_key[EVP_MAX_KEY_LENGTH] = {0};
    char evp_iv[EVP_MAX_IV_LENGTH] = {0};
    int ret;
    if (key)
    {
      key_len = EVP_MAX_KEY_LENGTH > key_len ? key_len : EVP_MAX_KEY_LENGTH;
      memcpy(evp_key, key, key_len);
    }
    if (iv_len > 0 && iv)
    {
      iv_len = EVP_MAX_IV_LENGTH > iv_len ? iv_len : EVP_MAX_IV_LENGTH;
      memcpy(evp_iv, iv, iv_len);
    }

    ret = EVP_DecryptInit_ex(c, cipher, e,
                             key ? (const byte*)evp_key : NULL,
                             iv_len > 0 ? (const byte*)evp_iv : NULL);
    if (ret == 1)
    {
      ret = EVP_CIPHER_CTX_set_padding(c, pad);
      if (ret == 1)
      {
        buffer = OPENSSL_malloc(input_len);

        ret = EVP_DecryptUpdate(c, (byte*)buffer, &len, (const byte*)input, input_len);
        if (ret == 1)
        {
          output_len += len;
          len = input_len - len;
          ret = EVP_DecryptFinal_ex(c, (byte*)buffer + output_len, &len);
          if (ret == 1)
          {
            output_len += len;
            lua_pushlstring(L, buffer, output_len);
          }
        }
        OPENSSL_free(buffer);
      }
    }
    EVP_CIPHER_CTX_free(c);
    return (ret == 1) ? ret : openssl_pushresult(L, ret);
  }
  else
    luaL_argerror(L, 1, "invalid cipher algorithm or openssl.evp_cipher object");
  return 0;
}

/***
quick encrypt or decrypt

@function cipher
@tparam string|integer|asn1_object alg name, nid or object identity
@tparam boolean encrypt true for encrypt,false for decrypt
@tparam string input data to encrypt or decrypt
@tparam string key secret key
@tparam[opt] string iv
@tparam[opt] boolean pad true for padding default
@tparam[opt] engine engine custom crypto engine
@treturn string result
*/
static LUA_FUNCTION(openssl_evp_cipher)
{
  const EVP_CIPHER* cipher = get_cipher(L, 1, NULL);

  if (cipher)
  {
    int enc = lua_toboolean(L, 2);
    size_t input_len = 0;
    const char *input = luaL_checklstring(L, 3, &input_len);
    size_t key_len = 0;
    const char *key = luaL_checklstring(L, 4, &key_len);
    size_t iv_len = 0;
    const char *iv = luaL_optlstring(L, 5, NULL, &iv_len); /* can be NULL */

    int pad = lua_isnone(L, 6) ? 1 : lua_toboolean(L, 6);
    ENGINE *e = lua_isnoneornil(L, 7) ? NULL : CHECK_OBJECT(7, ENGINE, "openssl.engine");

    EVP_CIPHER_CTX *c = EVP_CIPHER_CTX_new();

    int output_len = 0;
    int len = 0;

    char evp_key[EVP_MAX_KEY_LENGTH] = {0};
    char evp_iv[EVP_MAX_IV_LENGTH] = {0};

    int ret;

    if (key)
    {
      key_len = EVP_MAX_KEY_LENGTH > key_len ? key_len : EVP_MAX_KEY_LENGTH;
      memcpy(evp_key, key, key_len);
    }
    if (iv_len > 0 && iv)
    {
      iv_len = EVP_MAX_IV_LENGTH > iv_len ? iv_len : EVP_MAX_IV_LENGTH;
      memcpy(evp_iv, iv, iv_len);
    }

    ret = EVP_CipherInit_ex(c, cipher, e,
                            (const byte*)evp_key,
                            iv_len > 0 ? (const byte*)evp_iv : NULL,
                            enc);
    if (ret == 1)
    {
      ret = EVP_CIPHER_CTX_set_padding(c, pad);
      if (ret == 1)
      {
        char *buffer;
        len = input_len + EVP_MAX_BLOCK_LENGTH;
        buffer = OPENSSL_malloc(len);
        ret = EVP_CipherUpdate(c, (byte*)buffer, &len, (const byte*)input, input_len);
        if (ret == 1)
        {
          output_len += len;
          len = input_len + EVP_MAX_BLOCK_LENGTH - len;
          ret = EVP_CipherFinal_ex(c, (byte*)buffer + output_len, &len);
          if (ret == 1)
          {
            output_len += len;
            lua_pushlstring(L, buffer, output_len);
          }
        }
        OPENSSL_free(buffer);
      }
    }
    EVP_CIPHER_CTX_free(c);
    return (ret == 1) ? ret : openssl_pushresult(L, ret);
  }
  else
    luaL_argerror(L, 1, "invvalid cipher algorithm or openssl.evp_cipher object");

  return 0;
}

typedef enum
{
  DO_CIPHER = 0,
  DO_ENCRYPT = 1,
  DO_DECRYPT = 2
} CIPHER_MODE;

/***
get evp_cipher_ctx object for encrypt or decrypt

@function new
@tparam string|integer|asn1_object alg name, nid or object identity
@tparam boolean encrypt true for encrypt,false for decrypt
@tparam[opt] string key secret key
@tparam[opt] string iv
@tparam[opt] boolean pad true for padding default
@tparam[opt] engine engine custom crypto engine
@treturn evp_cipher_ctx cipher object mapping EVP_CIPHER_CTX in openssl

@see evp_cipher_ctx
*/

static LUA_FUNCTION(openssl_cipher_new)
{
  const EVP_CIPHER* cipher = get_cipher(L, 1, NULL);
  if (cipher)
  {
    int enc = lua_toboolean(L, 2);
    size_t key_len = 0;
    const char *key = luaL_optlstring(L, 3, NULL, &key_len);
    size_t iv_len = 0;
    const char *iv = luaL_optlstring(L, 4, NULL, &iv_len);
    int pad = lua_isnone(L, 5) ? 1 : lua_toboolean(L, 5);
    ENGINE *e = lua_isnoneornil(L, 6) ? NULL : CHECK_OBJECT(6, ENGINE, "openssl.engine");
    EVP_CIPHER_CTX *c = NULL;

    char evp_key[EVP_MAX_KEY_LENGTH] = {0};
    char evp_iv[EVP_MAX_IV_LENGTH] = {0};
    if (key)
    {
      key_len = EVP_MAX_KEY_LENGTH > key_len ? key_len : EVP_MAX_KEY_LENGTH;
      memcpy(evp_key, key, key_len);
    }
    if (iv_len > 0 && iv)
    {
      iv_len = EVP_MAX_IV_LENGTH > iv_len ? iv_len : EVP_MAX_IV_LENGTH;
      memcpy(evp_iv, iv, iv_len);
    }
    c = EVP_CIPHER_CTX_new();
    if (!EVP_CipherInit_ex(c, cipher, e,
                           key ? (const byte*)evp_key : NULL,
                           iv_len > 0 ? (const byte*)evp_iv : NULL,
                           enc))
    {
      luaL_error(L, "EVP_CipherInit_ex failed, please check openssl error");
    }
    EVP_CIPHER_CTX_set_padding(c, pad);
    PUSH_OBJECT(c, "openssl.evp_cipher_ctx");
    lua_pushinteger(L, DO_CIPHER);
    lua_rawsetp(L, LUA_REGISTRYINDEX, c);
  }
  else
    luaL_error(L, "argument #1 is not a valid cipher algorithm or openssl.evp_cipher object");

  return 1;
}

/***
get evp_cipher_ctx object for encrypt

@function encrypt_new
@tparam string|integer|asn1_object alg name, nid or object identity
@tparam string key secret key
@tparam[opt] string iv
@tparam[opt] engine engine custom crypto engine
@treturn evp_cipher_ctx cipher object mapping EVP_CIPHER_CTX in openssl

@see evp_cipher_ctx
*/

static LUA_FUNCTION(openssl_cipher_encrypt_new)
{
  const EVP_CIPHER* cipher  = get_cipher(L, 1, NULL);
  if (cipher)
  {
    int ret;
    size_t key_len = 0;
    const char *key = luaL_optlstring(L, 2, NULL, &key_len); /* can be NULL */
    size_t iv_len = 0;
    const char *iv = luaL_optlstring(L, 3, NULL, &iv_len); /* can be NULL */
    ENGINE *e = lua_isnoneornil(L, 4) ? NULL : CHECK_OBJECT(4, ENGINE, "openssl.engine");
    EVP_CIPHER_CTX *c = NULL;

    char evp_key[EVP_MAX_KEY_LENGTH] = {0};
    char evp_iv[EVP_MAX_IV_LENGTH] = {0};
    if (key)
    {
      key_len = EVP_MAX_KEY_LENGTH > key_len ? key_len : EVP_MAX_KEY_LENGTH;
      memcpy(evp_key, key, key_len);
    }
    if (iv_len > 0 && iv)
    {
      iv_len = EVP_MAX_IV_LENGTH > iv_len ? iv_len : EVP_MAX_IV_LENGTH;
      memcpy(evp_iv, iv, iv_len);
    }
    c = EVP_CIPHER_CTX_new();
    ret = EVP_EncryptInit_ex(c, cipher, e,
                             key ? (const byte*)evp_key : NULL,
                             iv_len > 0 ? (const byte*)evp_iv : NULL);
    if (ret==1)
    {
      PUSH_OBJECT(c, "openssl.evp_cipher_ctx");
      lua_pushinteger(L, DO_ENCRYPT);
      lua_rawsetp(L, LUA_REGISTRYINDEX, c);
      return 1;
    }
    EVP_CIPHER_CTX_free(c);
    return openssl_pushresult(L, ret);
  }
  else
    luaL_error(L, "argument #1 is not a valid cipher algorithm or openssl.evp_cipher object");

  return 0;
}

/***
get evp_cipher_ctx object for decrypt

@function decrypt_new
@tparam string|integer|asn1_object alg name, nid or object identity
@tparam string key secret key
@tparam[opt] string iv
@tparam[opt] engine engine custom crypto engine
@treturn evp_cipher_ctx cipher object mapping EVP_CIPHER_CTX in openssl

@see evp_cipher_ctx
*/

static LUA_FUNCTION(openssl_cipher_decrypt_new)
{
  const EVP_CIPHER* cipher = get_cipher(L, 1, NULL);
  if (cipher)
  {
    size_t key_len = 0;
    const char *key = luaL_optlstring(L, 2, NULL, &key_len); /* can be NULL */
    size_t iv_len = 0;
    const char *iv = luaL_optlstring(L, 3, NULL, &iv_len); /* can be NULL */
    ENGINE *e = lua_isnoneornil(L, 4) ? NULL : CHECK_OBJECT(4, ENGINE, "openssl.engine");
    EVP_CIPHER_CTX *c = NULL;

    char evp_key[EVP_MAX_KEY_LENGTH] = {0};
    char evp_iv[EVP_MAX_IV_LENGTH] = {0};
    int ret;

    if (key)
    {
      key_len = EVP_MAX_KEY_LENGTH > key_len ? key_len : EVP_MAX_KEY_LENGTH;
      memcpy(evp_key, key, key_len);
    }
    if (iv_len > 0 && iv)
    {
      iv_len = EVP_MAX_IV_LENGTH > iv_len ? iv_len : EVP_MAX_IV_LENGTH;
      memcpy(evp_iv, iv, iv_len);
    }
    c = EVP_CIPHER_CTX_new();
    ret = EVP_DecryptInit_ex(c, cipher, e,
                             key ? (const byte*)evp_key : NULL,
                             iv_len > 0 ? (const byte*)evp_iv : NULL);
    if (ret == 1)
    {
      PUSH_OBJECT(c, "openssl.evp_cipher_ctx");
      lua_pushinteger(L, DO_DECRYPT);
      lua_rawsetp(L, LUA_REGISTRYINDEX, c);
      return 1;
    }
    EVP_CIPHER_CTX_free(c);
    return openssl_pushresult(L, ret);
  }
  else
    luaL_argerror(L, 1, "invalid cipher algorithm or openssl.evp_cipher object");

  return 0;
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
static LUA_FUNCTION(openssl_cipher_info)
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
static LUA_FUNCTION(openssl_evp_BytesToKey)
{
  EVP_CIPHER* c = CHECK_OBJECT(1, EVP_CIPHER, "openssl.evp_cipher");
  size_t lsalt, lk;
  const char* k = luaL_checklstring(L, 2, &lk);
  const char* salt = luaL_optlstring(L, 3, NULL, &lsalt);
  const EVP_MD* m = get_digest(L, 4, "sha256");
  char key[EVP_MAX_KEY_LENGTH], iv[EVP_MAX_IV_LENGTH];
  int ret;
  if (salt != NULL && lsalt < PKCS5_SALT_LEN)
  {
    lua_pushfstring(L, "salt must not shorter than %d", PKCS5_SALT_LEN);
    luaL_argerror(L, 3, lua_tostring(L, -1));
  }

  ret = EVP_BytesToKey(c, m, (unsigned char*)salt, (unsigned char*)k, lk, 1, (unsigned char*)key, (unsigned char*)iv);
  if (ret > 1)
  {
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
@tparam[opt] engine engine custom crypto engine
@treturn evp_cipher_ctx evp_cipher_ctx object

@see evp_cipher_ctx
*/

/***
get evp_cipher_ctx to encrypt

@function encrypt_new
@tparam string key secret key
@tparam[opt] string iv
@tparam[opt] boolean pad true for padding default
@tparam[opt] engine engine custom crypto engine
@treturn evp_cipher_ctx evp_cipher_ctx object

@see evp_cipher_ctx
*/

/***
get evp_cipher_ctx to decrypt

@function decrypt_new
@tparam string key secret key
@tparam[opt] string iv
@tparam[opt] boolean pad true for padding default
@tparam[opt] engine engine custom crypto engine
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
@tparam[opt] engine engine custom crypto engine
@treturn string result
*/

/***
do encrypt

@function encrypt
@tparam string input data to encrypt
@tparam string key secret key
@tparam[opt] string iv
@tparam[opt] boolean pad true for padding default
@tparam[opt] engine engine custom crypto engine
@treturn string result
*/

/***
do decrypt

@function decrypt
@tparam string input data to decrypt
@tparam string key secret key
@tparam[opt] string iv
@tparam[opt] boolean pad true for padding default
@tparam[opt] engine engine custom crypto engine
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

static LUA_FUNCTION(openssl_evp_cipher_init)
{
  EVP_CIPHER_CTX* c = CHECK_OBJECT(1, EVP_CIPHER_CTX, "openssl.evp_cipher_ctx");
  int ret;
  CIPHER_MODE mode = 0;
  size_t key_len = 0;
  const char *key = luaL_checklstring(L, 2, &key_len);
  size_t iv_len = 0;
  const char *iv = luaL_optlstring(L, 3, NULL, &iv_len); /* can be NULL */
  int enc = lua_toboolean(L, 4);

  lua_rawgetp(L, LUA_REGISTRYINDEX, c);
  mode = lua_tointeger(L, -1);
  lua_pop(L, 1);

  char evp_key[EVP_MAX_KEY_LENGTH] = {0};
  char evp_iv[EVP_MAX_IV_LENGTH] = {0};
  if (key)
  {
    key_len = EVP_MAX_KEY_LENGTH > key_len ? key_len : EVP_MAX_KEY_LENGTH;
    memcpy(evp_key, key, key_len);
  }
  if (iv_len > 0 && iv)
  {
    iv_len = EVP_MAX_IV_LENGTH > iv_len ? iv_len : EVP_MAX_IV_LENGTH;
    memcpy(evp_iv, iv, iv_len);
  }

  ret = 0;
  if (mode == DO_CIPHER)
    ret = EVP_CipherInit_ex(c, NULL, NULL,
                            key ? (const byte*)evp_key : NULL,
                            iv_len > 0 ? (const byte*)evp_iv : NULL, enc);
  else if (mode == DO_ENCRYPT)
    ret = EVP_EncryptInit_ex(c, NULL, NULL,
                             key ? (const byte*)evp_key : NULL,
                             iv_len > 0 ? (const byte*)evp_iv : NULL);
  else if (mode == DO_DECRYPT)
    ret = EVP_DecryptInit_ex(c, NULL, NULL,
                             key ? (const byte*)evp_key : NULL,
                             iv_len > 0 ? (const byte*)evp_iv : NULL);
  else
    luaL_error(L, "never go here");
  return openssl_pushresult(L, ret);
}

/***
feed data to do cipher

@function update
@tparam string msg data
@treturn string result parture result
*/
static LUA_FUNCTION(openssl_evp_cipher_update)
{
  size_t inl;
  const char *in;
  int outl;
  char *out;
  CIPHER_MODE mode;
  int ret, type;

  EVP_CIPHER_CTX* c = CHECK_OBJECT(1, EVP_CIPHER_CTX, "openssl.evp_cipher_ctx");
  type = lua_type(L, 2);
  luaL_argcheck(L, type==LUA_TNUMBER || type==LUA_TSTRING, 2, "expect integer or string");

  in = luaL_checklstring(L, 2, &inl);
  outl = inl + EVP_MAX_BLOCK_LENGTH;
  out = OPENSSL_malloc(outl);

  lua_rawgetp(L, LUA_REGISTRYINDEX, c);
  mode = lua_tointeger(L, -1);
  lua_pop(L, 1);

  ret = 0;
  if (mode == DO_CIPHER)
    ret = EVP_CipherUpdate(c, (byte*)out, &outl, (const byte*)in, inl);
  else if (mode == DO_ENCRYPT)
    ret = EVP_EncryptUpdate(c, (byte*)out, &outl, (const byte*)in, inl);
  else if (mode == DO_DECRYPT)
    ret = EVP_DecryptUpdate(c, (byte*)out, &outl, (const byte*)in, inl);
  else
    luaL_error(L, "never go here");

  if (ret == 1)
    lua_pushlstring(L, out, outl);
  else
    ret = openssl_pushresult(L, ret);

  OPENSSL_free(out);

  return ret;
}

/***
get result of cipher

@function final
@treturn string result last result
*/
static LUA_FUNCTION(openssl_evp_cipher_final)
{
  EVP_CIPHER_CTX* c = CHECK_OBJECT(1, EVP_CIPHER_CTX, "openssl.evp_cipher_ctx");
  char out[EVP_MAX_BLOCK_LENGTH];
  int outl = sizeof(out);
  CIPHER_MODE mode;
  int ret = 0;

  lua_rawgetp(L, LUA_REGISTRYINDEX, c);
  mode = lua_tointeger(L, -1);

  if (mode == DO_CIPHER)
    ret = EVP_CipherFinal_ex(c, (byte*)out, &outl);
  else if (mode == DO_ENCRYPT)
    ret = EVP_EncryptFinal_ex(c, (byte*)out, &outl);
  else if (mode == DO_DECRYPT)
    ret = EVP_DecryptFinal_ex(c, (byte*)out, &outl);
  else
    luaL_error(L, "never go here");
  lua_pop(L, 1);

  if (ret == 1)
  {
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
static LUA_FUNCTION(openssl_cipher_ctx_info)
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

static LUA_FUNCTION(openssl_cipher_ctx_padding)
{
  int pad;
  EVP_CIPHER_CTX *ctx = CHECK_OBJECT(1, EVP_CIPHER_CTX, "openssl.evp_cipher_ctx");
  luaL_checkany(L, 2);

  pad = lua_toboolean(L, 2);
  EVP_CIPHER_CTX_set_padding(ctx, pad);
  return 0;
}

static LUA_FUNCTION(openssl_cipher_ctx_ctrl)
{
  int ret = 0;
  EVP_CIPHER_CTX *ctx = CHECK_OBJECT(1, EVP_CIPHER_CTX, "openssl.evp_cipher_ctx");
  int type = luaL_checkint(L, 2);
  int arg = 0;
  void *ptr = NULL;

  switch(type)
  {
  case EVP_CTRL_INIT:
    ret = EVP_CIPHER_CTX_ctrl(ctx, type, 0, NULL);
    ret = openssl_pushresult(L, ret);
    break;
  case EVP_CTRL_SET_KEY_LENGTH:
  case EVP_CTRL_SET_RC2_KEY_BITS:
  case EVP_CTRL_SET_RC5_ROUNDS:
  case EVP_CTRL_GCM_SET_IVLEN:  //EVP_CTRL_CCM_SET_IVLEN
    arg = luaL_checkint(L, 3);
    ret = EVP_CIPHER_CTX_ctrl(ctx, type, arg, NULL);
    ret = openssl_pushresult(L, ret);
    break;
  case EVP_CTRL_GCM_SET_TAG:    //EVP_CTRL_CCM_SET_TAG
  {
    size_t sz = 0;
    luaL_argcheck(L, lua_isnumber(L, 3) || lua_isstring(L, 3), 3, "need integer or string");

    ptr = (void*)luaL_checklstring(L, 3, &sz);
    ret = EVP_CIPHER_CTX_ctrl(ctx, type, sz, ptr);

    ret = openssl_pushresult(L, ret);
    break;
  }
  case EVP_CTRL_GET_RC2_KEY_BITS:
  case EVP_CTRL_GET_RC5_ROUNDS:
    ret = EVP_CIPHER_CTX_ctrl(ctx, type, 0, &arg);
    if(ret==1)
    {
      lua_pushinteger(L, arg);
      ret = 1;
    }else
      ret = openssl_pushresult(L, ret);
  case EVP_CTRL_GCM_GET_TAG:    //EVP_CTRL_CCM_GET_TAG
  {
    char buf[16];
    arg = luaL_checkint(L, 3);
    if (arg==4 || arg==6 || arg==10 || arg==12 || arg==14 || arg==16)
    {
      ret = EVP_CIPHER_CTX_ctrl(ctx, type, arg, buf);
      if(ret==1)
      {
        lua_pushlstring(L, buf, arg);
        ret = 1;
      }
      else
        ret = openssl_pushresult(L, ret);
    }
    else
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

static LUA_FUNCTION(openssl_cipher_ctx_free)
{
  EVP_CIPHER_CTX *ctx = CHECK_OBJECT(1, EVP_CIPHER_CTX, "openssl.evp_cipher_ctx");
  if(!ctx)
    return 0;
  lua_pushnil(L);
  lua_rawsetp(L, LUA_REGISTRYINDEX, ctx);
  EVP_CIPHER_CTX_free(ctx);
  FREE_OBJECT(1);
  return 0;
}

static luaL_Reg cipher_funs[] =
{
  {"info",        openssl_cipher_info},
  {"new",         openssl_cipher_new},
  {"encrypt_new", openssl_cipher_encrypt_new},
  {"decrypt_new", openssl_cipher_decrypt_new},

  {"BytesToKey",  openssl_evp_BytesToKey},

  {"encrypt",     openssl_evp_encrypt },
  {"decrypt",     openssl_evp_decrypt },
  {"cipher",      openssl_evp_cipher },

  {"__tostring",  auxiliar_tostring},

  {NULL, NULL}
};

static luaL_Reg cipher_ctx_funs[] =
{
  {"init",        openssl_evp_cipher_init},
  {"update",      openssl_evp_cipher_update},
  {"final",       openssl_evp_cipher_final},
  {"info",        openssl_cipher_ctx_info},
  {"close",       openssl_cipher_ctx_free},
  {"ctrl",        openssl_cipher_ctx_ctrl},
  {"padding",     openssl_cipher_ctx_padding},

  {"__gc",        openssl_cipher_ctx_free},
  {"__tostring",  auxiliar_tostring},

  {NULL, NULL}
};

static const luaL_Reg R[] =
{
  { "list",    openssl_cipher_list},
  { "get",     openssl_cipher_get},
  { "encrypt", openssl_evp_encrypt},
  { "decrypt", openssl_evp_decrypt},
  { "cipher",  openssl_evp_cipher},

  { "new",     openssl_cipher_new},
  { "encrypt_new", openssl_cipher_encrypt_new},
  { "decrypt_new", openssl_cipher_decrypt_new},

  {NULL,  NULL}
};

static LuaL_Enumeration evp_ctrls_code[] =
{
  {"EVP_CTRL_INIT",                           EVP_CTRL_INIT},
  {"EVP_CTRL_SET_KEY_LENGTH",                 EVP_CTRL_SET_KEY_LENGTH},
  {"EVP_CTRL_GET_RC2_KEY_BITS",               EVP_CTRL_GET_RC2_KEY_BITS},
  {"EVP_CTRL_SET_RC2_KEY_BITS",               EVP_CTRL_SET_RC2_KEY_BITS},
  {"EVP_CTRL_GET_RC5_ROUNDS",                 EVP_CTRL_GET_RC5_ROUNDS},
  {"EVP_CTRL_SET_RC5_ROUNDS",                 EVP_CTRL_SET_RC5_ROUNDS},
  {"EVP_CTRL_RAND_KEY",                       EVP_CTRL_RAND_KEY},
  {"EVP_CTRL_PBE_PRF_NID",                    EVP_CTRL_PBE_PRF_NID},
  {"EVP_CTRL_COPY",                           EVP_CTRL_COPY},
  {"EVP_CTRL_GCM_SET_IVLEN",                  EVP_CTRL_GCM_SET_IVLEN},
  {"EVP_CTRL_GCM_GET_TAG",                    EVP_CTRL_GCM_GET_TAG},
  {"EVP_CTRL_GCM_SET_TAG",                    EVP_CTRL_GCM_SET_TAG},
  {"EVP_CTRL_GCM_SET_IV_FIXED",               EVP_CTRL_GCM_SET_IV_FIXED},
  {"EVP_CTRL_GCM_IV_GEN",                     EVP_CTRL_GCM_IV_GEN},
  {"EVP_CTRL_CCM_SET_IVLEN",                  EVP_CTRL_GCM_SET_IVLEN},
  {"EVP_CTRL_CCM_GET_TAG",                    EVP_CTRL_CCM_GET_TAG},
  {"EVP_CTRL_CCM_SET_TAG",                    EVP_CTRL_CCM_SET_TAG},
  {"EVP_CTRL_CCM_SET_L",                      EVP_CTRL_CCM_SET_L},
  {"EVP_CTRL_CCM_SET_MSGLEN",                 EVP_CTRL_CCM_SET_MSGLEN},
  {"EVP_CTRL_AEAD_TLS1_AAD",                  EVP_CTRL_AEAD_TLS1_AAD},
  {"EVP_CTRL_AEAD_SET_MAC_KEY",               EVP_CTRL_AEAD_SET_MAC_KEY},
  {"EVP_CTRL_GCM_SET_IV_INV",                 EVP_CTRL_GCM_SET_IV_INV},

#if OPENSSL_VERSION_NUMBER >= 0x10002000L && !defined(LIBRESSL_VERSION_NUMBER)
  {"EVP_CTRL_TLS1_1_MULTIBLOCK_AAD",          EVP_CTRL_TLS1_1_MULTIBLOCK_AAD},
  {"EVP_CTRL_TLS1_1_MULTIBLOCK_ENCRYPT",      EVP_CTRL_TLS1_1_MULTIBLOCK_ENCRYPT},
  {"EVP_CTRL_TLS1_1_MULTIBLOCK_DECRYPT",      EVP_CTRL_TLS1_1_MULTIBLOCK_DECRYPT},
  {"EVP_CTRL_TLS1_1_MULTIBLOCK_MAX_BUFSIZE",  EVP_CTRL_TLS1_1_MULTIBLOCK_MAX_BUFSIZE},
#endif

  {NULL,                    -1}
};

int luaopen_cipher(lua_State *L)
{
  auxiliar_newclass(L, "openssl.evp_cipher",      cipher_funs);
  auxiliar_newclass(L, "openssl.evp_cipher_ctx",  cipher_ctx_funs);

  lua_newtable(L);
  luaL_setfuncs(L, R, 0);
  auxiliar_enumerate(L, -1, evp_ctrls_code);

  return 1;
}
