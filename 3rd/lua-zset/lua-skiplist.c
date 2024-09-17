/*
 *  author: xjdrew
 *  date: 2014-06-03 20:38
 */

#include <stdio.h>
#include <stdlib.h>

#include "lua.h"
#include "lauxlib.h"
#include "skiplist.h"

static inline skiplist*
_to_skiplist(lua_State *L) {
    skiplist **sl = lua_touserdata(L, 1);
    if(sl==NULL) {
        luaL_error(L, "must be skiplist object");
    }
    return *sl;
}

static int
_insert(lua_State *L) {
    skiplist *sl = _to_skiplist(L);
    double score = luaL_checknumber(L, 2);
    luaL_checktype(L, 3, LUA_TSTRING);
    size_t len;
    const char* ptr = lua_tolstring(L, 3, &len);
    slobj *obj = slCreateObj(ptr, len);
    slInsert(sl, score, obj);
    return 0;
}

static int
_delete(lua_State *L) {
    skiplist *sl = _to_skiplist(L);
    double score = luaL_checknumber(L, 2);
    luaL_checktype(L, 3, LUA_TSTRING);
    slobj obj;
    obj.ptr = (char *)lua_tolstring(L, 3, &obj.length);
    lua_pushboolean(L, slDelete(sl, score, &obj));
    return 1;
}

static void
_delete_rank_cb(void* ud, slobj *obj) {
    lua_State *L = (lua_State*)ud;
    lua_pushvalue(L, 4);
    lua_pushlstring(L, obj->ptr, obj->length);
    lua_call(L, 1, 0);
}

static int
_delete_by_rank(lua_State *L) {
    skiplist *sl = _to_skiplist(L);
    unsigned int start = luaL_checkinteger(L, 2);
    unsigned int end = luaL_checkinteger(L, 3);
    luaL_checktype(L, 4, LUA_TFUNCTION);
    if (start > end) {
        unsigned int tmp = start;
        start = end;
        end = tmp;
    }

    lua_pushinteger(L, slDeleteByRank(sl, start, end, _delete_rank_cb, L));
    return 1;
}

static int
_get_count(lua_State *L) {
    skiplist *sl = _to_skiplist(L);
    lua_pushinteger(L, sl->length);
    return 1;
}

static int
_get_rank(lua_State *L) {
    skiplist *sl = _to_skiplist(L);
    double score = luaL_checknumber(L, 2);
    luaL_checktype(L, 3, LUA_TSTRING);
    slobj obj;
    obj.ptr = (char *)lua_tolstring(L, 3, &obj.length);

    unsigned long rank = slGetRank(sl, score, &obj);
    if(rank == 0) {
        return 0;
    }

    lua_pushinteger(L, rank);

    return 1;
}

static int
_get_rank_range(lua_State *L) {
    skiplist *sl = _to_skiplist(L);
    unsigned long r1 = luaL_checkinteger(L, 2);
    unsigned long r2 = luaL_checkinteger(L, 3);
    int reverse, rangelen;
    if(r1 <= r2) {
        reverse = 0;
        rangelen = r2 - r1 + 1;
    } else {
        reverse = 1;
        rangelen = r1 - r2 + 1;
    }

    skiplistNode* node = slGetNodeByRank(sl, r1);
    lua_createtable(L, rangelen, 0);
    int n = 0;
    while(node && n < rangelen) {
        n++;

        lua_pushlstring(L, node->obj->ptr, node->obj->length);
        lua_rawseti(L, -2, n);
        node = reverse? node->backward : node->level[0].forward;
    } 
    return 1;
}

static int
_get_score_range(lua_State *L) {
    skiplist *sl = _to_skiplist(L);
    double s1 = luaL_checknumber(L, 2);
    double s2 = luaL_checknumber(L, 3);
    int reverse; 
    skiplistNode *node;

    if(s1 <= s2) {
        reverse = 0;
        node = slFirstInRange(sl, s1, s2);
    } else {
        reverse = 1;
        node = slLastInRange(sl, s2, s1);
    }

    lua_newtable(L);
    int n = 0;
    while(node) {
        if(reverse) {
            if(node->score < s2) break;
        } else {
            if(node->score > s2) break;
        }
        n++;

        lua_pushlstring(L, node->obj->ptr, node->obj->length);
        lua_rawseti(L, -2, n);

        node = reverse? node->backward:node->level[0].forward;
    }
    return 1;
}

static int
_get_member_by_rank(lua_State *L){
    skiplist *sl = _to_skiplist(L);
    unsigned long r = luaL_checkinteger(L, 2);
    skiplistNode *node = slGetNodeByRank(sl, r);
    if (node) {
        lua_pushlstring(L, node->obj->ptr, node->obj->length);
        return 1;
    }
    return 0;
}

static int
_dump(lua_State *L) {
    skiplist *sl = _to_skiplist(L);
    slDump(sl);
    return 0;
}

static int
_new(lua_State *L) {
    skiplist *psl = slCreate();

    skiplist **sl = (skiplist**) lua_newuserdata(L, sizeof(skiplist*));
    *sl = psl;
    lua_pushvalue(L, lua_upvalueindex(1));
    lua_setmetatable(L, -2);
    return 1;
}

static int
_release(lua_State *L) {
    skiplist *sl = _to_skiplist(L);
    printf("collect sl:%p\n", sl);
    slFree(sl);
    return 0;
}

int luaopen_skiplist_c(lua_State *L) {
#if defined(LUA_VERSION_NUM) && LUA_VERSION_NUM > 501
    luaL_checkversion(L);
#endif

    luaL_Reg l[] = {
        {"insert", _insert},
        {"delete", _delete},
        {"delete_by_rank", _delete_by_rank},

        {"get_count", _get_count},
        {"get_rank", _get_rank},
        {"get_rank_range", _get_rank_range},
        {"get_score_range", _get_score_range},
        {"get_member_by_rank", _get_member_by_rank},

        {"dump", _dump},
        {NULL, NULL}
    };

    lua_createtable(L, 0, 2);

    luaL_newlib(L, l);
    lua_setfield(L, -2, "__index");
    lua_pushcfunction(L, _release);
    lua_setfield(L, -2, "__gc");

    lua_pushcclosure(L, _new, 1);
    return 1;
}

