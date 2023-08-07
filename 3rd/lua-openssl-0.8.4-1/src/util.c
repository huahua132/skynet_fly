#include "private.h"

int openssl_newvalue(lua_State*L,const void*p)
{
  lua_rawgetp(L, LUA_REGISTRYINDEX, p);
  if (lua_isnil(L, -1))
  {
    lua_pop(L, 1);
    lua_newtable(L);
    lua_pushliteral(L, "reference");
    lua_pushinteger(L, 1);
    lua_rawset(L, -3);
    lua_rawsetp(L, LUA_REGISTRYINDEX, p);
  }
  else
  {
    lua_pushliteral(L, "reference");
    lua_rawget(L, -2);
    lua_pushinteger(L, lua_tointeger(L, -1)+1);
    lua_replace(L, -2);
    lua_pushliteral(L, "reference");
    lua_insert(L, lua_gettop(L) - 1);
    lua_rawset(L, -3);

    lua_pop(L, 1);
  }
  return 0;
}

int openssl_freevalue(lua_State*L, const void*p)
{
  int ref = 0;
  lua_rawgetp(L, LUA_REGISTRYINDEX, p);
  lua_pushliteral(L, "reference");
  lua_rawget(L, -2);

  ref = lua_tointeger(L, -1);
  ref = ref - 1;
  lua_pop(L, 1);

  if (ref>0)
  {
    lua_pushliteral(L, "reference");
    lua_pushinteger(L, ref);
    lua_rawset(L, -3);
  }
  lua_pop(L, 1);

  if (ref==0)
  {
    lua_pushnil(L);
    lua_rawsetp(L, LUA_REGISTRYINDEX, p);
  }

  return 0;
}

int openssl_valueset(lua_State*L, const void*p, const char*field)
{
  lua_rawgetp(L, LUA_REGISTRYINDEX, p);
  lua_pushvalue(L, -2);
  lua_remove(L, -3);
  lua_setfield(L, -2, field);
  lua_pop(L, 1);
  return 0;
}

int openssl_valueget(lua_State*L, const void*p, const char*field)
{
  lua_rawgetp(L, LUA_REGISTRYINDEX, p);
  if (!lua_isnil(L, -1))
  {
    lua_getfield(L, -1, field);
    lua_remove(L, -2);
  }
  return lua_type(L, -1);
}

int openssl_valueseti(lua_State*L, const void*p, int i)
{
  lua_rawgetp(L, LUA_REGISTRYINDEX, p);
  lua_pushvalue(L, -2);
  lua_remove(L, -3);
  lua_rawseti(L, -2, i);
  lua_pop(L, 1);
  return 0;
}

int openssl_valuegeti(lua_State*L, const void*p, int i)
{
  lua_rawgetp(L, LUA_REGISTRYINDEX, p);
  if (!lua_isnil(L, -1))
  {
    lua_rawgeti(L, -1, i);
    lua_remove(L, -2);
  }
  return lua_type(L, -1);
}

