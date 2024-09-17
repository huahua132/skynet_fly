/*=========================================================================*\
* dh.c
* DH routines for lua-openssl binding
*
* Author:  george zhao <zhaozg(at)gmail.com>
\*=========================================================================*/
#include "openssl.h"
#include "private.h"
#include <openssl/dh.h>
#include <openssl/engine.h>

#if !defined(OPENSSL_NO_DH)
static LUA_FUNCTION(openssl_dh_free)
{
  DH* dh = CHECK_OBJECT(1, DH, "openssl.dh");
  DH_free(dh);
  return 0;
};

static LUA_FUNCTION(openssl_dh_parse)
{
  const BIGNUM *p = NULL, *q = NULL, *g = NULL, *pub = NULL, *pri = NULL;
  DH* dh = CHECK_OBJECT(1, DH, "openssl.dh");
  lua_newtable(L);

  lua_pushinteger(L, DH_size(dh));
  lua_setfield(L, -2, "size");

  lua_pushinteger(L, DH_bits(dh));
  lua_setfield(L, -2, "bits");

  DH_get0_pqg(dh, &p, &q, &g);
  DH_get0_key(dh, &pub, &pri);

  OPENSSL_PKEY_GET_BN(p, p);
  OPENSSL_PKEY_GET_BN(q, q);
  OPENSSL_PKEY_GET_BN(g, g);
  OPENSSL_PKEY_GET_BN(pub, pub_key);
  OPENSSL_PKEY_GET_BN(pri, priv_key);

  return 1;
}

static LUA_FUNCTION(openssl_dh_check)
{
  const DH* dh = CHECK_OBJECT(1, DH, "openssl.dh");
  int ret = 0;
  int codes = 0;

  if (lua_isuserdata(L, 2))
  {
    const BIGNUM* pub = CHECK_OBJECT(2, BIGNUM, "openssl.bn");
    ret = DH_check_pub_key(dh, pub, &codes);
  } else
    ret = DH_check(dh, &codes);

  lua_pushboolean(L, ret);
  lua_pushinteger(L, codes);
  return 2;
}

static int openssl_dh_generate_parameters(lua_State *L)
{
  int bits = luaL_optint(L, 1, 1024);
  int generator = luaL_optint(L, 2, 2);
  ENGINE *eng = lua_isnoneornil(L, 3) ? NULL : CHECK_OBJECT(3, ENGINE, "openssl.engine");
  int ret = 0;

  DH *dh = eng ? DH_new_method(eng) : DH_new();
  ret = DH_generate_parameters_ex(dh, bits, generator, NULL);

  if (ret == 1)
  {
    PUSH_OBJECT(dh, "openssl.dh");
    return 1;
  }
  DH_free(dh);
  return openssl_pushresult(L, ret);
}

static int openssl_dh_generate_key(lua_State *L)
{
  DH* dhparamater = CHECK_OBJECT(1, DH, "openssl.dh");
  DH *dh = DHparams_dup(dhparamater);

  int ret = DH_generate_key(dh);
  if (ret == 1)
  {
    PUSH_OBJECT(dh, "openssl.dh");
    return 1;
  }
  DH_free(dh);
  return openssl_pushresult(L, ret);
}

static luaL_Reg dh_funs[] =
{
  {"generate_key",  openssl_dh_generate_key},
  {"parse",         openssl_dh_parse},
  {"check",         openssl_dh_check},

  {"__gc",          openssl_dh_free},
  {"__tostring",    auxiliar_tostring},

  { NULL, NULL }
};

static LuaL_Enumeration dh_problems[] =
{
  {"DH_CHECK_P_NOT_PRIME",         DH_CHECK_P_NOT_PRIME},
  {"DH_CHECK_P_NOT_SAFE_PRIME",    DH_CHECK_P_NOT_SAFE_PRIME},
  {"DH_UNABLE_TO_CHECK_GENERATOR", DH_UNABLE_TO_CHECK_GENERATOR},
  {"DH_NOT_SUITABLE_GENERATOR",    DH_NOT_SUITABLE_GENERATOR},
#ifdef DH_CHECK_Q_NOT_PRIME
  {"DH_CHECK_Q_NOT_PRIME",         DH_CHECK_Q_NOT_PRIME},
#endif
#ifdef DH_CHECK_INVALID_Q_VALUE
  {"DH_CHECK_INVALID_Q_VALUE",     DH_CHECK_INVALID_Q_VALUE},
#endif
#ifdef DH_CHECK_INVALID_J_VALUE
  {"DH_CHECK_INVALID_J_VALUE",     DH_CHECK_INVALID_J_VALUE},
#endif

  {"DH_CHECK_PUBKEY_TOO_SMALL",    DH_CHECK_PUBKEY_TOO_SMALL},
  {"DH_CHECK_PUBKEY_TOO_LARGE",    DH_CHECK_PUBKEY_TOO_LARGE},
#ifdef DH_CHECK_PUBKEY_INVALID
  {"DH_CHECK_PUBKEY_INVALID",      DH_CHECK_PUBKEY_INVALID},
#endif

  {NULL,                           -1}
};

static int openssl_dh_problems(lua_State *L)
{
  int reason = luaL_checkint(L, 1);
  int pub = lua_toboolean(L, 2);
  int i = 1;

#define VAL(r, v)  if(r & DH_##v) \
  { lua_pushliteral(L, #v);  lua_rawseti(L, -2, i++); }

  lua_newtable(L);
  if (pub)
  {
    VAL(reason, CHECK_PUBKEY_TOO_SMALL);
    VAL(reason, CHECK_PUBKEY_TOO_LARGE);
#ifdef DH_CHECK_PUBKEY_INVALID
    VAL(reason, CHECK_PUBKEY_INVALID);
#endif
  }
  else
  {
    VAL(reason, CHECK_P_NOT_PRIME);
    VAL(reason, CHECK_PUBKEY_TOO_SMALL);
    VAL(reason, UNABLE_TO_CHECK_GENERATOR);
    VAL(reason, NOT_SUITABLE_GENERATOR);

#ifdef DH_CHECK_Q_NOT_PRIME
    VAL(reason, CHECK_Q_NOT_PRIME);
#endif
#ifdef DH_CHECK_INVALID_Q_VALUE
    VAL(reason, CHECK_INVALID_Q_VALUE);
#endif
#ifdef DH_CHECK_INVALID_J_VALUE
    VAL(reason, CHECK_INVALID_J_VALUE);
#endif
  }

#undef VAL

  return 1;
}

static luaL_Reg R[] =
{
  {"generate_parameters", openssl_dh_generate_parameters},
  {"problems",            openssl_dh_problems},

  {NULL, NULL}
};


int luaopen_dh(lua_State *L)
{
  auxiliar_newclass(L, "openssl.dh",     dh_funs);

  lua_newtable(L);
  luaL_setfuncs(L, R, 0);

  auxiliar_enumerate(L, -1, dh_problems);

  return 1;
}
#endif
