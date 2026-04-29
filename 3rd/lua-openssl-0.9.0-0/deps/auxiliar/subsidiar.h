#ifndef SUBSIDIAR_H
#define SUBSIDIAR_H

#include "lua.h"
#include "lauxlib.h"

/* subsidiary part for auxiliar libirary */

#define AUXILIAR_SET(L, tidx, lvar, cval, ltype)    \
  do {                                              \
  int n = tidx < 0 ? tidx-1 : tidx;                 \
  lua_push##ltype(L, (cval));                       \
  lua_setfield(L, n, lvar);                         \
  } while(0)

#define AUXLIAR_GET(L, tidx, lvar, cvar, ltype)     \
  do {                                              \
  lua_getfield(L, tidx, lvar);                      \
  cvar = lua_to##ltype(L, -1);                      \
  lua_pop(L, 1);                                    \
  } while(0)

#define AUXILIAR_SETLSTR(L, tidx, lvar, cval, len)  \
  do {                                              \
  int n = tidx < 0 ? tidx-1 : tidx;                 \
  lua_pushlstring(L, (const char*)(cval),len);      \
  lua_setfield(L, n, lvar);                         \
  } while(0)

#define AUXILIAR_GETLSTR(L, tidx, lvar, cvar, len)  \
  do {                                              \
  lua_getfield(L, tidx, lvar);                      \
  cvar = lua_tolstring(L, -1, &len);                \
  lua_setfield(L, n, lvar);                         \
  } while(0)

typedef struct
{
  const char* name;
  int val;
} LuaL_Enumeration;

int auxiliar_enumerate(lua_State *L, int tidx, const LuaL_Enumeration *lenum);
int auxiliar_checkoption(lua_State*L, 
                         int objidx,
                         const char *def, 
                         const char *const slist[],
                         const int ival[]);

#endif

