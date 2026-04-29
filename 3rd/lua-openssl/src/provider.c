/***
Provider module for OpenSSL 3.0+ provider API support

This module provides Lua bindings for OpenSSL 3.0+ provider functionality,
allowing loading, unloading, and querying of cryptographic providers.

Note: This module is only available with OpenSSL 3.0 or later.
LibreSSL does not support the provider API, so it is excluded.

@module provider
@usage
  local provider = require('openssl').provider
  local default_provider = provider.load('default')
*/

#include "openssl.h"
#include "private.h"

/* Provider API is only available in OpenSSL 3.0+, not in LibreSSL */
#if (OPENSSL_VERSION_NUMBER >= 0x30000000L) && !defined(LIBRESSL_VERSION_NUMBER)
#include <openssl/provider.h>

/***
Load a provider by name

@function load
@tparam string name the name of the provider to load (e.g., 'default', 'fips', 'legacy')
@tparam[opt] boolean retain if true, the provider will be retained even after all references are released
@treturn openssl.provider loaded provider object or nil on failure
@treturn string error message if failed
@usage
  local default = provider.load('default')
  local fips = provider.load('fips', true)
*/
static int openssl_provider_load(lua_State *L)
{
  const char *name = luaL_checkstring(L, 1);
  int retain = lua_isnone(L, 2) ? 0 : lua_toboolean(L, 2);
  OSSL_PROVIDER *prov = NULL;

  if (retain) {
    prov = OSSL_PROVIDER_load(NULL, name);
  } else {
    prov = OSSL_PROVIDER_try_load(NULL, name, 1);
  }

  if (prov != NULL) {
    PUSH_OBJECT(prov, "openssl.provider");
    return 1;
  }

  return openssl_pushresult(L, 0);
}

/***
Get the name of a loaded provider

@function name
@treturn string provider name
@usage
  local prov = provider.load('default')
  print(prov:name())  -- prints "default"
*/
static int openssl_provider_get_name(lua_State *L)
{
  OSSL_PROVIDER *prov = CHECK_OBJECT(1, OSSL_PROVIDER, "openssl.provider");
  const char *name = OSSL_PROVIDER_get0_name(prov);

  if (name != NULL) {
    lua_pushstring(L, name);
    return 1;
  }

  return 0;
}

/***
Check if a provider is available

@function available
@treturn boolean true if provider is available and active
@usage
  local prov = provider.load('default')
  if prov:available() then
    print("Provider is active")
  end
*/
static int openssl_provider_available(lua_State *L)
{
  OSSL_PROVIDER *prov = CHECK_OBJECT(1, OSSL_PROVIDER, "openssl.provider");
  int available = OSSL_PROVIDER_available(NULL, OSSL_PROVIDER_get0_name(prov));

  lua_pushboolean(L, available);
  return 1;
}

/***
Get provider parameters

@function get_params
@tparam table params table of parameter names to query
@treturn table table of parameter values
@usage
  local prov = provider.load('default')
  local params = prov:get_params({'name', 'version', 'buildinfo'})
  for k, v in pairs(params) do
    print(k, v)
  end
*/
static int openssl_provider_get_params(lua_State *L)
{
  OSSL_PROVIDER *prov = CHECK_OBJECT(1, OSSL_PROVIDER, "openssl.provider");
  luaL_checktype(L, 2, LUA_TTABLE);

  /* Count parameters */
  int param_count = 0;
  lua_pushnil(L);
  while (lua_next(L, 2) != 0) {
    param_count++;
    lua_pop(L, 1);
  }

  if (param_count == 0) {
    lua_newtable(L);
    return 1;
  }

  /* Allocate OSSL_PARAM array */
  OSSL_PARAM *params = OPENSSL_malloc((param_count + 1) * sizeof(OSSL_PARAM));
  if (params == NULL) {
    return luaL_error(L, "out of memory");
  }

  /* Build OSSL_PARAM array */
  int i = 0;
  lua_pushnil(L);
  while (lua_next(L, 2) != 0) {
    const char *key = lua_tostring(L, -1);
    if (key != NULL) {
      params[i] = OSSL_PARAM_construct_utf8_ptr(key, NULL, 0);
      i++;
    }
    lua_pop(L, 1);
  }
  params[i] = OSSL_PARAM_construct_end();

  /* Get parameters */
  int ret = OSSL_PROVIDER_get_params(prov, params);

  /* Build result table */
  lua_newtable(L);
  if (ret == 1) {
    for (i = 0; params[i].key != NULL; i++) {
      if (params[i].data_type == OSSL_PARAM_UTF8_PTR &&
          params[i].data != NULL &&
          *(char **)params[i].data != NULL) {
        lua_pushstring(L, *(char **)params[i].data);
        lua_setfield(L, -2, params[i].key);
      }
    }
  }

  OPENSSL_free(params);
  return 1;
}

/***
Unload a provider

@function unload
@treturn boolean true on success
@usage
  local prov = provider.load('legacy')
  -- ... use provider
  prov:unload()
*/
static int openssl_provider_unload(lua_State *L)
{
  OSSL_PROVIDER *prov = CHECK_OBJECT(1, OSSL_PROVIDER, "openssl.provider");
  int ret = OSSL_PROVIDER_unload(prov);

  lua_pushboolean(L, ret);
  return 1;
}

/***
Self test a provider

@function self_test
@treturn boolean true if self test passes
@usage
  local prov = provider.load('fips')
  if prov:self_test() then
    print("FIPS provider self-test passed")
  end
*/
static int openssl_provider_self_test(lua_State *L)
{
  OSSL_PROVIDER *prov = CHECK_OBJECT(1, OSSL_PROVIDER, "openssl.provider");
  int ret = OSSL_PROVIDER_self_test(prov);

  lua_pushboolean(L, ret);
  return 1;
}

/***
List all available providers

@function list
@treturn table array of provider names
@usage
  local providers = provider.list()
  for i, name in ipairs(providers) do
    print(name)
  end
*/
static int openssl_provider_list_all(lua_State *L)
{
  /* This is a simplified version - OpenSSL 3.0 doesn't have a direct API to list all
     available providers, so we'll try loading common ones */
  const char *common_providers[] = {
    "default",
    "fips",
    "legacy",
    "base",
    "null",
    NULL
  };

  lua_newtable(L);
  int idx = 1;

  for (int i = 0; common_providers[i] != NULL; i++) {
    if (OSSL_PROVIDER_available(NULL, common_providers[i])) {
      lua_pushstring(L, common_providers[i]);
      lua_rawseti(L, -2, idx++);
    }
  }

  return 1;
}

/***
Get provider by name without loading

@function get
@tparam string name the name of the provider
@treturn openssl.provider provider object if already loaded, nil otherwise
@usage
  local prov = provider.get('default')
  if prov then
    print("Default provider is loaded")
  end
*/
static int openssl_provider_get(lua_State *L)
{
  const char *name = luaL_checkstring(L, 1);

  if (OSSL_PROVIDER_available(NULL, name)) {
    /* Try to get the provider without incrementing refcount */
    OSSL_PROVIDER *prov = OSSL_PROVIDER_load(NULL, name);
    if (prov != NULL) {
      PUSH_OBJECT(prov, "openssl.provider");
      return 1;
    }
  }

  lua_pushnil(L);
  return 1;
}

/***
Provider object garbage collection

@function __gc
@treturn nil always returns nil
*/
static int openssl_provider_gc(lua_State *L)
{
  OSSL_PROVIDER *prov = CHECK_OBJECT(1, OSSL_PROVIDER, "openssl.provider");
  /* Note: We don't automatically unload here as the provider might be in use
     Users should explicitly call unload() if needed */
  (void)prov;
  return 0;
}

/***
Provider object string representation

@function __tostring
@treturn string string representation of provider
*/
static int openssl_provider_tostring(lua_State *L)
{
  OSSL_PROVIDER *prov = CHECK_OBJECT(1, OSSL_PROVIDER, "openssl.provider");
  const char *name = OSSL_PROVIDER_get0_name(prov);

  lua_pushfstring(L, "openssl.provider: %s (%p)", name, prov);
  return 1;
}

static luaL_Reg provider_funs[] = {
  {"name",        openssl_provider_get_name},
  {"available",   openssl_provider_available},
  {"get_params",  openssl_provider_get_params},
  {"unload",      openssl_provider_unload},
  {"self_test",   openssl_provider_self_test},

  {"__gc",        openssl_provider_gc},
  {"__tostring",  openssl_provider_tostring},

  {NULL, NULL}
};

static luaL_Reg provider_funcs[] = {
  {"load",  openssl_provider_load},
  {"list",  openssl_provider_list_all},
  {"get",   openssl_provider_get},

  {NULL, NULL}
};

int luaopen_provider(lua_State *L)
{
  auxiliar_newclass(L, "openssl.provider", provider_funs);

  lua_newtable(L);
  luaL_setfuncs(L, provider_funcs, 0);

  return 1;
}

#else

/* For OpenSSL < 3.0, provide stub module */
int luaopen_provider(lua_State *L)
{
  lua_newtable(L);
  lua_pushstring(L, "Provider API requires OpenSSL 3.0 or later");
  lua_setfield(L, -2, "_error");
  return 1;
}

#endif
