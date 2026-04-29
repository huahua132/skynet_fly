/***
util module with internal utility functions for lua-openssl

This module provides internal utility functions for value management,
memory handling, and registry operations used throughout the
lua-openssl library.
*/
#include "private.h"

int
openssl_newvalue(lua_State *L, const void *p)
{
  lua_rawgetp(L, LUA_REGISTRYINDEX, p);
  if (lua_isnil(L, -1)) {
    lua_newtable(L);
    lua_rawsetp(L, LUA_REGISTRYINDEX, p);
  }
  lua_pop(L, 1);
  return 0;
}

int
openssl_freevalue(lua_State *L, const void *p)
{
  lua_pushnil(L);
  lua_rawsetp(L, LUA_REGISTRYINDEX, p);

  return 0;
}

int
openssl_valueset(lua_State *L, const void *p, const char *field)
{
  lua_rawgetp(L, LUA_REGISTRYINDEX, p);
  lua_pushstring(L, field);
  lua_pushvalue(L, -3);
  lua_rawset(L, -3);
  lua_pop(L, 2);
  return 0;
}

int
openssl_valueget(lua_State *L, const void *p, const char *field)
{
  lua_rawgetp(L, LUA_REGISTRYINDEX, p);
  if (!lua_isnil(L, -1)) {
    lua_pushstring(L, field);
    lua_rawget(L, -2);
    lua_remove(L, -2);
  }
  return lua_type(L, -1);
}

int
openssl_valueseti(lua_State *L, const void *p, int i)
{
  lua_rawgetp(L, LUA_REGISTRYINDEX, p);
  lua_pushvalue(L, -2);
  lua_rawseti(L, -2, i);
  lua_pop(L, 2);
  return 0;
}

int
openssl_valuegeti(lua_State *L, const void *p, int i)
{
  lua_rawgetp(L, LUA_REGISTRYINDEX, p);
  if (!lua_isnil(L, -1)) {
    lua_rawgeti(L, -1, i);
    lua_remove(L, -2);
  }
  return lua_type(L, -1);
}
