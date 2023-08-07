/***
big-number library for Lua 5.1 based on OpenSSL bn

@module bn
@author Luiz Henrique de Figueiredo <lhf@tecgraf.puc-rio.br>
@license This code is hereby placed in the public domain.
@warning verson 11 Nov 2010 22:56:45
*/

#include <stdlib.h>

#include <openssl/bn.h>
#include <openssl/crypto.h>
#include <openssl/err.h>
#include <openssl/rand.h>
#if OPENSSL_VERSION_NUMBER < 0x10100000L
#define BN_is_negative(a) ((a)->neg != 0)
#endif

#include "lua.h"
#include "lauxlib.h"
#include "lualib.h"

#include "private.h"
#if (OPENSSL_VERSION_NUMBER >= 0x30000000L)
#define SHLIB_VERSION_NUMBER OPENSSL_VERSION_STR
#endif
#define MYNAME    "bn"
#define MYVERSION MYNAME " library for " LUA_VERSION " / Nov 2010 / "\
      "based on OpenSSL " SHLIB_VERSION_NUMBER
#define MYTYPE    "openssl.bn"

static void error(lua_State *L, const char *message)
{
  luaL_error(L, "(bn) %s %s", message, ERR_reason_error_string(ERR_get_error()));
}

static BIGNUM *Bnew(lua_State *L)
{
  BIGNUM *x = BN_new();
  if (x == NULL) error(L, "BN_new failed");
  PUSH_BN(x);
  return x;
}

static BIGNUM *Bget(lua_State *L, int i)
{
  switch (lua_type(L, i))
  {
  case LUA_TNUMBER:
  case LUA_TSTRING:
  {
    BIGNUM *x = Bnew(L);
    const char *s = lua_tostring(L, i);
    if (s[0] == 'X' || s[0] == 'x') BN_hex2bn(&x, s + 1);
    else BN_dec2bn(&x, s);
    lua_replace(L, i);
    return x;
  }
  default:
    return *((void**)luaL_checkudata(L, i, MYTYPE));
  }
}

static int Bbits(lua_State *L)      /** bits(x) */
{
  BIGNUM *a = Bget(L, 1);
  lua_pushinteger(L, BN_num_bits(a));
  return 1;
}

static int Btostring(lua_State *L)    /** tostring(x) */
{
  BIGNUM *a = Bget(L, 1);
  char *s = BN_bn2dec(a);
  lua_pushstring(L, s);
  OPENSSL_free(s);
  return 1;
}

static int Btohex(lua_State *L)     /** tohex(x) */
{
  BIGNUM *a = Bget(L, 1);
  char *s = BN_bn2hex(a);
  lua_pushstring(L, s);
  OPENSSL_free(s);
  return 1;
}

static int Btotext(lua_State *L)    /** totext(x) */
{
  BIGNUM *a = Bget(L, 1);
  int n = BN_num_bytes(a);
  void *s = malloc(n);
  if (s == NULL) return 0;
  BN_bn2bin(a, s);
  lua_pushlstring(L, s, n);
  free(s);
  return 1;
}

static int Btonumber(lua_State *L)    /** tonumber(x) */
{
  Btostring(L);
  lua_pushnumber(L, lua_tonumber(L, -1));
  return 1;
}

static int Biszero(lua_State *L)    /** iszero(x) */
{
  BIGNUM *a = Bget(L, 1);
  lua_pushboolean(L, BN_is_zero(a));
  return 1;
}

static int Bisone(lua_State *L)     /** isone(x) */
{
  BIGNUM *a = Bget(L, 1);
  lua_pushboolean(L, BN_is_one(a));
  return 1;
}

static int Bisodd(lua_State *L)     /** isodd(x) */
{
  BIGNUM *a = Bget(L, 1);
  lua_pushboolean(L, BN_is_odd(a));
  return 1;
}

static int Bisneg(lua_State *L)     /** isneg(x) */
{
  BIGNUM *a = Bget(L, 1);
  lua_pushboolean(L, BN_is_negative(a));
  return 1;
}

static int Bnumber(lua_State *L)    /** number(x) */
{
  Bget(L, 1);
  lua_settop(L, 1);
  return 1;
}

static int Btext(lua_State *L)      /** text(t) */
{
  size_t l;
  const char *s = luaL_checklstring(L, 1, &l);
  BIGNUM *x = Bnew(L);
  BN_bin2bn((const unsigned char *)s, l, x);
  return 1;
}

static int Bcompare(lua_State *L)   /** compare(x,y) */
{
  BIGNUM *a = Bget(L, 1);
  BIGNUM *b = Bget(L, 2);
  lua_pushinteger(L, BN_cmp(a, b));
  return 1;
}

static int Beq(lua_State *L)
{
  BIGNUM *a = Bget(L, 1);
  BIGNUM *b = Bget(L, 2);
  lua_pushboolean(L, BN_cmp(a, b) == 0);
  return 1;
}

static int Blt(lua_State *L)
{
  BIGNUM *a = Bget(L, 1);
  BIGNUM *b = Bget(L, 2);
  lua_pushboolean(L, BN_cmp(a, b) < 0);
  return 1;
}

static int Bsqr(lua_State *L)     /** sqr(x) */
{
  BIGNUM *a = Bget(L, 1);
  BIGNUM *c = Bnew(L);
  BN_CTX *ctx = BN_CTX_new();
  BN_sqr(c, a, ctx);
  BN_CTX_free(ctx);
  return 1;
}

static int Bneg(lua_State *L)     /** neg(x) */
{
  BIGNUM *a = BN_new();
  BIGNUM *b = Bget(L, 1);
  BIGNUM *c = Bnew(L);
  BN_set_word(a, 0);
  BN_sub(c, a, b);
  BN_free(a);
  return 1;
}

static int Babs(lua_State *L)     /** abs(x) */
{
  BIGNUM *b = Bget(L, 1);
  if (BN_is_negative(b))
  {
    BIGNUM *a = BN_new();
    BIGNUM *c = Bnew(L);
    BN_set_word(a, 0);
    BN_sub(c, a, b);
    BN_free(a);
  }
  else lua_settop(L, 1);
  return 1;
}

static int Badd(lua_State *L)     /** add(x,y) */
{
  BIGNUM *a = Bget(L, 1);
  BIGNUM *b = Bget(L, 2);
  BIGNUM *c = Bnew(L);
  BN_add(c, a, b);
  return 1;
}

static int Bsub(lua_State *L)     /** sub(x,y) */
{
  BIGNUM *a = Bget(L, 1);
  BIGNUM *b = Bget(L, 2);
  BIGNUM *c = Bnew(L);
  BN_sub(c, a, b);
  return 1;
}

static int Bmul(lua_State *L)     /** mul(x,y) */
{
  BIGNUM *a = Bget(L, 1);
  BIGNUM *b = Bget(L, 2);
  BIGNUM *c = Bnew(L);
  BN_CTX *ctx = BN_CTX_new();
  BN_mul(c, a, b, ctx);
  BN_CTX_free(ctx);
  return 1;
}

static int Bdiv(lua_State *L)     /** div(x,y) */
{
  BIGNUM *a = Bget(L, 1);
  BIGNUM *b = Bget(L, 2);
  BIGNUM *q = Bnew(L);
  BIGNUM *r = NULL;
  BN_CTX *ctx = BN_CTX_new();
  BN_div(q, r, a, b, ctx);
  BN_CTX_free(ctx);
  return 1;
}

static int Bmod(lua_State *L)     /** mod(x,y) */
{
  BIGNUM *a = Bget(L, 1);
  BIGNUM *b = Bget(L, 2);
  BIGNUM *q = NULL;
  BIGNUM *r = Bnew(L);
  BN_CTX *ctx = BN_CTX_new();
  BN_div(q, r, a, b, ctx);
  BN_CTX_free(ctx);
  return 1;
}

static int Brmod(lua_State *L)      /** rmod(x,y) */
{
  BIGNUM *a = Bget(L, 1);
  BIGNUM *b = Bget(L, 2);
  BIGNUM *r = Bnew(L);
  BN_CTX *ctx = BN_CTX_new();
  BN_nnmod(r, a, b, ctx);
  BN_CTX_free(ctx);
  return 1;
}

static int Bdivmod(lua_State *L)    /** divmod(x,y) */
{
  BIGNUM *a = Bget(L, 1);
  BIGNUM *b = Bget(L, 2);
  BIGNUM *q = Bnew(L);
  BIGNUM *r = Bnew(L);
  BN_CTX *ctx = BN_CTX_new();
  BN_div(q, r, a, b, ctx);
  BN_CTX_free(ctx);
  return 2;
}

static int Bgcd(lua_State *L)     /** gcd(x,y) */
{
  BIGNUM *a = Bget(L, 1);
  BIGNUM *b = Bget(L, 2);
  BIGNUM *c = Bnew(L);
  BN_CTX *ctx = BN_CTX_new();
  BN_gcd(c, a, b, ctx);
  BN_CTX_free(ctx);
  return 1;
}

static int Bpow(lua_State *L)     /** pow(x,y) */
{
  BIGNUM *a = Bget(L, 1);
  BIGNUM *b = Bget(L, 2);
  BIGNUM *c = Bnew(L);
  BN_CTX *ctx = BN_CTX_new();
  BN_exp(c, a, b, ctx);
  BN_CTX_free(ctx);
  return 1;
}

static int Baddmod(lua_State *L)    /** addmod(x,y,m) */
{
  BIGNUM *a = Bget(L, 1);
  BIGNUM *b = Bget(L, 2);
  BIGNUM *m = Bget(L, 3);
  BIGNUM *c = Bnew(L);
  BN_CTX *ctx = BN_CTX_new();
  BN_mod_add(c, a, b, m, ctx);
  BN_CTX_free(ctx);
  return 1;
}

static int Bsubmod(lua_State *L)    /** submod(x,y,m) */
{
  BIGNUM *a = Bget(L, 1);
  BIGNUM *b = Bget(L, 2);
  BIGNUM *m = Bget(L, 3);
  BIGNUM *c = Bnew(L);
  BN_CTX *ctx = BN_CTX_new();
  BN_mod_sub(c, a, b, m, ctx);
  BN_CTX_free(ctx);
  return 1;
}

static int Bmulmod(lua_State *L)    /** mulmod(x,y,m) */
{
  BIGNUM *a = Bget(L, 1);
  BIGNUM *b = Bget(L, 2);
  BIGNUM *m = Bget(L, 3);
  BIGNUM *c = Bnew(L);
  BN_CTX *ctx = BN_CTX_new();
  BN_mod_mul(c, a, b, m, ctx);
  BN_CTX_free(ctx);
  return 1;
}

static int Bpowmod(lua_State *L)    /** powmod(x,y,m) */
{
  BIGNUM *a = Bget(L, 1);
  BIGNUM *b = Bget(L, 2);
  BIGNUM *m = Bget(L, 3);
  BIGNUM *c = Bnew(L);
  BN_CTX *ctx = BN_CTX_new();
  BN_mod_exp(c, a, b, m, ctx);
  BN_CTX_free(ctx);
  return 1;
}

static int Bsqrmod(lua_State *L)    /** sqrmod(x) */
{
  BIGNUM *a = Bget(L, 1);
  BIGNUM *m = Bget(L, 2);
  BIGNUM *c = Bnew(L);
  BN_CTX *ctx = BN_CTX_new();
  BN_mod_sqr(c, a, m, ctx);
  BN_CTX_free(ctx);
  return 1;
}

static int Binvmod(lua_State *L)    /** invmod(x) */
{
  BIGNUM *a = Bget(L, 1);
  BIGNUM *m = Bget(L, 2);
  BIGNUM *c = Bnew(L);
  BN_CTX *ctx = BN_CTX_new();
  BN_mod_inverse(c, a, m, ctx);
  BN_CTX_free(ctx);
  return 1;
}

static int Bsqrtmod(lua_State *L)   /** sqrtmod(x) */
{
  BIGNUM *a = Bget(L, 1);
  BIGNUM *m = Bget(L, 2);
  BIGNUM *c = Bnew(L);
  BN_CTX *ctx = BN_CTX_new();
  BN_mod_sqrt(c, a, m, ctx);
  BN_CTX_free(ctx);
  return 1;
}

static int Brandom(lua_State *L)    /** random(bits) */
{
  int bits = luaL_optint(L, 1, 32);
  BIGNUM *x = Bnew(L);
  BN_rand(x, bits, -1, 0);
  return 1;
}

static int Baprime(lua_State *L)    /** aprime(bits) */
{
  int bits = luaL_optint(L, 1, 32);
  BIGNUM *x = Bnew(L);
  if (BN_generate_prime_ex(x, bits, 0, NULL, NULL, NULL))
    return 1;
  else
    lua_pop(L, 1);
  return 0;
}

static int Bisprime(lua_State *L)   /** isprime(x,[checks]) */
{
  BIGNUM *a = Bget(L, 1);
  BN_CTX *ctx = BN_CTX_new();
#if (OPENSSL_VERSION_NUMBER >= 0x30000000L)
  BN_GENCB *cb = BN_GENCB_new();
  lua_pushboolean(L, BN_check_prime(a, ctx, cb));
  BN_GENCB_free(cb);
#else
  int checks = luaL_optint(L, 2, BN_prime_checks);
  lua_pushboolean(L, BN_is_prime_fasttest_ex(a, checks, ctx, 1, NULL));
#endif
  BN_CTX_free(ctx);
  return 1;
}

static int Bgc(lua_State *L)
{
  BIGNUM *a = Bget(L, 1);
  BN_free(a);
  return 0;
}

static const luaL_Reg R[] =
{
  { "__add",  Badd  },    /** __add(x,y) */
  { "__div",  Bdiv  },    /** __div(x,y) */
  { "__eq", Beq },    /** __eq(x,y) */
  { "__gc", Bgc },
  { "__lt", Blt },    /** __lt(x,y) */
  { "__mod",  Bmod  },    /** __mod(x,y) */
  { "__mul",  Bmul  },    /** __mul(x,y) */
  { "__pow",  Bpow  },    /** __pow(x,y) */
  { "__sub",  Bsub  },    /** __sub(x,y) */
  { "__tostring", Btostring},   /** __tostring(x) */
  { "__unm",  Bneg  },    /** __unm(x) */
  { "abs",  Babs  },
  { "add",  Badd  },
  { "addmod", Baddmod },
  { "aprime", Baprime },
  { "bits", Bbits },
  { "compare",  Bcompare},
  { "div",  Bdiv  },
  { "divmod", Bdivmod },
  { "gcd",  Bgcd  },
  { "invmod", Binvmod },
  { "isneg",  Bisneg  },
  { "isodd",  Bisodd  },
  { "isone",  Bisone  },
  { "isprime",  Bisprime},
  { "iszero", Biszero },
  { "mod",  Bmod  },
  { "mul",  Bmul  },
  { "mulmod", Bmulmod },
  { "neg",  Bneg  },
  { "number", Bnumber },
  { "pow",  Bpow  },
  { "powmod", Bpowmod },
  { "random", Brandom },
  { "rmod", Brmod },
  { "sqr",  Bsqr  },
  { "sqrmod", Bsqrmod },
  { "sqrtmod",  Bsqrtmod},
  { "sub",  Bsub  },
  { "submod", Bsubmod },
  { "text", Btext },
  { "tohex",  Btohex  },
  { "totext", Btotext },
  { "tonumber", Btonumber},
  { "tostring", Btostring},
  { NULL,   NULL  }
};

int luaopen_bn(lua_State *L)
{
#if OPENSSL_VERSION_NUMBER < 0x30000000
  ERR_load_BN_strings();
#endif
  RAND_seed(MYVERSION, sizeof(MYVERSION));

  luaL_newmetatable(L, MYTYPE);
  luaL_setfuncs(L, R, 0);
  lua_pushliteral(L, "version");     /** version */
  lua_pushliteral(L, MYVERSION);
  lua_settable(L, -3);
  lua_pushliteral(L, "__index");
  lua_pushvalue(L, -2);
  lua_settable(L, -3);

  return 1;
}
