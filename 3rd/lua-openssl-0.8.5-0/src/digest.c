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
list all support digest algs

@function list
@tparam[opt] boolean alias include alias names for digest alg, default true
@treturn[table] all methods
*/
static LUA_FUNCTION(openssl_digest_list)
{
  int aliases = lua_isnone(L, 1) ? 1 : lua_toboolean(L, 1);
  lua_newtable(L);
  OBJ_NAME_do_all_sorted(OBJ_NAME_TYPE_MD_METH, aliases ? openssl_add_method_or_alias : openssl_add_method, L);
  return 1;
};

/***
get evp_digest object

@function get
@tparam string|integer|asn1_object alg name, nid or object identity
@treturn evp_digest digest object mapping EVP_MD in openssl

@see evp_digest
*/
static LUA_FUNCTION(openssl_digest_get)
{
  const EVP_MD* md = get_digest(L, 1, NULL);

  PUSH_OBJECT((void*)md, "openssl.evp_digest");
  return 1;
}

/***
get evp_digest_ctx object

@function new
@tparam string|integer|asn1_object alg name, nid or object identity
@treturn evp_digest_ctx digest object mapping EVP_MD_CTX in openssl

@see evp_digest_ctx
*/
static LUA_FUNCTION(openssl_digest_new)
{
  const EVP_MD* md = get_digest(L, 1, NULL);
  int ret = 0;
  ENGINE* e = lua_isnoneornil(L, 2) ? NULL : CHECK_OBJECT(2, ENGINE, "openssl.engine");
  EVP_MD_CTX* ctx = EVP_MD_CTX_create();
  if (ctx)
  {
    EVP_MD_CTX_init(ctx);
    lua_pushlightuserdata(L, e);
    lua_rawsetp(L, LUA_REGISTRYINDEX, ctx);
    ret = EVP_DigestInit_ex(ctx, md, e);
    if (ret == 1)
    {
      PUSH_OBJECT(ctx, "openssl.evp_digest_ctx");
    }
    else
    {
      EVP_MD_CTX_destroy(ctx);
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
static LUA_FUNCTION(openssl_digest)
{
  const EVP_MD *md;
  ENGINE *eng;
  size_t inl;
  const char* in;
  unsigned char buf[EVP_MAX_MD_SIZE];
  unsigned int  blen = sizeof(buf);
  int raw, ret;

  md = get_digest(L, 1, NULL);
  in = luaL_checklstring(L, 2, &inl);
  raw = (lua_isnone(L, 3)) ? 0 : lua_toboolean(L, 3);
  eng = (lua_isnoneornil(L, 4) ? 0 : CHECK_OBJECT(4, ENGINE, "openssl.engine"));

  ret = EVP_Digest(in, inl, buf, &blen, md, eng);
  if (ret == 1)
  {
    if (raw)
      lua_pushlstring(L, (const char*)buf, blen);
    else
    {
      char hex[2 * EVP_MAX_MD_SIZE + 1];
      to_hex((const char*)buf, blen, hex);
      lua_pushstring(L, hex);
    }
  }
  return ret == 1 ? 1 : openssl_pushresult(L, ret);
};

/***
create digest object for sign

@function signInit
@tparam string|integer|asn1_object alg name, nid or object identity
@tparam[opt=nil] engine object
@treturn evp_digest_ctx
*/
static LUA_FUNCTION(openssl_signInit)
{
  const EVP_MD *md = lua_isnil(L, 1) ? NULL: get_digest(L, 1, NULL);
  EVP_PKEY* pkey = CHECK_OBJECT(2, EVP_PKEY, "openssl.evp_pkey");
  ENGINE*     e = lua_gettop(L) > 2 ? CHECK_OBJECT(3, ENGINE, "openssl.engine") : NULL;
  EVP_MD_CTX *ctx = EVP_MD_CTX_create();
  int ret = 0;

  if (ctx)
  {
    EVP_MD_CTX_init(ctx);
    ret = EVP_DigestSignInit(ctx, NULL, md, e, pkey);
    if (ret==1)
    {
      PUSH_OBJECT(ctx, "openssl.evp_digest_ctx");
    }
    else
      ret = openssl_pushresult(L, ret);
  }
  return ret;
}

/***
create digest object for verify

@function verifyInit
@tparam string|integer|asn1_object alg name, nid or object identity
@tparam[opt=nil] engine object
@treturn evp_digest_ctx
*/
static LUA_FUNCTION(openssl_verifyInit)
{
  const EVP_MD *md = lua_isnil(L, 1) ? NULL: get_digest(L, 1, NULL);
  EVP_PKEY* pkey = CHECK_OBJECT(2, EVP_PKEY, "openssl.evp_pkey");
  ENGINE*     e = lua_gettop(L) > 2 ? CHECK_OBJECT(3, ENGINE, "openssl.engine") : NULL;
  EVP_PKEY_CTX *pctx = 0;
  EVP_MD_CTX *ctx = EVP_MD_CTX_create();
  int ret = 0;

  if (ctx)
  {
    EVP_MD_CTX_init(ctx);
    ret = EVP_DigestVerifyInit(ctx, &pctx, md, e, pkey);
    if (ret)
    {
      PUSH_OBJECT(ctx, "openssl.evp_digest_ctx");
    }
    else
      ret = openssl_pushresult(L, ret);
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
@tparam[opt] engine, eng
@treturn string result a binary hash value for msg
*/
static LUA_FUNCTION(openssl_digest_digest)
{
  size_t inl;
  EVP_MD *md = CHECK_OBJECT(1, EVP_MD, "openssl.evp_digest");
  const char* in = luaL_checklstring(L, 2, &inl);
  ENGINE*     e = lua_isnoneornil(L, 3) ? NULL : CHECK_OBJECT(3, ENGINE, "openssl.engine");

  char buf[EVP_MAX_MD_SIZE];
  unsigned int  blen = EVP_MAX_MD_SIZE;

  int ret = EVP_Digest(in, inl, (unsigned char*)buf, &blen, md, e);
  if (ret == 1)
  {
    lua_pushlstring(L, buf, blen);
  }
  else
    ret = openssl_pushresult(L, ret);

  return ret;
}

/***
get infomation of evp_digest object

@function info
@treturn table info keys include nid,name size,block_size,pkey_type,flags
*/
static LUA_FUNCTION(openssl_digest_info)
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
create new evp_digest_ctx

@function new
@tparam[opt] engine, eng
@treturn evp_digest_ctx ctx
@see evp_digest_ctx
*/
static LUA_FUNCTION(openssl_evp_digest_init)
{
  EVP_MD* md = CHECK_OBJECT(1, EVP_MD, "openssl.evp_digest");
  ENGINE*     e = lua_isnoneornil(L, 2) ? NULL : CHECK_OBJECT(2, ENGINE, "openssl.engine");
  int ret = 0;

  EVP_MD_CTX* ctx = EVP_MD_CTX_create();
  if (ctx)
  {
    EVP_MD_CTX_init(ctx);
    ret = EVP_DigestInit_ex(ctx, md, e);
    if (ret == 1)
    {
      PUSH_OBJECT(ctx, "openssl.evp_digest_ctx");
    }
    else
    {
      EVP_MD_CTX_destroy(ctx);
      ret = openssl_pushresult(L, ret);
    }
  }
  return ret;
}

/***
create digest object for sign

@function signInit
@tparam[opt=nil] engine object
@treturn evp_digest_ctx
*/

/***
create digest object for verify

@function verifyInit
@tparam[opt=nil] engine object
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
static LUA_FUNCTION(openssl_digest_ctx_info)
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
static LUA_FUNCTION(openssl_evp_digest_update)
{
  size_t inl;
  EVP_MD_CTX* c = CHECK_OBJECT(1, EVP_MD_CTX, "openssl.evp_digest_ctx");
  const char* in = luaL_checklstring(L, 2, &inl);

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
static LUA_FUNCTION(openssl_evp_digest_final)
{
  EVP_MD_CTX* c = CHECK_OBJECT(1, EVP_MD_CTX, "openssl.evp_digest_ctx");

  byte out[EVP_MAX_MD_SIZE];
  unsigned int outl = sizeof(out);
  int ret = 0, raw = 0;

  if (lua_isstring(L, 2))
  {
    size_t inl;
    const char* in = luaL_checklstring(L, 2, &inl);
    ret = EVP_DigestUpdate(c, in, inl);
    if (ret!=1)
    {
      ret = openssl_pushresult(L, ret);
      goto err;
    }

    raw = (lua_isnone(L, 3)) ? 0 : lua_toboolean(L, 3);
  }
  else if (lua_gettop(L) >= 3)
    raw = lua_toboolean(L, 3);
  else
    raw = (lua_isnone(L, 2)) ? 0 : lua_toboolean(L, 2);

  ret = EVP_DigestFinal_ex(c, (byte*)out, &outl);
  if (ret == 1)
  {
    if (raw)
    {
      lua_pushlstring(L, (const char*)out, outl);
    }
    else
    {
      char hex[2 * EVP_MAX_MD_SIZE + 1];
      to_hex((const char*)out, outl, hex);
      lua_pushstring(L, hex);
    }
  }
  else
    ret = openssl_pushresult(L, ret);

err:
  return ret;
}

static LUA_FUNCTION(openssl_digest_ctx_free)
{
  EVP_MD_CTX *ctx = CHECK_OBJECT(1, EVP_MD_CTX, "openssl.evp_digest_ctx");
  lua_pushnil(L);
  lua_rawsetp(L, LUA_REGISTRYINDEX, ctx);
  EVP_MD_CTX_destroy(ctx);
  return 0;
}

/***
reset evp_diget_ctx to reuse

@function reset
*/
static LUA_FUNCTION(openssl_digest_ctx_reset)
{
  EVP_MD_CTX *ctx = CHECK_OBJECT(1, EVP_MD_CTX, "openssl.evp_digest_ctx");
#if OPENSSL_VERSION_NUMBER < 0x30000000
  const EVP_MD *md = EVP_MD_CTX_md(ctx);
#else
  const EVP_MD *md = EVP_MD_CTX_get0_md(ctx);
#endif

  ENGINE* e = NULL;
  int ret;

  lua_rawgetp(L, LUA_REGISTRYINDEX, ctx);
  e = (ENGINE*)lua_topointer(L, -1);
  ret = EVP_MD_CTX_reset(ctx);
  if (ret)
  {
    EVP_MD_CTX_init(ctx);
    EVP_DigestInit_ex(ctx, md, e);
  }
  return openssl_pushresult(L, ret);
}

/***
retrieve md data

@function data
@treturn string md_data
*/

/***
restore md data

@function data
@tparam string md_data
*/
static LUA_FUNCTION(openssl_digest_ctx_data)
{
  int ret = 0;
  EVP_MD_CTX *ctx = CHECK_OBJECT(1, EVP_MD_CTX, "openssl.evp_digest_ctx");

#if OPENSSL_VERSION_NUMBER < 0x10100000L || \
  (defined(LIBRESSL_VERSION_NUMBER) && LIBRESSL_VERSION_NUMBER < 0x3050000fL)

  if (lua_isnone(L, 2))
  {
    lua_pushlstring(L, ctx->md_data, ctx->digest->ctx_size);
  }
  else
  {
    size_t l;
    const char* d = luaL_checklstring(L, 2, &l);
    luaL_argcheck(L,
                  l == (size_t)ctx->digest->ctx_size,
                  2,
                  "wrong data");
    memcpy(ctx->md_data, d, l);
    lua_pushboolean(L, 1);
  }
  ret = 1;

#else

#if defined(LIBRESSL_VERSION_NUMBER) && LIBRESSL_VERSION_NUMBER > 0x3050000fL
  lua_pushnil(L);
  lua_pushstring(L, "NYI");
  (void)ctx;

  ret = 2;
#else
  /* TODO: https://github.com/openssl/openssl/issues/14222#issuecomment-871151001 */
#if OPENSSL_VERSION_NUMBER < 0x30000000
  const EVP_MD *md = EVP_MD_CTX_md(ctx);
#else
  const EVP_MD *md = EVP_MD_CTX_get0_md(ctx);
#endif
  size_t ctx_size;

  if (lua_isnone(L, 2))
  {
    ctx_size = (size_t)EVP_MD_meth_get_app_datasize(md);
    lua_pushlstring(L, EVP_MD_CTX_md_data(ctx), ctx_size);
  }
  else
  {
    const char* d = luaL_checklstring(L, 2, &ctx_size);
    luaL_argcheck(L,
                  ctx_size == (size_t)EVP_MD_meth_get_app_datasize(md),
                  2,
                  "wrong data");
    memcpy(EVP_MD_CTX_md_data(ctx), d, ctx_size);
    lua_pushboolean(L, 1);
  }
  ret = 1;
#endif

#endif
  return ret;
}

/***
feed data for sign to get signature

@function verifyUpdate
@tparam string data to be signed
@treturn boolean result
*/
static LUA_FUNCTION(openssl_signUpdate)
{
  size_t l;
  int ret;
  EVP_MD_CTX *ctx = CHECK_OBJECT(1, EVP_MD_CTX, "openssl.evp_digest_ctx");
  const char* data = luaL_checklstring(L, 2, &l);
  ret = EVP_DigestSignUpdate(ctx, data, l);
  return openssl_pushresult(L, ret);
}

/***
feed data for verify with signature

@function verifyUpdate
@tparam string data to be verified
@treturn boolean result
*/
static LUA_FUNCTION(openssl_verifyUpdate)
{
  size_t l;
  int ret;
  EVP_MD_CTX *ctx = CHECK_OBJECT(1, EVP_MD_CTX, "openssl.evp_digest_ctx");
  const char* data = luaL_checklstring(L, 2, &l);
  ret = EVP_DigestVerifyUpdate(ctx, data, l);
  return openssl_pushresult(L, ret);
}

/***
get result of sign

@function signFinal
@tparam evp_pkey private key to do sign
@treturn string singed result
*/
static LUA_FUNCTION(openssl_signFinal)
{
  EVP_MD_CTX *ctx = CHECK_OBJECT(1, EVP_MD_CTX, "openssl.evp_digest_ctx");
  size_t siglen = 0;
  int ret = EVP_DigestSignFinal(ctx, NULL, &siglen);
  if (ret == 1)
  {
    unsigned char *sigbuf = OPENSSL_malloc(siglen);
    ret = EVP_DigestSignFinal(ctx, sigbuf, &siglen);
    if (ret == 1)
    {
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
static LUA_FUNCTION(openssl_verifyFinal)
{
  EVP_MD_CTX *ctx = CHECK_OBJECT(1, EVP_MD_CTX, "openssl.evp_digest_ctx");
  size_t signature_len;
  const char* signature = luaL_checklstring(L, 2, &signature_len);
  int ret = EVP_DigestVerifyFinal(ctx, (unsigned char*) signature, signature_len);

  EVP_MD_CTX_reset(ctx);
  return openssl_pushresult(L, ret);
}

static luaL_Reg digest_funs[] =
{
  {"new",         openssl_evp_digest_init},
  {"info",        openssl_digest_info},
  {"digest",      openssl_digest_digest},

  {"signInit",    openssl_signInit},
  {"verifyInit",  openssl_verifyInit},

  {"__tostring",  auxiliar_tostring},

  {NULL, NULL}
};


#if OPENSSL_VERSION_NUMBER >= 0x10101000L && !defined (LIBRESSL_VERSION_NUMBER) \
   || LIBRESSL_VERSION_NUMBER > 0x3050000fL
/***
get result of oneshot sign

@function sign
@tparam evp_digest_ctx
@tparam string data to sign
@treturn[1] string singed result
@treturn[2] nil followd by error message
*/
static LUA_FUNCTION(openssl_oneshot_sign)
{
  EVP_MD_CTX *ctx = CHECK_OBJECT(1, EVP_MD_CTX, "openssl.evp_digest_ctx");
  size_t tbslen;
  const uint8_t *tbs = (const uint8_t*) luaL_checklstring(L, 2, &tbslen);
  size_t siglen = 0;

  int ret = EVP_DigestSign(ctx, NULL, &siglen, tbs, tbslen);
  if (ret == 1)
  {
    unsigned char *sigbuf = OPENSSL_malloc(siglen);
    ret = EVP_DigestSign(ctx, sigbuf, &siglen, tbs, tbslen);
    if (ret == 1)
    {
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
@tparam evp_digest_ctx
@tparam string signature to verify
@tparam data to verify
@treturn[1] string singed result
@treturn[2] nil followd by error message
@tparam string signature
@treturn boolean result, true for verify pass
*/
static LUA_FUNCTION(openssl_oneshot_verify)
{
  EVP_MD_CTX *ctx = CHECK_OBJECT(1, EVP_MD_CTX, "openssl.evp_digest_ctx");
  size_t siglen;
  const uint8_t* sig = (const uint8_t*)luaL_checklstring(L, 2, &siglen);
  size_t tbslen;
  const uint8_t *tbs = (const uint8_t*) luaL_checklstring(L, 3, &tbslen);

  int ret = EVP_DigestVerify(ctx, sig, siglen, tbs, tbslen);
  EVP_MD_CTX_reset(ctx);

  if (ret < 0)
    return openssl_pushresult(L, ret);
  lua_pushboolean(L, ret);
  return ret;
}
#endif

static luaL_Reg digest_ctx_funs[] =
{
  {"update",      openssl_evp_digest_update},
  {"final",       openssl_evp_digest_final},
  {"info",        openssl_digest_ctx_info},
  {"reset",       openssl_digest_ctx_reset},
  {"close",       openssl_digest_ctx_free},
  {"data",        openssl_digest_ctx_data},


  {"signUpdate",  openssl_signUpdate},
  {"signFinal",   openssl_signFinal},
  {"verifyUpdate",openssl_verifyUpdate},
  {"verifyFinal", openssl_verifyFinal},

#if OPENSSL_VERSION_NUMBER >= 0x10101000L && !defined (LIBRESSL_VERSION_NUMBER) \
   || LIBRESSL_VERSION_NUMBER > 0x3050000fL
  {"sign",        openssl_oneshot_sign},
  {"verify",      openssl_oneshot_verify},
#endif

  {"__tostring",  auxiliar_tostring},
  {"__gc",        openssl_digest_ctx_free},
  {NULL, NULL}
};

static const luaL_Reg R[] =
{
  {"list",       openssl_digest_list},
  {"get",        openssl_digest_get},
  {"new",        openssl_digest_new},
  {"digest",     openssl_digest},

  {"signInit",   openssl_signInit},
  {"verifyInit", openssl_verifyInit},

  {NULL,  NULL}
};

int luaopen_digest(lua_State *L)
{
  auxiliar_newclass(L, "openssl.evp_digest",   digest_funs);
  auxiliar_newclass(L, "openssl.evp_digest_ctx", digest_ctx_funs);

  lua_newtable(L);
  luaL_setfuncs(L, R, 0);

  return 1;
}
