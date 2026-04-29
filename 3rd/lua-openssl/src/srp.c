/***
srp module to handle secure remote password.
Provide srp_gn as lua object.

@module srp
@usage
  srp = require('openssl').srp
*/
#include "openssl.h"
#include "private.h"

#ifndef OPENSSL_NO_SRP
#include <openssl/bn.h>
#include <openssl/srp.h>

/* Suppress deprecation warnings for SRP functions in OpenSSL 3.0+
 * The SRP module is marked deprecated but remains functional.
 * We continue to use it to maintain backward compatibility. */
#if defined(__GNUC__) || defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
#endif

/***
Gets the default SRP_gN object.
@function get_default_gN
@tparam string id SRP_gN ID
@treturn openssl.srp_gn GN SRP_gN object
*/
static int
openssl_srp_get_default_gN(lua_State *L)
{
  const char *id = luaL_checkstring(L, 1);
  SRP_gN     *GN = SRP_get_default_gN(id);
  if (GN)
    PUSH_OBJECT(GN, "openssl.srp_gn");
  else
    lua_pushnil(L);
  return 1;
}

/***
Calculates the x value.
@function calc_x
@tparam openssl.bn s Salt
@tparam string username Username
@tparam string password Password
@treturn openssl.bn x Value
*/
static int
openssl_srp_calc_x(lua_State *L)
{
  BIGNUM     *s = CHECK_OBJECT(1, BIGNUM, "openssl.bn");
  const char *username = luaL_checkstring(L, 2);
  const char *password = luaL_checkstring(L, 3);

  BIGNUM *x = SRP_Calc_x(s, username, password);
  PUSH_OBJECT(x, "openssl.bn");
  return 1;
}

/***
openssl.srp_gn class.
@type srp_gn
*/

/***
Creates an SRP verifier.
@function create_verifier
@tparam string username Username
@tparam string servpass Service password
@treturn openssl.bn salt Salt
@treturn openssl.bn verifier Verifier
*/
static int
openssl_srp_create_verifier(lua_State *L)
{
  const SRP_gN *GN = CHECK_OBJECT(1, SRP_gN, "openssl.srp_gn");
  const char   *username = luaL_checkstring(L, 2);
  const char   *servpass = luaL_checkstring(L, 3);
  BIGNUM       *salt = NULL, *verifier = NULL;
  int           ret = SRP_create_verifier_BN(username, servpass, &salt, &verifier, GN->N, GN->g);
  if (ret == 1) {
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

/***
Calculates the server's B value.
@function calc_b
@tparam openssl.bn v Verifier
@tparam[opt] int bits Number of random bits, default is 256
@treturn openssl.bn Bpub Server public key
@treturn openssl.bn Brnd Server random number
*/
static int
openssl_srp_calc_b(lua_State *L)
{
  int           ret = 0;
  const SRP_gN *GN = CHECK_OBJECT(1, SRP_gN, "openssl.srp_gn");
  BIGNUM       *v = CHECK_OBJECT(2, BIGNUM, "openssl.bn");
  int           bits = luaL_optint(L, 3, 32 * 8);

  BIGNUM *Brnd = NULL, *Bpub = NULL;
  Brnd = BN_new();

  ret = BN_rand(Brnd, bits, BN_RAND_TOP_ANY, BN_RAND_BOTTOM_ANY);
  if (ret == 1) {
    /* Server's first message */
    Bpub = SRP_Calc_B(Brnd, GN->N, GN->g, v);
    ret = SRP_Verify_B_mod_N(Bpub, GN->N);
    if (ret == 1) {
      PUSH_OBJECT(Bpub, "openssl.bn");
      PUSH_OBJECT(Brnd, "openssl.bn");
      ret = 2;
    }
  }
  if (ret != 2) {
    ret = openssl_pushresult(L, ret);
    if (Brnd) BN_free(Brnd);
    if (Bpub) BN_free(Bpub);
  }
  return ret;
}

/***
Calculates the server's key.
@function calc_server_key
@tparam openssl.bn Apub Client public key
@tparam openssl.bn v Verifier
@tparam openssl.bn u Random number u
@tparam openssl.bn Brnd Server random number
@treturn openssl.bn Kserver Server key
*/
static int
openssl_srp_calc_server_key(lua_State *L)
{
  const SRP_gN *GN = CHECK_OBJECT(1, SRP_gN, "openssl.srp_gn");
  BIGNUM       *Apub = CHECK_OBJECT(2, BIGNUM, "openssl.bn");
  BIGNUM       *v = CHECK_OBJECT(3, BIGNUM, "openssl.bn");
  BIGNUM       *u = CHECK_OBJECT(4, BIGNUM, "openssl.bn");
  BIGNUM       *Brnd = CHECK_OBJECT(5, BIGNUM, "openssl.bn");

  /* Server's key */
  BIGNUM *Kserver = SRP_Calc_server_key(Apub, v, u, Brnd, GN->N);
  PUSH_OBJECT(Kserver, "openssl.bn");
  return 1;
}

/* client side */
/***
Calculates the client's A value.
@function calc_a
@tparam[opt] int bits Number of random bits, default is 256
@treturn openssl.bn Apub Client public key
@treturn openssl.bn Arnd Client random number
***/
static int
openssl_srp_calc_a(lua_State *L)
{
  int           ret = 0;
  const SRP_gN *GN = CHECK_OBJECT(1, SRP_gN, "openssl.srp_gn");
  int           bits = luaL_optint(L, 3, 32 * 8);

  BIGNUM *Arnd = NULL, *Apub = NULL;
  Arnd = BN_new();

  ret = BN_rand(Arnd, bits, BN_RAND_TOP_ANY, BN_RAND_BOTTOM_ANY);
  if (ret == 1) {
    /* Client's response */
    Apub = SRP_Calc_A(Arnd, GN->N, GN->g);
    ret = SRP_Verify_A_mod_N(Apub, GN->N);
    if (ret == 1) {
      PUSH_OBJECT(Apub, "openssl.bn");
      PUSH_OBJECT(Arnd, "openssl.bn");
      ret = 2;
    }
  }
  if (ret != 2) {
    ret = openssl_pushresult(L, ret);
    if (Arnd) BN_free(Arnd);
    if (Apub) BN_free(Apub);
  }
  return ret;
}

/* close https://github.com/zhaozg/lua-openssl/issues/312 */
/***
Calculates the x value.
@function calc_x
@tparam openssl.bn s Salt
@tparam string username Username
@tparam string password Password
@treturn openssl.bn x Value
*/
static int
openssl_srp_calc_X(lua_State *L)
{
  const SRP_gN *GN = CHECK_OBJECT(1, SRP_gN, "openssl.srp_gn");
  BIGNUM       *s = CHECK_OBJECT(2, BIGNUM, "openssl.bn");
  const char   *username = luaL_checkstring(L, 3);
  const char   *password = luaL_checkstring(L, 4);

  BIGNUM *x = SRP_Calc_x(s, username, password);
  PUSH_OBJECT(x, "openssl.bn");

  (void)GN;
  return 1;
}

/***
Calculates the client's key.
@function calc_client_key
@tparam openssl.bn Bpub Server public key
@tparam openssl.bn x x Value
@tparam openssl.bn Arnd Client random number
@tparam openssl.bn u Random number u
@treturn openssl.bn Kclient Client key
*/
static int
openssl_srp_calc_client_key(lua_State *L)
{
  const SRP_gN *GN = CHECK_OBJECT(1, SRP_gN, "openssl.srp_gn");
  BIGNUM       *Bpub = CHECK_OBJECT(2, BIGNUM, "openssl.bn");
  BIGNUM       *x = CHECK_OBJECT(3, BIGNUM, "openssl.bn");
  BIGNUM       *Arnd = CHECK_OBJECT(4, BIGNUM, "openssl.bn");
  BIGNUM       *u = CHECK_OBJECT(5, BIGNUM, "openssl.bn");

  /* Client's key */
  BIGNUM *Kclient = SRP_Calc_client_key(GN->N, Bpub, GN->g, x, Arnd, u);
  PUSH_OBJECT(Kclient, "openssl.bn");
  return 1;
}

/***
Calculates the u value.
@function calc_u
@tparam openssl.bn Apub Client public key
@tparam openssl.bn Bpub Server public key
@treturn openssl.bn u Value
*/
static int
openssl_srp_calc_u(lua_State *L)
{
  const SRP_gN *GN = CHECK_OBJECT(1, SRP_gN, "openssl.srp_gn");
  BIGNUM       *Apub = CHECK_OBJECT(2, BIGNUM, "openssl.bn");
  BIGNUM       *Bpub = CHECK_OBJECT(3, BIGNUM, "openssl.bn");

  /* Both sides calculate u */
  BIGNUM *u = SRP_Calc_u(Apub, Bpub, GN->N);
  PUSH_OBJECT(u, "openssl.bn");
  return 1;
}

static luaL_Reg srp_funs[] = {
  /* both side */
  { "calc_u",          openssl_srp_calc_u          },

  /* client side */
  { "calc_a",          openssl_srp_calc_a          },
  { "calc_x",          openssl_srp_calc_X          },
  { "calc_client_key", openssl_srp_calc_client_key },

  /* server side */
  { "calc_b",          openssl_srp_calc_b          },
  { "create_verifier", openssl_srp_create_verifier },
  { "calc_server_key", openssl_srp_calc_server_key },

  /* prototype */
  { "__tostring",      auxiliar_tostring           },

  { NULL,              NULL                        }
};

static luaL_Reg R[] = {
  { "get_default_gN", openssl_srp_get_default_gN },
  { "calc_x",         openssl_srp_calc_x         },

  { NULL,             NULL                       }
};

int
luaopen_srp(lua_State *L)
{
  auxiliar_newclass(L, "openssl.srp_gn", srp_funs);

  lua_newtable(L);
  luaL_setfuncs(L, R, 0);

  return 1;
}

#if defined(__GNUC__) || defined(__clang__)
#pragma GCC diagnostic pop
#endif

#endif
