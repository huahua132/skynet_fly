#include "openssl.h"
#include "private.h"

#ifndef OPENSSL_NO_SRP
#include <openssl/srp.h>
#include <openssl/bn.h>

/* server side */
static int openssl_srp_create_verifier(lua_State *L)
{
  const SRP_gN *GN = CHECK_OBJECT(1, SRP_gN, "openssl.srp_gn");
  const char *username = luaL_checkstring(L, 2);
  const char *servpass = luaL_checkstring(L, 3);
  BIGNUM *salt = NULL, *verifier = NULL;
  int ret = SRP_create_verifier_BN(username, servpass, &salt, &verifier, GN->N, GN->g);
  if (ret==1)
  {
    PUSH_OBJECT(salt, "openssl.bn");
    PUSH_OBJECT(verifier, "openssl.bn");
    return 2;
  }
  return openssl_pushresult(L, ret);
}

#ifndef BN_RAND_TOP_ANY
#define BN_RAND_TOP_ANY -1
#endif
#ifndef BN_RAND_BOTTOM_ANY
#define BN_RAND_BOTTOM_ANY 0
#endif

static int openssl_srp_calc_b(lua_State *L)
{
  int ret = 0;
  const SRP_gN *GN = CHECK_OBJECT(1, SRP_gN, "openssl.srp_gn");
  BIGNUM *v = CHECK_OBJECT(2, BIGNUM, "openssl.bn");
  int bits = luaL_optint(L, 3, 32*8);

  BIGNUM *Brnd = NULL, *Bpub = NULL;
  Brnd = BN_new();

  ret = BN_rand(Brnd, bits, BN_RAND_TOP_ANY, BN_RAND_BOTTOM_ANY);
  if (ret==1)
  {
    /* Server's first message */
    Bpub = SRP_Calc_B(Brnd, GN->N, GN->g, v);
    ret = SRP_Verify_B_mod_N(Bpub, GN->N);
    if(ret==1)
    {
      PUSH_OBJECT(Bpub, "openssl.bn");
      PUSH_OBJECT(Brnd, "openssl.bn");
      ret = 2;
    }
  }
  if(ret!=2)
  {
    ret = openssl_pushresult(L, ret);
    if(Brnd) BN_free(Brnd);
    if(Bpub) BN_free(Bpub);
  }
  return ret;
}

static int openssl_srp_calc_server_key(lua_State *L)
{
  const SRP_gN *GN = CHECK_OBJECT(1, SRP_gN, "openssl.srp_gn");
  BIGNUM *Apub = CHECK_OBJECT(2, BIGNUM, "openssl.bn");
  BIGNUM *v = CHECK_OBJECT(3, BIGNUM, "openssl.bn");
  BIGNUM *u = CHECK_OBJECT(4, BIGNUM, "openssl.bn");
  BIGNUM *Brnd = CHECK_OBJECT(5, BIGNUM, "openssl.bn");

  /* Server's key */
  BIGNUM *Kserver = SRP_Calc_server_key(Apub, v, u, Brnd, GN->N);
  PUSH_OBJECT(Kserver, "openssl.bn");
  return 1;
}

/* client side */
static int openssl_srp_calc_a(lua_State *L)
{
  int ret = 0;
  const SRP_gN *GN = CHECK_OBJECT(1, SRP_gN, "openssl.srp_gn");
  int bits = luaL_optint(L, 3, 32*8);

  BIGNUM *Arnd = NULL, *Apub = NULL;
  Arnd = BN_new();

  ret = BN_rand(Arnd, bits, BN_RAND_TOP_ANY, BN_RAND_BOTTOM_ANY);
  if (ret==1)
  {
    /* Client's response */
    Apub = SRP_Calc_A(Arnd, GN->N, GN->g);
    ret = SRP_Verify_A_mod_N(Apub, GN->N);
    if(ret==1)
    {
      PUSH_OBJECT(Apub, "openssl.bn");
      PUSH_OBJECT(Arnd, "openssl.bn");
      ret = 2;
    }
  }
  if(ret!=2)
  {
    ret = openssl_pushresult(L, ret);
    if(Arnd) BN_free(Arnd);
    if(Apub) BN_free(Apub);
  }
  return ret;
}

static int openssl_srp_calc_x(lua_State *L)
{
  BIGNUM *s = CHECK_OBJECT(1, BIGNUM, "openssl.bn");
  const char *username = luaL_checkstring(L, 2);
  const char *password = luaL_checkstring(L, 3);

  BIGNUM *x = SRP_Calc_x(s, username, password);
  PUSH_OBJECT(x, "openssl.bn");
  return 1;
}

static int openssl_srp_calc_client_key(lua_State *L)
{
  const SRP_gN *GN = CHECK_OBJECT(1, SRP_gN, "openssl.srp_gn");
  BIGNUM *Bpub = CHECK_OBJECT(2, BIGNUM, "openssl.bn");
  BIGNUM *x = CHECK_OBJECT(3, BIGNUM, "openssl.bn");
  BIGNUM *Arnd = CHECK_OBJECT(4, BIGNUM, "openssl.bn");
  BIGNUM *u = CHECK_OBJECT(5, BIGNUM, "openssl.bn");

  /* Client's key */
  BIGNUM *Kclient = SRP_Calc_client_key(GN->N, Bpub, GN->g, x, Arnd, u);
  PUSH_OBJECT(Kclient, "openssl.bn");
  return 1;
}

/* both side */
static int openssl_srp_get_default_gN(lua_State *L)
{
  const char *id = luaL_checkstring(L, 1);
  SRP_gN *GN = SRP_get_default_gN(id);
  if(GN)
    PUSH_OBJECT(GN, "openssl.srp_gn");
  else
    lua_pushnil(L);
  return 1;
}

static int openssl_srp_calc_u(lua_State *L)
{
  const SRP_gN *GN = CHECK_OBJECT(1, SRP_gN, "openssl.srp_gn");
  BIGNUM *Apub = CHECK_OBJECT(2, BIGNUM, "openssl.bn");
  BIGNUM *Bpub = CHECK_OBJECT(3, BIGNUM, "openssl.bn");

  /* Both sides calculate u */
  BIGNUM *u = SRP_Calc_u(Apub, Bpub, GN->N);
  PUSH_OBJECT(u, "openssl.bn");
  return 1;
}

static luaL_Reg srp_funs[] =
{
  /* both side */
  {"calc_u",          openssl_srp_calc_u},

  /* client side */
  {"calc_a",          openssl_srp_calc_a},
  {"calc_x",          openssl_srp_calc_x},
  {"calc_client_key", openssl_srp_calc_client_key},

  /* server side */
  {"calc_b",          openssl_srp_calc_b},
  {"create_verifier", openssl_srp_create_verifier},
  {"calc_server_key", openssl_srp_calc_server_key},

  /* prototype */
  {"__tostring",      auxiliar_tostring},

  {NULL,  NULL }
};

static luaL_Reg R[] =
{
  {"get_default_gN",  openssl_srp_get_default_gN},

  {NULL,  NULL}
};

int luaopen_srp(lua_State *L)
{
  auxiliar_newclass(L, "openssl.srp_gn",       srp_funs);

  lua_newtable(L);
  luaL_setfuncs(L, R, 0);

  return 1;
}
#endif
