#define LUA_LIB

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"
#include "skynet_fly_env.h"

static int is_init = 0;

static int
command_getenv(lua_State *L) {
	if (!lua_isstring(L,1))
    {
        luaL_error(L,"arg_ment #%d err not string",1);
    }

    const char* param = lua_tostring(L,1);
	const char* result = skynet_fly_getenv(param);
	lua_pushstring(L,result);
	return 1;
}

static int
command_setenv(lua_State *L) {
	if (!lua_isstring(L,1))
    {
        luaL_error(L,"arg_ment #%d err not string",1);
    }
	if (!lua_isstring(L,2))
    {
        luaL_error(L,"arg_ment #%d err not string",2);
    }

	const char* key = lua_tostring(L,1);
	const char* value = lua_tostring(L,2);

	skynet_fly_setenv(key,value);
	return 0;
}

static int
command_resetenv(lua_State *L) {
	if (!lua_isstring(L,1))
    {
        luaL_error(L,"arg_ment #%d err not string",1);
    }
	if (!lua_isstring(L,2))
    {
        luaL_error(L,"arg_ment #%d err not string",2);
    }

	const char* key = lua_tostring(L,1);
	const char* value = lua_tostring(L,2);

	skynet_fly_resetenv(key,value);
	return 0;
}

static const struct luaL_Reg cmd[] =
{
    {"getenv",command_getenv},
	{"setenv",command_setenv},
    {"resetenv",command_resetenv},
    {NULL,NULL},
};

int luaopen_skynet_fly_env(lua_State *L)
{
	int old_val = __sync_val_compare_and_swap(&is_init,0,1);
	if (old_val == 0) {
		skynet_fly_env_init();
	}
    luaL_newlib(L,cmd);
    return 1;
}
