/***
hmac module perform Message Authentication Code operations.
It base on HMAC_CTX in OpenSSL v1.

@module hmac
@author  george zhao <zhaozg(at)gmail.com>
@usage
  hamc = require('openssl').hmac
*/
#include "openssl.h"
#include "private.h"

/***
get hamc_ctx object

@function new
@tparam string|integer|asn1_object alg name, nid or object identity
@tparam string key secret key
@tparam[opt] engine engine, nothing with default engine
@treturn hamc_ctx hmac object mapping HMAC_CTX in openssl

@see hmac_ctx
*/
static int openssl_hmac_ctx_new(lua_State *L)
{
  const EVP_MD *type = get_digest(L, 1, NULL);
  size_t l;
  const char *k = luaL_checklstring(L, 2, &l);
  ENGINE* e = lua_isnoneornil(L, 3) ? NULL : CHECK_OBJECT(3, ENGINE, "openssl.engine");

  HMAC_CTX *c = HMAC_CTX_new();
  int ret = HMAC_Init_ex(c, k, (int)l, type, e);
  if (ret==1)
    PUSH_OBJECT(c, "openssl.hmac_ctx");
  else
    ret = openssl_pushresult(L, ret);
  return ret;
}

static int openssl_mac_ctx_free(lua_State *L)
{
  HMAC_CTX *c = CHECK_OBJECT(1, HMAC_CTX, "openssl.hmac_ctx");
  if(!c) return 0;
  HMAC_CTX_free(c);

  FREE_OBJECT(1);
  return 0;
}

/***
compute hmac one step, in module openssl.hamc

@function hmac
@tparam evp_digest|string|nid digest digest alg identity
@tparam string message
@tparam string key
@treturn string result binary string
*/
static int openssl_hmac(lua_State *L)
{
  const EVP_MD *type = get_digest(L, 1, NULL);
  size_t len;
  const char *dat = luaL_checklstring(L, 2, &len);
  size_t l;
  const char *k = luaL_checklstring(L, 3, &l);
  int raw = (lua_isnone(L, 4)) ? 0 : lua_toboolean(L, 4);
  ENGINE* e = lua_isnoneornil(L, 5) ? NULL : CHECK_OBJECT(5, ENGINE, "openssl.engine");

  unsigned char digest[EVP_MAX_MD_SIZE];
  unsigned int dlen = EVP_MAX_MD_SIZE;

  int ret = HMAC(type, k, l, (const unsigned char*)dat, (int)len, digest, &dlen) != NULL;

  if (ret==0)
    return openssl_pushresult(L, ret);

  if (raw)
    lua_pushlstring(L, (char *)digest, dlen);
  else
  {
    char hex[2 * EVP_MAX_MD_SIZE + 1];
    to_hex((const char*)digest, dlen, hex);
    lua_pushstring(L, hex);
  }

  (void)e;
  return 1;
}

/***
openssl.hmac_ctx object
@type hmac_ctx
*/

/***
feed data to do digest

@function update
@tparam string msg data
*/
static int openssl_mac_ctx_update(lua_State *L)
{
  size_t l;

  HMAC_CTX *c = CHECK_OBJECT(1, HMAC_CTX, "openssl.hmac_ctx");
  const char *s = luaL_checklstring(L, 2, &l);

  int ret = HMAC_Update(c, (unsigned char *)s, l);
  return openssl_pushresult(L, ret);
}

/***
get result of hmac

@function final
@tparam[opt] string last last part of data
@tparam[opt] boolean raw binary or hex encoded result, default true for binary result
@treturn string val hash result
*/
static int openssl_mac_ctx_final(lua_State *L)
{
  HMAC_CTX *c = CHECK_OBJECT(1, HMAC_CTX, "openssl.hmac_ctx");
  unsigned char digest[EVP_MAX_MD_SIZE];
  size_t len = sizeof(digest);
  int raw = 0;
  int ret = 1;

  if (lua_isstring(L, 2))
  {
    size_t l;
    const char *s = luaL_checklstring(L, 2, &l);
    ret = HMAC_Update(c, (unsigned char *)s, l);
    raw = (lua_isnone(L, 3)) ? 0 : lua_toboolean(L, 3);
  }
  else
    raw = (lua_isnone(L, 2)) ? 0 : lua_toboolean(L, 2);

  if (ret==1)
  {
    ret = HMAC_Final(c, digest, (unsigned int*)&len);
  }

  if (ret==0)
    return openssl_pushresult(L, ret);

  if (raw)
  {
    lua_pushlstring(L, (char *)digest, len);
  }
  else
  {
    char hex[2 * EVP_MAX_MD_SIZE + 1];
    to_hex((const char*) digest, len, hex);
    lua_pushstring(L, hex);
  }
  return 1;
}

/***
return size of mac value

@function size
@tparam string msg data
*/
static int openssl_mac_ctx_size(lua_State *L)
{
  HMAC_CTX *c = CHECK_OBJECT(1, HMAC_CTX, "openssl.hmac_ctx");
  size_t sz = HMAC_size(c);
  lua_pushinteger(L, sz);
  return 1;
}

static luaL_Reg mac_ctx_funs[] =
{
  {"update",      openssl_mac_ctx_update},
  {"final",       openssl_mac_ctx_final},
  {"close",       openssl_mac_ctx_free},
  {"size",        openssl_mac_ctx_size},

  {"__tostring",  auxiliar_tostring},
  {"__gc",        openssl_mac_ctx_free},
  {NULL, NULL}
};

static const luaL_Reg mac_R[] =
{
  { "new",      openssl_hmac_ctx_new},
  { "hmac",     openssl_hmac},

  {NULL,  NULL}
};

int luaopen_hmac(lua_State *L)
{
  auxiliar_newclass(L, "openssl.hmac_ctx", mac_ctx_funs);

  lua_newtable(L);
  luaL_setfuncs(L, mac_R, 0);

  return 1;
}
