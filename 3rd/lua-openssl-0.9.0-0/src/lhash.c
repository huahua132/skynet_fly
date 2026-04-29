/*=========================================================================*\
* lhash.c
* openssl lhash object for lua-openssl binding
*
* Author:  george zhao <zhaozg(at)gmail.com>
\*=========================================================================*/
#include "openssl.h"
#include "private.h"
#include <openssl/conf.h>

#if 0
static void table2data(lua_State*L, int idx, BIO* bio)
{
  lua_pushnil(L);
  while (lua_next(L, idx))
  {
    const char * key = lua_tostring(L, -2);
    if (lua_istable(L, -1))
    {
      BIO_printf(bio, "[%s]\n", key);
      table2data(L, lua_gettop(L), bio);
    }
    else
    {
      const char * val = lua_tostring(L, -1);
      BIO_printf(bio, "%s=%s\n", key, val);
    }
    lua_pop(L, 1);
  }
}
#endif

static LUA_FUNCTION(openssl_lhash_read)
{
  long eline = -1;
  BIO* bio = load_bio_object(L, 1);
  LHASH* lhash = CONF_load_bio(NULL, bio, &eline);
  BIO_free(bio);
  if (lhash)
  {
    PUSH_OBJECT(lhash, "openssl.lhash");
    return 1;
  }
  else
  {
    lua_pushfstring(L, "ERROR at LINE %d", eline);
    return luaL_argerror(L, 1, lua_tostring(L, -1));
  }
}


static LUA_FUNCTION(openssl_lhash_load)
{
  long eline = -1;
  const char* conf = luaL_checkstring(L, 1);
  BIO* bio = BIO_new_file(conf, "r");
  LHASH* lhash = CONF_load_bio(NULL, bio, &eline);
  BIO_free(bio);
  if (lhash)
    PUSH_OBJECT(lhash, "openssl.lhash");
  else
  {
    lua_pushfstring(L, "ERROR at LINE %d", eline);
    return luaL_argerror(L, 1, lua_tostring(L, -1));
  }

  return 1;
}

LUA_FUNCTION(openssl_lhash_gc)
{
  LHASH* lhash = CHECK_OBJECT(1, LHASH, "openssl.lhash");
  CONF_free(lhash);
  return 0;
}

LUA_FUNCTION(openssl_lhash_get_number)
{
  LHASH* lhash = CHECK_OBJECT(1, LHASH, "openssl.lhash");
  const char* group = luaL_checkstring(L, 2);
  const char* name = luaL_checkstring(L, 3);
  lua_pushinteger(L, CONF_get_number(lhash, group, name));
  return 1;
}


LUA_FUNCTION(openssl_lhash_get_string)
{
  LHASH* lhash = CHECK_OBJECT(1, LHASH, "openssl.lhash");
  const char* group = luaL_checkstring(L, 2);
  const char* name = luaL_checkstring(L, 3);
  lua_pushstring(L, CONF_get_string(lhash, group, name));

  return 1;
}

static void dump_value_doall_arg(CONF_VALUE const *a, lua_State *L)
{
  if (a->name)
  {
    lua_getfield(L, -1, a->section);
    if (!lua_istable(L, -1))
    {
      lua_pop(L, 1);
      lua_newtable(L);
      lua_setfield(L, -2, a->section);
      lua_getfield(L, -1, a->section);
    }
    AUXILIAR_SET(L, -1, a->name, a->value, string);
    lua_pop(L, 1);
  }
  else
  {
    if (a->section)
    {
      lua_getfield(L, -1, a->section);
      if (lua_isnil(L, -1))
      {
        lua_pop(L, 1);
        lua_newtable(L);
        lua_setfield(L, -2, a->section);
      }
      else
        lua_pop(L, 1);
    }
    else
    {
      AUXILIAR_SET(L, -1, a->name, a->value, string);
    }
  }
}

#if OPENSSL_VERSION_NUMBER >= 0x10100000L && defined(LIBRESSL_VERSION_NUMBER)==0
IMPLEMENT_LHASH_DOALL_ARG_CONST(CONF_VALUE, lua_State);
#elif OPENSSL_VERSION_NUMBER >= 0x10000002L
static IMPLEMENT_LHASH_DOALL_ARG_FN(dump_value, CONF_VALUE, lua_State)
#endif
#if defined(LIBRESSL_VERSION_NUMBER)==0
#define LHM_lh_doall_arg(type, lh, fn, arg_type, arg) \
  lh_doall_arg(CHECKED_LHASH_OF(type, lh), fn, CHECKED_PTR_OF(arg_type, arg))
#endif

static LUA_FUNCTION(openssl_lhash_parse)
{
  LHASH* lhash = CHECK_OBJECT(1, LHASH, "openssl.lhash");

  lua_newtable(L);
#if OPENSSL_VERSION_NUMBER >= 0x10100000L && defined(LIBRESSL_VERSION_NUMBER)==0
  lh_CONF_VALUE_doall_lua_State(lhash, dump_value_doall_arg, L);
#elif OPENSSL_VERSION_NUMBER >= 0x10000002L
  lh_CONF_VALUE_doall_arg(lhash, LHASH_DOALL_ARG_FN(dump_value), lua_State, L);
#else
  lh_doall_arg(lhash, (LHASH_DOALL_ARG_FN_TYPE)dump_value_doall_arg, L);
#endif

  return 1;
}


static LUA_FUNCTION(openssl_lhash_export)
{
  LHASH* lhash = CHECK_OBJECT(1, LHASH, "openssl.lhash");

  BIO *bio = BIO_new(BIO_s_mem());
  BUF_MEM *bptr = NULL;

  CONF_dump_bio(lhash, bio);
  BIO_get_mem_ptr(bio, &bptr);

  lua_pushlstring(L, bptr->data, bptr->length);
  BIO_free(bio);

  return 1;
}

static luaL_Reg lhash_funs[] =
{
  {"__tostring", auxiliar_tostring},
  {"__gc", openssl_lhash_gc},

  {"parse", openssl_lhash_parse},
  {"export", openssl_lhash_export},
  {"get_string", openssl_lhash_get_string},
  {"get_number", openssl_lhash_get_number},

  { NULL, NULL }
};

int openssl_register_lhash(lua_State* L)
{
  auxiliar_newclass(L, "openssl.lhash", lhash_funs);
  AUXILIAR_SET(L, -1, "lhash_read", openssl_lhash_read, cfunction);
  AUXILIAR_SET(L, -1, "lhash_load", openssl_lhash_load, cfunction);
  return 0;
};
