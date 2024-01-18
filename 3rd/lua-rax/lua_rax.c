#include <stdio.h>
#define LUA_LIB

#include <string.h>
#include <lua.h>
#include <lauxlib.h>
#include "rax.h"

static int
lrax_new(lua_State *L) {
    rax *r = raxNew();
    lua_pushlightuserdata(L, r);
    return 1;
}

static int
lrax_destroy(lua_State *L) {
    rax *r = (rax *)lua_touserdata(L, 1);
    if (r == NULL) {
        return 0;
    }

    raxFree(r);
    return 0;
}

static int
lrax_insert(lua_State *L) {
    rax *r = (rax *)lua_touserdata(L, 1);
    if (r == NULL) {
        return luaL_error(L, "tree is null.");
    }

    size_t len = 0;
    unsigned char *buf = (unsigned char *)lua_tolstring(L, 2, &len);
    if (buf == NULL) {
        return luaL_error(L, "buf is null.");
    }

    intptr_t idx = luaL_checkinteger(L, 3);

    int ret = raxInsert(r, buf, len, (void *)idx, NULL);
    lua_pushboolean(L, ret);
    return 1;
}

static int
lrax_find(lua_State *L) {
    rax *r = (rax *)lua_touserdata(L, 1);
    if (r == NULL) {
        return luaL_error(L, "tree is null.");
    }

    size_t len = 0;
    unsigned char *buf = (unsigned char *)lua_tolstring(L, 2, &len);
    if (buf == NULL) {
        return luaL_error(L, "buf is null.");
    }

    void *res = raxFind(r, buf, len);
    if (res == raxNotFound) {
        return 0;
    }
    intptr_t idx = (intptr_t)res;
    lua_pushinteger(L, idx);
    return 1;
}

static int
lrax_search(lua_State *L) {
    raxIterator *iter = (raxIterator *)lua_touserdata(L, 1);
    if (iter == NULL) {
        return luaL_error(L, "iter is null.");
    }

    size_t len = 0;
    unsigned char *buf = (unsigned char *)lua_tolstring(L, 2, &len);
    if (buf == NULL) {
        return luaL_error(L, "buf is null.");
    }

    int ret = raxSeek(iter, "<=", buf, len);
    lua_pushboolean(L, ret);
    return 1;
}

static int
lrax_prev(lua_State *L) {
    raxIterator *iter = (raxIterator *)lua_touserdata(L, 1);
    if (iter == NULL) {
        return luaL_error(L, "iter is null.");
    }

    size_t len = 0;
    unsigned char *buf = (unsigned char *)lua_tolstring(L, 2, &len);
    if (buf == NULL) {
        return luaL_error(L, "buf is null.");
    }

    int ret;
    while (1) {
        ret = raxPrev(iter);
        if (!ret) {
            lua_pushinteger(L, -1);
            return 1;
        }

        //fprintf(stderr, "it key len: %lu buf len: %lu, key: %.*s\n",
        //        iter->key_len, len, (int)iter->key_len, iter->key);
        if (iter->key_len > len || memcmp(buf, iter->key, iter->key_len) != 0) {
            continue;
        }

        break;
    }

    intptr_t idx = (intptr_t)iter->data;
    lua_pushinteger(L, idx);
    return 1;
}

static int
lrax_next(lua_State *L) {
    raxIterator *iter = (raxIterator *)lua_touserdata(L, 1);
    if (iter == NULL) {
        return luaL_error(L, "iter is null.");
    }

    size_t len = 0;
    unsigned char *buf = (unsigned char *)lua_tolstring(L, 2, &len);
    if (buf == NULL) {
        return luaL_error(L, "buf is null.");
    }

    int ret = raxNext(iter);
    if (!ret) {
        lua_pushinteger(L, -1);
        return 1;
    }

    if (iter->key_len > len || memcmp(buf, iter->key, iter->key_len != 0)) {
        lua_pushinteger(L, -1);
        return 1;
    }

    intptr_t idx = (intptr_t)iter->data;
    lua_pushinteger(L, idx);
    return 1;
}

static int
lrax_stop(lua_State *L) {
    raxIterator *iter = (raxIterator *)lua_touserdata(L, 1);
    if (iter == NULL) {
        return 0;
    }

    raxStop(iter);
    return 0;
}

static int
lrax_newit(lua_State *L) {
    rax *r = (rax *)lua_touserdata(L, 1);
    if (r == NULL) {
        return luaL_error(L, "tree is null.");
    }

    raxIterator *iter = (raxIterator *)lua_newuserdata(L, sizeof(raxIterator));
    if (iter == NULL) {
        return 0;
    }

    raxStart(iter, r);
    return 1;
}

static int
lrax_dump(lua_State *L) {
    rax *r = (rax *)lua_touserdata(L, 1);
    if (r == NULL) {
        return luaL_error(L, "tree is null.");
    }

    raxShow(r);
    return 0;
}

LUAMOD_API int
luaopen_rax_core(lua_State *L) {
    luaL_checkversion(L);
    luaL_Reg l[] = {
        { "new", lrax_new },
        { "destroy", lrax_destroy },
        { "insert", lrax_insert },
        { "find", lrax_find },
        { "search", lrax_search },
        { "prev", lrax_prev },
        { "next", lrax_next },
        { "stop", lrax_stop },
        { "newit", lrax_newit },
        { "dump", lrax_dump },
		{ NULL, NULL },
    };

    luaL_newlib(L, l);
    return 1;
}

