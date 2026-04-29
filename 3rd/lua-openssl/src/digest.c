/***
digest module perform digest operations base on OpenSSL EVP API.

@module digest
@usage
  digest = require('openssl').digest
*/
#include "openssl.h"
#include "private.h"
#if defined(LIBRESSL_VERSION_NUMBER)
#include <openssl/engine.h>
#endif

/***
EVP_MD digest algorithm object

This object represents an OpenSSL EVP_MD digest algorithm.
It can be obtained using digest.get() or digest.fetch().

@type openssl.evp_digest
*/

/***
EVP_MD_CTX digest context object

This object represents an OpenSSL EVP_MD_CTX digest context.
It is created using digest.new() and used for hash operations.

@type openssl.evp_digest_ctx
*/

/***
list all supported digest algorithms

@function list
@tparam[opt=true] boolean alias include alias names for digest algorithms
@treturn table table of digest algorithm names
-- @see OpenSSL function: EVP_MD_do_all_sorted
@usage
  -- Get all digest algorithms with aliases
  local digests = digest.list()
  for name, _ in pairs(digests) do
    print(name)
  end

  -- Get only primary names (no aliases)
  local primary_digests = digest.list(false)
*/
static int openssl_digest_list(lua_State *L)
{
  int aliases = lua_isnone(L, 1) ? 1 : lua_toboolean(L, 1);
  lua_newtable(L);
  OBJ_NAME_do_all_sorted(
    OBJ_NAME_TYPE_MD_METH, aliases ? openssl_add_method_or_alias : openssl_add_method, L);
  return 1;
};

/***
get EVP_MD digest algorithm object

This function retrieves a digest algorithm object by name, NID, or ASN1 object.
The returned object can be used with digest.new() to create a digest context.

@function get
@tparam string|integer|openssl.asn1_object alg algorithm name, NID, or ASN1 object
@treturn[1] openssl.evp_digest digest algorithm object
@treturn[2] nil if algorithm not found
@treturn[2] string error message
@see digest.new
@see digest.fetch
@usage
  local digest = require('openssl').digest

  -- Get digest by name
  local sha256 = digest.get('SHA256')

  -- Get digest by NID
  local sha256_nid = digest.get(672)  -- NID for SHA256

  -- Use with digest.new()
  local ctx = digest.new(sha256)
  ctx:update('data')
  local result = ctx:final()
*/
static int openssl_digest_get(lua_State *L)
{
  const EVP_MD *md = get_digest(L, 1, NULL);

  PUSH_OBJECT((void *)md, "openssl.evp_digest");
  return 1;
}

#if (OPENSSL_VERSION_NUMBER >= 0x30000000L) && !defined(LIBRESSL_VERSION_NUMBER)
/***
fetch evp_digest object with provider support (OpenSSL 3.0+)

@function fetch
@tparam string alg algorithm name (e.g., 'SHA256', 'SHA512')
@tparam[opt] table options optional table with 'provider' and 'properties' fields
@treturn openssl.evp_digest digest object mapping EVP_MD in openssl or nil on failure
@treturn string error message if failed

@usage
  -- Fetch with default provider
  local sha256 = digest.fetch('SHA256')

  -- Fetch from specific provider
  local fips_sha256 = digest.fetch('SHA256', {provider = 'fips', properties = 'fips=yes'})

@see evp_digest
*/
static int openssl_digest_fetch(lua_State *L)
{
  const char *algorithm = luaL_checkstring(L, 1);
  const char *provider = NULL;
  const char *properties = NULL;
  OSSL_LIB_CTX *libctx = NULL;  /* NULL means default context */
  EVP_MD *md = NULL;

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
  md = EVP_MD_fetch(libctx, algorithm, properties);

  if (md != NULL) {
    PUSH_OBJECT(md, "openssl.evp_digest");
    /* Mark this as a fetched object that needs to be freed */
    lua_pushboolean(L, 1);
    lua_rawsetp(L, LUA_REGISTRYINDEX, md);
    return 1;
  }

  return openssl_pushresult(L, 0);
}

/***
get provider name for a digest (OpenSSL 3.0+)

@function get_provider_name
@treturn[1] string provider name
@treturn[2] nil if digest has no provider or provider has no name
*/
static int openssl_digest_get_provider_name(lua_State *L)
{
  EVP_MD *md = CHECK_OBJECT(1, EVP_MD, "openssl.evp_digest");
  const OSSL_PROVIDER *prov = EVP_MD_get0_provider(md);

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
free a fetched evp_digest object (OpenSSL 3.0+)

@function __gc
@treturn nil always returns nil
*/
static int openssl_digest_gc(lua_State *L)
{
  EVP_MD *md = CHECK_OBJECT(1, EVP_MD, "openssl.evp_digest");

  /* Check if this is a fetched object that needs to be freed */
  lua_rawgetp(L, LUA_REGISTRYINDEX, md);
  if (lua_toboolean(L, -1)) {
    /* This is a fetched object, free it */
    EVP_MD_free(md);
    /* Remove the marker */
    lua_pushnil(L);
    lua_rawsetp(L, LUA_REGISTRYINDEX, md);
  }
  lua_pop(L, 1);

  return 0;
}
#endif

/***
get evp_digest_ctx object

@function new
@tparam string|integer|asn1_object alg name, nid or object identity
@treturn evp_digest_ctx digest object mapping EVP_MD_CTX in openssl

@see evp_digest_ctx
*/
static int openssl_digest_new(lua_State *L)
{
  const EVP_MD *md = get_digest(L, 1, NULL);
  int           ret = 0;
  ENGINE       *e = lua_isnoneornil(L, 2) ? NULL : CHECK_OBJECT(2, ENGINE, "openssl.engine");
  EVP_MD_CTX   *ctx = EVP_MD_CTX_new();
  if (ctx) {
    lua_pushlightuserdata(L, e);
    lua_rawsetp(L, LUA_REGISTRYINDEX, ctx);
    ret = EVP_DigestInit_ex(ctx, md, e);
    if (ret == 1) {
      PUSH_OBJECT(ctx, "openssl.evp_digest_ctx");
    } else {
      EVP_MD_CTX_free(ctx);
      ret = openssl_pushresult(L, ret);
    }
  }
  return ret;
}

/***
quick method to generate digest result

@function digest
@tparam string|integer|asn1_object alg name, nid or object identity
@tparam string msg to compute digest
@tparam[opt] boolean raw binary result return if set true, or hex encoded string default
@treturn string digest result value
*/
static int openssl_digest(lua_State *L)
{
  const EVP_MD *md;
  ENGINE       *eng;
  size_t        inl;
  const char   *in;
  unsigned char buf[EVP_MAX_MD_SIZE];
  unsigned int  blen = sizeof(buf);
  int           raw, ret;

  md = get_digest(L, 1, NULL);
  in = luaL_checklstring(L, 2, &inl);
  raw = (lua_isnone(L, 3)) ? 0 : lua_toboolean(L, 3);
  eng = (lua_isnoneornil(L, 4) ? 0 : CHECK_OBJECT(4, ENGINE, "openssl.engine"));

  ret = EVP_Digest(in, inl, buf, &blen, md, eng);
  if (ret == 1) {
    if (raw)
      lua_pushlstring(L, (const char *)buf, blen);
    else {
      char hex[2 * EVP_MAX_MD_SIZE + 1];
      to_hex((const char *)buf, blen, hex);
      lua_pushstring(L, hex);
    }
  }
  return ret == 1 ? 1 : openssl_pushresult(L, ret);
};

/***
create digest object for sign

@function signInit
@tparam string|integer|asn1_object alg name, nid or object identity
@tparam[opt=nil] openssl.engine object
@treturn evp_digest_ctx
*/
static int openssl_signInit(lua_State *L)
{
  const EVP_MD *md = lua_isnil(L, 1) ? NULL : get_digest(L, 1, NULL);
  EVP_PKEY     *pkey = CHECK_OBJECT(2, EVP_PKEY, "openssl.evp_pkey");
  ENGINE       *e = lua_gettop(L) > 2 ? CHECK_OBJECT(3, ENGINE, "openssl.engine") : NULL;
  EVP_MD_CTX   *ctx = EVP_MD_CTX_new();
  int           ret = 0;

  if (ctx) {
    ret = EVP_DigestSignInit(ctx, NULL, md, e, pkey);
    if (ret == 1) {
      PUSH_OBJECT(ctx, "openssl.evp_digest_ctx");
    } else {
      EVP_MD_CTX_free(ctx);
      ret = openssl_pushresult(L, ret);
    }
  }
  return ret;
}

/***
create digest object for verify

@function verifyInit
@tparam string|integer|asn1_object alg name, nid or object identity
@tparam[opt=nil] openssl.engine object
@treturn evp_digest_ctx
*/
static int openssl_verifyInit(lua_State *L)
{
  const EVP_MD *md = lua_isnil(L, 1) ? NULL : get_digest(L, 1, NULL);
  EVP_PKEY     *pkey = CHECK_OBJECT(2, EVP_PKEY, "openssl.evp_pkey");
  ENGINE       *e = lua_gettop(L) > 2 ? CHECK_OBJECT(3, ENGINE, "openssl.engine") : NULL;
  EVP_PKEY_CTX *pctx = 0;
  EVP_MD_CTX   *ctx = EVP_MD_CTX_new();
  int           ret = 0;

  if (ctx) {
    ret = EVP_DigestVerifyInit(ctx, &pctx, md, e, pkey);
    if (ret) {
      PUSH_OBJECT(ctx, "openssl.evp_digest_ctx");
    } else {
      EVP_MD_CTX_free(ctx);
      ret = openssl_pushresult(L, ret);
    }
  }
  return ret;
}

/***
openssl.evp_digest object
@type evp_digest
*/

/***
compute msg digest result

@function digest
@tparam string msg data to digest
@tparam[opt] openssl.engine eng
@treturn string result a binary hash value for msg
*/
static int openssl_digest_digest(lua_State *L)
{
  size_t      inl;
  EVP_MD     *md = CHECK_OBJECT(1, EVP_MD, "openssl.evp_digest");
  const char *in = luaL_checklstring(L, 2, &inl);
  ENGINE     *e = lua_isnoneornil(L, 3) ? NULL : CHECK_OBJECT(3, ENGINE, "openssl.engine");

  char         buf[EVP_MAX_MD_SIZE];
  unsigned int blen = EVP_MAX_MD_SIZE;

  int ret = EVP_Digest(in, inl, (unsigned char *)buf, &blen, md, e);
  if (ret == 1) {
    lua_pushlstring(L, buf, blen);
  } else
    ret = openssl_pushresult(L, ret);

  return ret;
}

/***
get infomation of evp_digest object

@function info
@treturn table info keys include nid,name size,block_size,pkey_type,flags
*/
static int openssl_digest_info(lua_State *L)
{
  EVP_MD *md = CHECK_OBJECT(1, EVP_MD, "openssl.evp_digest");
  lua_newtable(L);
  AUXILIAR_SET(L, -1, "nid", EVP_MD_nid(md), integer);
  AUXILIAR_SET(L, -1, "name", EVP_MD_name(md), string);
  AUXILIAR_SET(L, -1, "size", EVP_MD_size(md), integer);
  AUXILIAR_SET(L, -1, "block_size", EVP_MD_block_size(md), integer);

  AUXILIAR_SET(L, -1, "pkey_type", EVP_MD_pkey_type(md), integer);
  AUXILIAR_SET(L, -1, "flags", EVP_MD_type(md), integer);
  return 1;
}

/***
initialize digest context with message digest
@function init
@tparam openssl.evp_digest md message digest algorithm
@tparam[opt] openssl.engine eng
@treturn evp_digest_ctx ctx
@see evp_digest_ctx
*/
static int openssl_evp_digest_init(lua_State *L)
{
  EVP_MD *md = CHECK_OBJECT(1, EVP_MD, "openssl.evp_digest");
  ENGINE *e = lua_isnoneornil(L, 2) ? NULL : CHECK_OBJECT(2, ENGINE, "openssl.engine");
  int     ret = 0;

  EVP_MD_CTX *ctx = EVP_MD_CTX_new();
  if (ctx) {
    ret = EVP_DigestInit_ex(ctx, md, e);
    if (ret == 1) {
      PUSH_OBJECT(ctx, "openssl.evp_digest_ctx");
    } else {
      EVP_MD_CTX_free(ctx);
      ret = openssl_pushresult(L, ret);
    }
  }
  return ret;
}

/***
create digest object for sign

@function signInit
@tparam[opt=nil] openssl.engine object
@treturn evp_digest_ctx
*/

/***
create digest object for verify

@function verifyInit
@tparam[opt=nil] openssl.engine object
@treturn evp_digest_ctx
*/

/***
openssl.evp_digest_ctx object
@type evp_digest_ctx
*/

/***
get infomation of evp_digest_ctx object

@function info
@treturn table info keys include size,block_size,digest
*/
static int openssl_digest_ctx_info(lua_State *L)
{
  EVP_MD_CTX *ctx = CHECK_OBJECT(1, EVP_MD_CTX, "openssl.evp_digest_ctx");
#if OPENSSL_VERSION_NUMBER < 0x30000000
  const EVP_MD *md = EVP_MD_CTX_md(ctx);
#else
  const EVP_MD *md = EVP_MD_CTX_get0_md(ctx);
#endif

  lua_newtable(L);
  AUXILIAR_SET(L, -1, "block_size", EVP_MD_CTX_block_size(ctx), integer);
  AUXILIAR_SET(L, -1, "size", EVP_MD_CTX_size(ctx), integer);
  AUXILIAR_SET(L, -1, "type", EVP_MD_CTX_type(ctx), integer);

  AUXILIAR_SETOBJECT(L, md, "openssl.evp_digest", -1, "digest");
  return 1;
}

/***
feed data to do digest

@function update
@tparam string msg data
@treturn boolean result true for success
*/
static int openssl_evp_digest_update(lua_State *L)
{
  size_t      inl;
  EVP_MD_CTX *c = CHECK_OBJECT(1, EVP_MD_CTX, "openssl.evp_digest_ctx");
  const char *in = luaL_checklstring(L, 2, &inl);

  int ret = EVP_DigestUpdate(c, in, inl);

  lua_pushboolean(L, ret);
  return 1;
}

/***
get result of digest

@function final
@tparam[opt] string last last part of data
@tparam[opt] boolean raw binary or hexadecimal result, default false for hexadecimal result
@treturn string val hash result
*/
static int openssl_evp_digest_final(lua_State *L)
{
  EVP_MD_CTX *c = CHECK_OBJECT(1, EVP_MD_CTX, "openssl.evp_digest_ctx");

  byte         out[EVP_MAX_MD_SIZE];
  unsigned int outl = sizeof(out);
  int          ret = 0, raw = 0;

  if (lua_isstring(L, 2)) {
    size_t      inl;
    const char *in = luaL_checklstring(L, 2, &inl);
    ret = EVP_DigestUpdate(c, in, inl);
    if (ret != 1) {
      ret = openssl_pushresult(L, ret);
      goto err;
    }

    raw = (lua_isnone(L, 3)) ? 0 : lua_toboolean(L, 3);
  } else if (lua_gettop(L) >= 3)
    raw = lua_toboolean(L, 3);
  else
    raw = (lua_isnone(L, 2)) ? 0 : lua_toboolean(L, 2);

  ret = EVP_DigestFinal_ex(c, (byte *)out, &outl);
  if (ret == 1) {
    if (raw) {
      lua_pushlstring(L, (const char *)out, outl);
    } else {
      char hex[2 * EVP_MAX_MD_SIZE + 1];
      to_hex((const char *)out, outl, hex);
      lua_pushstring(L, hex);
    }
  } else
    ret = openssl_pushresult(L, ret);

err:
  return ret;
}

static int openssl_digest_ctx_free(lua_State *L)
{
  EVP_MD_CTX *ctx = CHECK_OBJECT(1, EVP_MD_CTX, "openssl.evp_digest_ctx");
  lua_pushnil(L);
  lua_rawsetp(L, LUA_REGISTRYINDEX, ctx);
  EVP_MD_CTX_free(ctx);
  return 0;
}

/***
reset evp_diget_ctx to reuse

@function reset
@treturn boolean true on success, false on failure
*/
static int openssl_digest_ctx_reset(lua_State *L)
{
  EVP_MD_CTX *ctx = CHECK_OBJECT(1, EVP_MD_CTX, "openssl.evp_digest_ctx");
#if OPENSSL_VERSION_NUMBER < 0x30000000
  const EVP_MD *md = EVP_MD_CTX_md(ctx);
#else
  const EVP_MD *md = EVP_MD_CTX_get0_md(ctx);
#endif

  ENGINE *e = NULL;
  int     ret;

  lua_rawgetp(L, LUA_REGISTRYINDEX, ctx);
  e = (ENGINE *)lua_topointer(L, -1);
  ret = EVP_MD_CTX_reset(ctx);
  if (ret) {
    EVP_DigestInit_ex(ctx, md, e);
  }
  return openssl_pushresult(L, ret);
}

/***
retrieve md data

@function data
@tparam[opt] string md_data data to set (optional)
@treturn string|boolean if no parameter given, returns current md_data; if parameter given, returns boolean success status
*/
static int openssl_digest_ctx_data(lua_State *L)
{
  EVP_MD_CTX *ctx = CHECK_OBJECT(1, EVP_MD_CTX, "openssl.evp_digest_ctx");

#if OPENSSL_VERSION_NUMBER < 0x10100000L                                                           \
  || (defined(LIBRESSL_VERSION_NUMBER) && LIBRESSL_VERSION_NUMBER < 0x3050000fL)

  if (lua_isnone(L, 2)) {
    lua_pushlstring(L, ctx->md_data, ctx->digest->ctx_size);
  } else {
    size_t      l;
    const char *d = luaL_checklstring(L, 2, &l);
    luaL_argcheck(L, l == (size_t)ctx->digest->ctx_size, 2, "wrong data");
    memcpy(ctx->md_data, d, l);
    lua_pushboolean(L, 1);
  }
#else

#if defined(LIBRESSL_VERSION_NUMBER) || OPENSSL_VERSION_NUMBER >= 0x30000000L
  /* without EVP_MD_meth_get_app_datasize
   * LibreSSL does not support this function
   * OpenSSL 3.0+ deprecated EVP_MD_meth_get_app_datasize in favor of provider-based architecture
   */
  (void)ctx;
  return 0;
#else

  const EVP_MD *md = EVP_MD_CTX_md(ctx);
  size_t ctx_size = (size_t)EVP_MD_meth_get_app_datasize(md);
  if (ctx_size == 0) return 0;

  if (lua_isnone(L, 2)) {
    lua_pushlstring(L, EVP_MD_CTX_md_data(ctx), ctx_size);
  } else {
    const char *d = luaL_checklstring(L, 2, &ctx_size);
    luaL_argcheck(L, ctx_size == (size_t)EVP_MD_meth_get_app_datasize(md), 2, "wrong data");
    memcpy(EVP_MD_CTX_md_data(ctx), d, ctx_size);
    lua_pushboolean(L, 1);
  }
#endif

#endif
  return 1;
}

/***
update digest context for signing operation
@function signUpdate
@tparam evp_digest_ctx ctx digest context
@tparam string data data to sign
@treturn boolean result
*/
static int openssl_signUpdate(lua_State *L)
{
  size_t      l;
  int         ret;
  EVP_MD_CTX *ctx = CHECK_OBJECT(1, EVP_MD_CTX, "openssl.evp_digest_ctx");
  const char *data = luaL_checklstring(L, 2, &l);
  ret = EVP_DigestSignUpdate(ctx, data, l);
  return openssl_pushresult(L, ret);
}

/***
feed data for verify with signature

@function verifyUpdate
@tparam string data to be verified
@treturn boolean result
*/
static int openssl_verifyUpdate(lua_State *L)
{
  size_t      l;
  int         ret;
  EVP_MD_CTX *ctx = CHECK_OBJECT(1, EVP_MD_CTX, "openssl.evp_digest_ctx");
  const char *data = luaL_checklstring(L, 2, &l);
  ret = EVP_DigestVerifyUpdate(ctx, data, l);
  return openssl_pushresult(L, ret);
}

/***
get result of sign

@function signFinal
@tparam openssl.evp_pkey private key to do sign
@treturn string singed result
*/
static int openssl_signFinal(lua_State *L)
{
  EVP_MD_CTX *ctx = CHECK_OBJECT(1, EVP_MD_CTX, "openssl.evp_digest_ctx");
  size_t      siglen = 0;
  int         ret = EVP_DigestSignFinal(ctx, NULL, &siglen);
  if (ret == 1) {
    unsigned char *sigbuf = OPENSSL_malloc(siglen);
    ret = EVP_DigestSignFinal(ctx, sigbuf, &siglen);
    if (ret == 1) {
      lua_pushlstring(L, (char *)sigbuf, siglen);
    }
    OPENSSL_free(sigbuf);
    EVP_MD_CTX_reset(ctx);
  }
  return ret == 1 ? 1 : openssl_pushresult(L, ret);
}

/***
get verify result

@function verifyFinal
@tparam string signature
@treturn boolean result, true for verify pass
*/
static int openssl_verifyFinal(lua_State *L)
{
  EVP_MD_CTX *ctx = CHECK_OBJECT(1, EVP_MD_CTX, "openssl.evp_digest_ctx");
  size_t      signature_len;
  const char *signature = luaL_checklstring(L, 2, &signature_len);
  int         ret = EVP_DigestVerifyFinal(ctx, (unsigned char *)signature, signature_len);

  EVP_MD_CTX_reset(ctx);
  return openssl_pushresult(L, ret);
}

static luaL_Reg digest_funs[] = {
  { "new",        openssl_evp_digest_init },
  { "info",       openssl_digest_info     },
  { "digest",     openssl_digest_digest   },

  { "signInit",   openssl_signInit        },
  { "verifyInit", openssl_verifyInit      },

#if (OPENSSL_VERSION_NUMBER >= 0x30000000L) && !defined(LIBRESSL_VERSION_NUMBER)
  { "get_provider_name", openssl_digest_get_provider_name },
  { "__gc",       openssl_digest_gc       },
#endif

  { "__tostring", auxiliar_tostring       },

  { NULL,         NULL                    }
};

#if OPENSSL_VERSION_NUMBER >= 0x10101000L && !defined(LIBRESSL_VERSION_NUMBER)                     \
  || LIBRESSL_VERSION_NUMBER > 0x3050000fL
/***
get result of oneshot sign

@function sign
@tparam evp_digest_ctx ctx
@tparam string data to sign
@treturn[1] string singed result
@treturn[2] nil followd by error message
*/
static int openssl_oneshot_sign(lua_State *L)
{
  EVP_MD_CTX    *ctx = CHECK_OBJECT(1, EVP_MD_CTX, "openssl.evp_digest_ctx");
  size_t         tbslen;
  const uint8_t *tbs = (const uint8_t *)luaL_checklstring(L, 2, &tbslen);
  size_t         siglen = 0;

  int ret = EVP_DigestSign(ctx, NULL, &siglen, tbs, tbslen);
  if (ret == 1) {
    unsigned char *sigbuf = OPENSSL_malloc(siglen);
    ret = EVP_DigestSign(ctx, sigbuf, &siglen, tbs, tbslen);
    if (ret == 1) {
      lua_pushlstring(L, (const char *)sigbuf, siglen);
    }
    OPENSSL_free(sigbuf);
    EVP_MD_CTX_reset(ctx);
  }
  return ret == 1 ? 1 : openssl_pushresult(L, ret);
}

/***
get result of oneshot verify

@function verify
@tparam evp_digest_ctx ctx
@tparam string signature to verify
@tparam data to verify
@treturn[1] string singed result
@treturn[2] nil followd by error message
@tparam string signature
@treturn boolean result, true for verify pass
*/
static int openssl_oneshot_verify(lua_State *L)
{
  EVP_MD_CTX    *ctx = CHECK_OBJECT(1, EVP_MD_CTX, "openssl.evp_digest_ctx");
  size_t         siglen;
  const uint8_t *sig = (const uint8_t *)luaL_checklstring(L, 2, &siglen);
  size_t         tbslen;
  const uint8_t *tbs = (const uint8_t *)luaL_checklstring(L, 3, &tbslen);

  int ret = EVP_DigestVerify(ctx, sig, siglen, tbs, tbslen);
  EVP_MD_CTX_reset(ctx);

  if (ret < 0) return openssl_pushresult(L, ret);
  lua_pushboolean(L, ret);
  return ret;
}
#endif

static luaL_Reg digest_ctx_funs[] = {
  { "update",       openssl_evp_digest_update },
  { "final",        openssl_evp_digest_final  },
  { "info",         openssl_digest_ctx_info   },
  { "reset",        openssl_digest_ctx_reset  },
  { "close",        openssl_digest_ctx_free   },
  { "data",         openssl_digest_ctx_data   },

  { "signUpdate",   openssl_signUpdate        },
  { "signFinal",    openssl_signFinal         },
  { "verifyUpdate", openssl_verifyUpdate      },
  { "verifyFinal",  openssl_verifyFinal       },

#if OPENSSL_VERSION_NUMBER >= 0x10101000L && !defined(LIBRESSL_VERSION_NUMBER)                     \
  || LIBRESSL_VERSION_NUMBER > 0x3050000fL
  { "sign",         openssl_oneshot_sign      },
  { "verify",       openssl_oneshot_verify    },
#endif

  { "__tostring",   auxiliar_tostring         },
  { "__gc",         openssl_digest_ctx_free   },
  { NULL,           NULL                      }
};

static const luaL_Reg R[] = {
  { "list",       openssl_digest_list },
  { "get",        openssl_digest_get  },
  { "new",        openssl_digest_new  },
  { "digest",     openssl_digest      },

  { "signInit",   openssl_signInit    },
  { "verifyInit", openssl_verifyInit  },

#if (OPENSSL_VERSION_NUMBER >= 0x30000000L) && !defined(LIBRESSL_VERSION_NUMBER)
  { "fetch",      openssl_digest_fetch },
#endif

  { NULL,         NULL                }
};

/***
EVP_MD digest algorithm object

This object represents an OpenSSL EVP_MD digest algorithm.
It can be obtained using digest.get() or digest.fetch().

@type openssl.evp_digest
*/

/***
EVP_MD_CTX digest context object

This object represents an OpenSSL EVP_MD_CTX digest context.
It is created using digest.new() and used for hash operations.

@type openssl.evp_digest_ctx
*/

int
luaopen_digest(lua_State *L)
{
  auxiliar_newclass(L, "openssl.evp_digest", digest_funs);
  auxiliar_newclass(L, "openssl.evp_digest_ctx", digest_ctx_funs);

  lua_newtable(L);
  luaL_setfuncs(L, R, 0);

  return 1;
}
