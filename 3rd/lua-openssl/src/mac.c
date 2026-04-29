/***
mac module perform Message Authentication Code operations.
It base on EVP_MAC in OpenSSL v3.

@module mac
@author  george zhao <zhaozg(at)gmail.com>
@usage
  mac = require('openssl').mac
*/
#include "openssl.h"
#include "private.h"

#if (OPENSSL_VERSION_NUMBER >= 0x30000000L)
/***
create new MAC object
@function new
@tparam string algorithm MAC algorithm name (e.g., "HMAC", "CMAC", "GMAC")
@tparam[opt] string properties optional properties string
@treturn mac|nil new MAC object or nil on failure
*/
static int
openssl_mac_new(lua_State *L)
{
  const char *algorithm = luaL_checkstring(L, 2);
  const char *properties = luaL_optstring(L, 3, NULL);

  EVP_MAC *mac = EVP_MAC_fetch(NULL, algorithm, properties);
  if (mac) {
    PUSH_OBJECT(mac, "openssl.mac");
    return 1;
  }
  return openssl_pushresult(L, 0);
}

static int
openssl_mac_gc(lua_State *L)
{
  EVP_MAC *mac = CHECK_OBJECT(1, EVP_MAC, "openssl.mac");
  EVP_MAC_free(mac);
  return 0;
}

/***
check if MAC algorithm supports a specific name
@function is_a
@tparam string name algorithm name to check
@treturn boolean true if MAC supports the given name
*/
static int
openssl_mac_is_a(lua_State *L)
{
  EVP_MAC    *mac = CHECK_OBJECT(1, EVP_MAC, "openssl.mac");
  const char *name = luaL_checkstring(L, 2);
  int         ret = EVP_MAC_is_a(mac, name);
  return openssl_pushresult(L, ret);
}

static void
openssl_mac_names_do(const char *name, void *data)
{
  lua_State *L = data;
  int        len = lua_rawlen(L, -1);
  lua_pushstring(L, name);
  lua_rawseti(L, -2, len + 1);
}

/***
get all names supported by this MAC algorithm
@function names
@treturn table array of supported algorithm names
*/
static int
openssl_mac_names(lua_State *L)
{
  EVP_MAC *mac = CHECK_OBJECT(1, EVP_MAC, "openssl.mac");

  lua_newtable(L);
  EVP_MAC_names_do_all(mac, openssl_mac_names_do, L);
  return 1;
}

/***
get provider name for this MAC algorithm
@function provider
@treturn string name of the provider implementing this MAC
*/
static int
openssl_mac_provider(lua_State *L)
{
  EVP_MAC             *mac = CHECK_OBJECT(1, EVP_MAC, "openssl.mac");
  const OSSL_PROVIDER *provider = EVP_MAC_get0_provider(mac);
  const char          *name = OSSL_PROVIDER_get0_name(provider);
  lua_pushstring(L, name);
  return 1;
}

static int
openssl_mac_get_params(lua_State *L)
{
  EVP_MAC    *mac = CHECK_OBJECT(1, EVP_MAC, "openssl.mac");
  OSSL_PARAM *params = openssl_toparams(L, 2);
  int         ret = EVP_MAC_get_params(mac, params);
  if (ret == 1)
    ret = openssl_pushparams(L, params);
  else {
    ret = openssl_pushparams(L, params);
    ret += openssl_pushresult(L, ret);
  }
  OPENSSL_free(params);
  return ret;
}

static int
openssl_mac_ctx_gc(lua_State *L)
{
  EVP_MAC_CTX *ctx = CHECK_OBJECT(1, EVP_MAC_CTX, "openssl.mac_ctx");
  EVP_MAC_CTX_free(ctx);
  return 0;
}

/***
duplicate MAC context
@function dup
@treturn mac_ctx duplicated MAC context
*/
static int
openssl_mac_ctx_dup(lua_State *L)
{
  EVP_MAC_CTX *ctx = CHECK_OBJECT(1, EVP_MAC_CTX, "openssl.mac_ctx");
  EVP_MAC_CTX *clone = EVP_MAC_CTX_dup(ctx);
  PUSH_OBJECT(clone, "openssl.mac_ctx");
  return 1;
}

/***
get MAC object from MAC context
@function mac
@treturn openssl.mac the MAC object associated with this context
*/
static int
openssl_mac_ctx_mac(lua_State *L)
{
  EVP_MAC_CTX *ctx = CHECK_OBJECT(1, EVP_MAC_CTX, "openssl.mac_ctx");
  EVP_MAC     *mac = EVP_MAC_CTX_get0_mac(ctx);
  PUSH_OBJECT(mac, "openssl.mac");
  return 1;
}

/***
get or set MAC context parameters (not yet implemented)
@function params
@treturn nil always returns nil (NYI - Not Yet Implemented)
@treturn string error message "NYI"
*/
static int
openssl_mac_ctx_params(lua_State *L)
{
  EVP_MAC_CTX *ctx = CHECK_OBJECT(1, EVP_MAC_CTX, "openssl.mac_ctx");
  (void)ctx;
  /*
  int EVP_MAC_CTX_get_params(EVP_MAC_CTX *ctx, OSSL_PARAM params[]);
  int EVP_MAC_CTX_set_params(EVP_MAC_CTX *ctx, const OSSL_PARAM params[]);
  */
  lua_pushnil(L);
  lua_pushstring(L, "NYI");
  return 1;
}

static void
openssl_mac_entry(EVP_MAC *mac, void *arg)
{
  lua_State *L = arg;
  int        i = lua_rawlen(L, -1);

  PUSH_OBJECT(mac, "openssl.mac");
  lua_rawseti(L, -2, i + 1);
}

static int
openssl_mac_all(lua_State *L)
{
  OSSL_LIB_CTX *ctx = CHECK_OBJECT(1, OSSL_LIB_CTX, "openssl.ctx");
  lua_newtable(L);

  EVP_MAC_do_all_provided(ctx, openssl_mac_entry, L);
  return 1;
}

const OSSL_PARAM *EVP_MAC_gettable_params(const EVP_MAC *mac);
const OSSL_PARAM *EVP_MAC_gettable_ctx_params(const EVP_MAC *mac);
const OSSL_PARAM *EVP_MAC_settable_ctx_params(const EVP_MAC *mac);

/***
get mac_ctx object

@function new
@tparam string|integer|asn1_object alg name, nid or object identity
@tparam string key secret key
@tparam[opt] openssl.engine engine nothing with default engine
@treturn mac_ctx object mapping MAC_CTX in openssl
*/
static int
openssl_mac_ctx_new(lua_State *L)
{
  int               ret = 0;
  OSSL_PARAM        params[2];
  size_t            params_n = 0;
  size_t            l;
  const char       *k;
  const EVP_MD     *type_md;
  const EVP_CIPHER *type_c;
  EVP_MAC          *mac;
  EVP_MAC_CTX      *ctx;

  type_c = opt_cipher(L, 1, NULL);
  if (type_c)
    type_md = NULL;
  else
    type_md = opt_digest(L, 1, NULL);

  if (type_md == NULL && type_c == NULL) {
    luaL_argerror(
      L, 1, "must be a string, NID number or asn1_object identity digest/cipher method");
  }

  k = luaL_checklstring(L, 2, &l);

  if (type_md) {
    mac = EVP_MAC_fetch(NULL, "hmac", NULL);
    params[params_n++]
      = OSSL_PARAM_construct_utf8_string("digest", (char *)EVP_MD_name(type_md), 0);
  } else {
    mac = EVP_MAC_fetch(NULL, "cmac", NULL);
    params[params_n++]
      = OSSL_PARAM_construct_utf8_string("cipher", (char *)EVP_CIPHER_name(type_c), 0);
  }
  params[params_n] = OSSL_PARAM_construct_end();

  if (mac) {
    ctx = EVP_MAC_CTX_new(mac);
    if (ctx) {
      ret = EVP_MAC_init(ctx, (const unsigned char *)k, l, params);
      if (ret == 1)
        PUSH_OBJECT(ctx, "openssl.mac_ctx");
      else {
        ret = openssl_pushresult(L, ret);
        EVP_MAC_CTX_free(ctx);
      }
    }
    EVP_MAC_free(mac);
  }
  return ret;
}

/***
free MAC context resources
@function free
@treturn number always returns 0
*/
static int
openssl_mac_ctx_free(lua_State *L)
{
  EVP_MAC_CTX *c = CHECK_OBJECT(1, EVP_MAC_CTX, "openssl.mac_ctx");
  if (!c) return 0;
  EVP_MAC_CTX_free(c);

  FREE_OBJECT(1);
  return 0;
}

/***
compute mac one step, in module openssl.mac

@function mac
@tparam evp_digest|string|nid digest digest alg identity
@tparam string message
@tparam string key
@tparam[opt=false] boolean raw binary or hex encoded result, default false for hex result
@treturn string result binary string when raw is true, hex string otherwise
*/
static int
openssl_mac(lua_State *L)
{
  int           ret = 0;
  const EVP_MD *type = get_digest(L, 1, NULL);
  size_t        len;
  const char   *dat = luaL_checklstring(L, 2, &len);
  size_t        l;
  const char   *k = luaL_checklstring(L, 3, &l);
  int           raw = (lua_isnone(L, 4)) ? 0 : lua_toboolean(L, 4);
  ENGINE       *e = lua_isnoneornil(L, 5) ? NULL : CHECK_OBJECT(5, ENGINE, "openssl.engine");
  (void)e;

  unsigned char digest[EVP_MAX_MD_SIZE];

  size_t       dlen = EVP_MAX_MD_SIZE;
  EVP_MAC     *mac;
  EVP_MAC_CTX *ctx = NULL;

  OSSL_PARAM params[2];
  size_t     params_n = 0;

  mac = EVP_MAC_fetch(NULL, "hmac", NULL);
  if (mac) {
    params[params_n++] = OSSL_PARAM_construct_utf8_string("digest", (char *)EVP_MD_name(type), 0);
    params[params_n] = OSSL_PARAM_construct_end();

    ctx = EVP_MAC_CTX_new(mac);
    if (ctx) {
      ret = EVP_MAC_init(ctx, (const unsigned char *)k, l, params);
      if (ret == 1) {
        ret = EVP_MAC_update(ctx, (const unsigned char *)dat, len);
        if (ret == 1) ret = EVP_MAC_final(ctx, digest, &dlen, dlen);
      }
      EVP_MAC_CTX_free(ctx);
    }
    EVP_MAC_free(mac);
  }

  if (ret == 0) return openssl_pushresult(L, ret);

  if (raw)
    lua_pushlstring(L, (char *)digest, dlen);
  else {
    char hex[2 * EVP_MAX_MD_SIZE + 1];
    to_hex((const char *)digest, dlen, hex);
    lua_pushstring(L, hex);
  }

  return 1;
}

/***
feed data to do digest

@function update
@tparam string msg data
@treturn boolean result true for success
*/
static int
openssl_mac_ctx_update(lua_State *L)
{
  int         ret;
  size_t      l;
  const char *s;

  EVP_MAC_CTX *c = CHECK_OBJECT(1, EVP_MAC_CTX, "openssl.mac_ctx");
  s = luaL_checklstring(L, 2, &l);

  ret = EVP_MAC_update(c, (unsigned char *)s, l);
  return openssl_pushresult(L, ret);
}

/***
get result of mac

@function final
@tparam[opt] string last last part of data
@tparam[opt] boolean raw binary or hex encoded result, default true for binary result
@treturn string val hash result
*/
static int
openssl_mac_ctx_final(lua_State *L)
{
  EVP_MAC_CTX  *c = CHECK_OBJECT(1, EVP_MAC_CTX, "openssl.mac_ctx");
  unsigned char digest[EVP_MAX_MD_SIZE];
  size_t        len = sizeof(digest);
  int           raw = 0;
  int           ret = 1;

  if (lua_isstring(L, 2)) {
    size_t      l;
    const char *s = luaL_checklstring(L, 2, &l);
    ret = EVP_MAC_update(c, (unsigned char *)s, l);
    raw = (lua_isnone(L, 3)) ? 0 : lua_toboolean(L, 3);
  } else
    raw = (lua_isnone(L, 2)) ? 0 : lua_toboolean(L, 2);

  if (ret == 1) {
    ret = EVP_MAC_final(c, digest, &len, len);
  }

  if (ret == 0) return openssl_pushresult(L, ret);

  if (raw) {
    lua_pushlstring(L, (char *)digest, len);
  } else {
    char hex[2 * EVP_MAX_MD_SIZE + 1];
    to_hex((const char *)digest, len, hex);
    lua_pushstring(L, hex);
  }
  return 1;
}

/***
return size of mac value

@function size
@tparam string msg data
@treturn number size of MAC value in bytes
*/
static int
openssl_mac_ctx_size(lua_State *L)
{
  EVP_MAC_CTX *c = CHECK_OBJECT(1, EVP_MAC_CTX, "openssl.mac_ctx");
  size_t       sz = EVP_MAC_CTX_get_mac_size(c);

  lua_pushinteger(L, sz);
  return 1;
}

static luaL_Reg mac_funs[] = {
  { "is_a",       openssl_mac_is_a       },
  { "names",      openssl_mac_names      },
  { "provider",   openssl_mac_provider   },
  { "get_params", openssl_mac_get_params },

  { "__tostring", auxiliar_tostring      },
  { "__gc",       openssl_mac_gc         },
  { NULL,         NULL                   }
};

static luaL_Reg mac_ctx_funs[] = {
  { "update",     openssl_mac_ctx_update },
  { "final",      openssl_mac_ctx_final  },
  { "close",      openssl_mac_ctx_free   },
  { "size",       openssl_mac_ctx_size   },

  { "dup",        openssl_mac_ctx_dup    },
  { "mac",        openssl_mac_ctx_mac    },
  { "params",     openssl_mac_ctx_params },

  { "__tostring", auxiliar_tostring      },
  { "__gc",       openssl_mac_ctx_free   },

  { NULL,         NULL                   }
};

static const luaL_Reg mac_R[] = {
  { "ctx", openssl_mac_ctx_new },
  { "new", openssl_mac_new     },
  { "mac", openssl_mac         },

  { NULL,  NULL                }
};

int
luaopen_mac(lua_State *L)
{
  auxiliar_newclass(L, "openssl.mac", mac_funs);
  auxiliar_newclass(L, "openssl.mac_ctx", mac_ctx_funs);

  lua_newtable(L);
  luaL_setfuncs(L, mac_R, 0);

  return 1;
}
#endif
