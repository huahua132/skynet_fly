/*
STACK\_OF(CTYPE) object just like STACK\_OF(X509) are high frequency used,
in x509, pkcs7, pkcs12 and others module, and it has complex APIs in openssl.

In lua-openssl, all of STACK\_OF(CTYPE) C side objects are mapping to array
actually table in Lua side, and follow the rules of the Lua array, start
index from 1, not 0 in C world.

E.g C side STACK\_OF(X509) and Lua side array {cert1,cert2,...,certn} can
be automatic convert in lua\-openssl if need.
*/

#include "openssl.h"

#ifdef CRYPTO_LOCK_REF
#if OPENSSL_VERSION_NUMBER < 0x10100000L
#define REF_OR_DUP(TYPE, x)  CRYPTO_add(&x->references,1,CRYPTO_LOCK_##TYPE)
#else
#define REF_OR_DUP(TYPE, x)  TYPE##_up_ref(x)
#endif
#else
#define REF_OR_DUP(TYPE, x) x = TYPE##_dup(x)
#endif

#if OPENSSL_VERSION_NUMBER < 0x10100000L
#define TAB2SK(TYPE, type)                                        \
STACK_OF(TYPE)* openssl_sk_##type##_fromtable(lua_State*L, int idx) {     \
  STACK_OF(TYPE) * sk;                                            \
  luaL_argcheck(L, lua_istable(L, idx),  idx,                     \
         "must be a table as array or nil");                      \
  sk = SKM_sk_new_null(TYPE);                                     \
  if (lua_istable(L,idx)) {                                       \
    int n = lua_rawlen(L, idx);                                   \
    int i;                                                        \
    for ( i=0; i<n; i++ ) {                                       \
      TYPE *x;                                                    \
      lua_rawgeti(L, idx, i+1);                                   \
      x = CHECK_OBJECT(-1,TYPE,"openssl." #type);                 \
      REF_OR_DUP(TYPE, x);                                        \
      SKM_sk_push(TYPE, sk, x);                                   \
      lua_pop(L,1);                                               \
    }                                                             \
  }                                                               \
  return sk;                                                      \
}


#define SK2TAB(TYPE,type)  int openssl_sk_##type##_totable(lua_State* L,const STACK_OF(TYPE) *sk)  {  \
  int i=0, n=0;                                                                           \
  lua_newtable(L);                                                                        \
  n = SKM_sk_num(TYPE, sk);                                                               \
  for(i=0;i<n;i++) {                                                                      \
    TYPE *x =  SKM_sk_value(TYPE, sk, i);                                                 \
    REF_OR_DUP(TYPE, x);                                                                  \
    PUSH_OBJECT(x,"openssl."#type);                                                       \
    lua_rawseti(L,-2, i+1);                                                               \
  }                                                                                       \
  return 1;                                                                               \
}
#else
#define TAB2SK(TYPE, type)                                        \
STACK_OF(TYPE)* openssl_sk_##type##_fromtable(lua_State*L, int idx) {     \
  STACK_OF(TYPE) * sk;                                            \
  luaL_argcheck(L, lua_istable(L, idx),  idx,                     \
         "must be a table as array or nil");                      \
  sk = sk_##TYPE##_new_null();                                    \
  if (lua_istable(L,idx)) {                                       \
    int n = lua_rawlen(L, idx);                                   \
    int i;                                                        \
    for ( i=0; i<n; i++ ) {                                       \
      TYPE *x;                                                    \
      lua_rawgeti(L, idx, i+1);                                   \
      x = CHECK_OBJECT(-1,TYPE,"openssl." #type);                 \
      REF_OR_DUP(TYPE, x);                                        \
      sk_##TYPE##_push(sk, x);                                    \
      lua_pop(L,1);                                               \
    }                                                             \
  }                                                               \
  return sk;                                                      \
}


#define SK2TAB(TYPE,type)  int openssl_sk_##type##_totable(lua_State* L, const STACK_OF(TYPE) *sk)  {  \
  int i=0, n=0;                                                                           \
  lua_newtable(L);                                                                        \
  n = sk_##TYPE##_num(sk);                                                                \
  for(i=0;i<n;i++) {                                                                      \
    TYPE *x =  sk_##TYPE##_value(sk, i);                                                  \
    REF_OR_DUP(TYPE, x);                                                                  \
    PUSH_OBJECT(x,"openssl."#type);                                                       \
    lua_rawseti(L,-2, i+1);                                                               \
  }                                                                                       \
  return 1;                                                                               \
}
#endif

#define IMP_LUA_SK(TYPE,type)   \
TAB2SK(TYPE,type);              \
SK2TAB(TYPE,type)
