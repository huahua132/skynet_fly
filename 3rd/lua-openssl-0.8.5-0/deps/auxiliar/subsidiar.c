#include "auxiliar.h"
#include "subsidiar.h"

int auxiliar_enumerate(lua_State *L, int tidx, const LuaL_Enumeration *lenums)
{
  int n = tidx < 0 ? tidx-2 : tidx;
  const LuaL_Enumeration *e = lenums;
  while( e->name!=NULL ) 
  {
    lua_pushstring(L, e->name);
    lua_pushinteger(L, e->val);
    lua_rawset(L, n);
    e++;
  }
  return 1;
}

int auxiliar_checkoption(lua_State*L, int objidx, const char* def, const char* const slist[], const int ival[])
{
  int at = luaL_checkoption(L, objidx, def, slist);
  return ival[at];
}
