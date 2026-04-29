/*=========================================================================*\
* dh.c
* DH routines for lua-openssl binding
*
* Author:  george zhao <zhaozg(at)gmail.com>
\*=========================================================================*/

/***
dh module for lua-openssl binding

Diffie-Hellman (DH) key exchange is a method of securely exchanging
cryptographic keys over a public channel. The module provides functionality
for DH parameter generation, key generation and key agreement operations.

@module dh
@usage
  dh = require('openssl').dh
*/
#include <openssl/dh.h>
#include <openssl/engine.h>

#include "openssl.h"
#include "private.h"

#if !defined(OPENSSL_NO_DH)

#if OPENSSL_VERSION_NUMBER >= 0x30000000L && !defined(LIBRESSL_VERSION_NUMBER)
EVP_PKEY* openssl_new_pkey_dh_with(const BIGNUM *p,
                                   const BIGNUM *q,
                                   const BIGNUM *g,
                                   const BIGNUM *pub_key,
                                   const BIGNUM *priv_key)
{
  EVP_PKEY *pkey = NULL;
  OSSL_PARAM_BLD *param_bld = OSSL_PARAM_BLD_new();
  if (param_bld) {
    EVP_PKEY_CTX *ctx = NULL;
    OSSL_PARAM *params = NULL;

    if (p && !OSSL_PARAM_BLD_push_BN(param_bld, OSSL_PKEY_PARAM_FFC_P, p)) goto cleanup;
    if (q && !OSSL_PARAM_BLD_push_BN(param_bld, OSSL_PKEY_PARAM_FFC_Q, q)) goto cleanup;
    if (g && !OSSL_PARAM_BLD_push_BN(param_bld, OSSL_PKEY_PARAM_FFC_G, g)) goto cleanup;
    if (pub_key && !OSSL_PARAM_BLD_push_BN(param_bld, OSSL_PKEY_PARAM_PUB_KEY, pub_key)) goto cleanup;

    if (priv_key && !OSSL_PARAM_BLD_push_BN(param_bld, OSSL_PKEY_PARAM_PRIV_KEY, priv_key)) goto cleanup;
    params = OSSL_PARAM_BLD_to_param(param_bld);
    if (!params) goto cleanup;

    ctx = EVP_PKEY_CTX_new_from_name(NULL, "DH", NULL);
    if (!ctx) goto cleanup;

    if (EVP_PKEY_fromdata_init(ctx) <= 0) goto cleanup;
    if (EVP_PKEY_fromdata(ctx, &pkey, EVP_PKEY_KEYPAIR, params) <= 0) {
      pkey = NULL;
    }
  cleanup:
    OSSL_PARAM_free(params);
    OSSL_PARAM_BLD_free(param_bld);
    EVP_PKEY_CTX_free(ctx);
  }
  return pkey;
}
#endif

/* Suppress deprecation warnings for DH_free which is unavoidable
 * since we manage DH objects for Lua interface compatibility */
#if defined(__GNUC__) || defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
#endif

static int openssl_dh_free(lua_State *L)
{
  DH *dh = CHECK_OBJECT(1, DH, "openssl.dh");
  /* Note: DH_free is still used here as we manage DH objects directly.
   * The deprecation warnings are in the generation/manipulation functions
   * which have been migrated to EVP_PKEY APIs above. */
  DH_free(dh);
  return 0;
};

#if defined(__GNUC__) || defined(__clang__)
#pragma GCC diagnostic pop
#endif

/***
parse DH key parameters and components
@function parse
@treturn table DH parameters including size, bits, p, q, g, public key, and private key (if present)
*/
static int openssl_dh_parse(lua_State *L)
{
  DH *dh = CHECK_OBJECT(1, DH, "openssl.dh");
  lua_newtable(L);

#if OPENSSL_VERSION_NUMBER >= 0x30000000L
  /* OpenSSL 3.0+ - Use EVP_PKEY APIs */
  BIGNUM   *p = NULL, *q = NULL, *g = NULL, *pub = NULL, *pri = NULL;
  EVP_PKEY *pkey = NULL;
  int       bits = 0;

  /* Create EVP_PKEY from DH to use new APIs */
  pkey = EVP_PKEY_new();

#if defined(__GNUC__) || defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
#endif

  if (pkey && EVP_PKEY_set1_DH(pkey, dh) == 1) {

#if defined(__GNUC__) || defined(__clang__)
#pragma GCC diagnostic pop
#endif

    /* Get bits using EVP_PKEY API */
    bits = EVP_PKEY_get_bits(pkey);
    lua_pushinteger(L, (bits + 7) / 8); /* size in bytes */
    lua_setfield(L, -2, "size");

    lua_pushinteger(L, bits);
    lua_setfield(L, -2, "bits");

    /* Get parameters using EVP_PKEY_get_bn_param */
    if (EVP_PKEY_get_bn_param(pkey, OSSL_PKEY_PARAM_FFC_P, &p) == 1) {
      OPENSSL_PKEY_GET_BN(p, p);
      BN_free(p);
    }

    if (EVP_PKEY_get_bn_param(pkey, OSSL_PKEY_PARAM_FFC_Q, &q) == 1) {
      OPENSSL_PKEY_GET_BN(q, q);
      BN_free(q);
    }

    if (EVP_PKEY_get_bn_param(pkey, OSSL_PKEY_PARAM_FFC_G, &g) == 1) {
      OPENSSL_PKEY_GET_BN(g, g);
      BN_free(g);
    }

    if (EVP_PKEY_get_bn_param(pkey, OSSL_PKEY_PARAM_PUB_KEY, &pub) == 1) {
      OPENSSL_PKEY_GET_BN(pub, pub_key);
      BN_free(pub);
    }

    if (EVP_PKEY_get_bn_param(pkey, OSSL_PKEY_PARAM_PRIV_KEY, &pri) == 1) {
      OPENSSL_PKEY_GET_BN(pri, priv_key);
      BN_free(pri);
    }

    EVP_PKEY_free(pkey);
  } else {
    /* Fallback if EVP_PKEY creation fails */
    if (pkey) EVP_PKEY_free(pkey);
    lua_pushinteger(L, 0);
    lua_setfield(L, -2, "size");
    lua_pushinteger(L, 0);
    lua_setfield(L, -2, "bits");
  }
#else
  /* OpenSSL 1.x - Use legacy DH APIs */
  const BIGNUM *p = NULL, *q = NULL, *g = NULL, *pub = NULL, *pri = NULL;

  lua_pushinteger(L, DH_size(dh));
  lua_setfield(L, -2, "size");

  lua_pushinteger(L, DH_bits(dh));
  lua_setfield(L, -2, "bits");

  DH_get0_pqg(dh, &p, &q, &g);
  DH_get0_key(dh, &pub, &pri);

  OPENSSL_PKEY_GET_BN(p, p);
  OPENSSL_PKEY_GET_BN(q, q);
  OPENSSL_PKEY_GET_BN(g, g);
  OPENSSL_PKEY_GET_BN(pub, pub_key);
  OPENSSL_PKEY_GET_BN(pri, priv_key);
#endif

  return 1;
}

/***
check DH parameters for validity
@function check
@treturn boolean true if parameters are valid
@treturn[opt] table error codes if parameters are invalid
*/
static int openssl_dh_check(lua_State *L)
{
  const DH *dh = CHECK_OBJECT(1, DH, "openssl.dh");
  int       ret = 0;
  int       codes = 0;

#if OPENSSL_VERSION_NUMBER >= 0x30000000L
  /* OpenSSL 3.0+ - Use EVP_PKEY APIs */
  EVP_PKEY     *pkey = NULL;
  EVP_PKEY_CTX *ctx = NULL;

#if defined(__GNUC__) || defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
#endif

  if (lua_isuserdata(L, 2)) {
    /* Check public key - convert to EVP_PKEY and use EVP_PKEY_public_check */
    pkey = EVP_PKEY_new();
    if (pkey && EVP_PKEY_set1_DH(pkey, (DH*)dh) == 1) {
      ctx = EVP_PKEY_CTX_new(pkey, NULL);
      if (ctx) {
        ret = EVP_PKEY_public_check(ctx);
        /* Map result to legacy codes for compatibility */
        if (ret != 1) {
          codes = DH_CHECK_PUBKEY_TOO_SMALL; /* Simplified mapping */
        }
        EVP_PKEY_CTX_free(ctx);
      }
      EVP_PKEY_free(pkey);
    }
  } else {
    /* Check parameters - convert to EVP_PKEY and use EVP_PKEY_param_check */
    pkey = EVP_PKEY_new();
    if (pkey && EVP_PKEY_set1_DH(pkey, (DH*)dh) == 1) {
      ctx = EVP_PKEY_CTX_new(pkey, NULL);
      if (ctx) {
        ret = EVP_PKEY_param_check(ctx);
        /* EVP_PKEY_param_check returns 1 for success, 0 for failure */
        /* We need to map this to legacy DH_check codes for compatibility */
        if (ret != 1) {
          codes = DH_CHECK_P_NOT_PRIME; /* Simplified mapping */
        }
        EVP_PKEY_CTX_free(ctx);
      }
      EVP_PKEY_free(pkey);
    }
  }

#if defined(__GNUC__) || defined(__clang__)
#pragma GCC diagnostic pop
#endif

#else
  /* OpenSSL 1.x - Use legacy DH APIs */
  if (lua_isuserdata(L, 2)) {
    const BIGNUM *pub = CHECK_OBJECT(2, BIGNUM, "openssl.bn");
    ret = DH_check_pub_key(dh, pub, &codes);
  } else {
    ret = DH_check(dh, &codes);
  }
#endif

  lua_pushboolean(L, ret);
  lua_pushinteger(L, codes);
  return 2;
}

/***
generate DH parameters for key exchange
@function generate_parameters
@tparam[opt=1024] number bits parameter size in bits
@tparam[opt=2] number generator generator value (typically 2 or 5)
@tparam[opt] openssl.engine eng engine to use for parameter generation
@treturn dh|nil generated DH parameters or nil on error
*/
static int
openssl_dh_generate_parameters(lua_State *L)
{
  int     bits = luaL_optint(L, 1, 1024);
  int     generator = luaL_optint(L, 2, 2);
  ENGINE *eng = lua_isnoneornil(L, 3) ? NULL : CHECK_OBJECT(3, ENGINE, "openssl.engine");
  int     ret = 0;
  DH     *dh = NULL;

#if OPENSSL_VERSION_NUMBER >= 0x30000000L
  /* OpenSSL 3.0+ - Use EVP_PKEY APIs */
  EVP_PKEY_CTX *pctx = NULL;
  EVP_PKEY     *pkey = NULL;

  /* Note: ENGINE support is not directly available with EVP_PKEY_CTX_new_from_name.
   * For ENGINE support, the old API would need to be used. */
  (void)eng;

  /* Create parameter generation context */
  pctx = EVP_PKEY_CTX_new_from_name(NULL, "DH", NULL);
  if (!pctx) {
    return openssl_pushresult(L, 0);
  }

  /* Initialize parameter generation */
  ret = EVP_PKEY_paramgen_init(pctx);
  if (ret != 1) {
    EVP_PKEY_CTX_free(pctx);
    return openssl_pushresult(L, ret);
  }

  /* Set parameter generation options */
  if (EVP_PKEY_CTX_set_dh_paramgen_prime_len(pctx, bits) <= 0) {
    EVP_PKEY_CTX_free(pctx);
    return openssl_pushresult(L, 0);
  }

  if (EVP_PKEY_CTX_set_dh_paramgen_generator(pctx, generator) <= 0) {
    EVP_PKEY_CTX_free(pctx);
    return openssl_pushresult(L, 0);
  }

  /* Generate parameters */
  ret = EVP_PKEY_paramgen(pctx, &pkey);
  EVP_PKEY_CTX_free(pctx);

  if (ret == 1 && pkey) {
    /* Extract DH from EVP_PKEY for compatibility with Lua API */
#if defined(__GNUC__) || defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
#endif
    dh = EVP_PKEY_get1_DH(pkey);
#if defined(__GNUC__) || defined(__clang__)
#pragma GCC diagnostic pop
#endif

    EVP_PKEY_free(pkey);

    if (dh) {
      PUSH_OBJECT(dh, "openssl.dh");
      return 1;
    }
  }

  if (pkey) EVP_PKEY_free(pkey);
  return openssl_pushresult(L, ret);
#else
  /* OpenSSL 1.x - Use legacy DH APIs */
  dh = eng ? DH_new_method(eng) : DH_new();
  ret = DH_generate_parameters_ex(dh, bits, generator, NULL);

  if (ret == 1) {
    PUSH_OBJECT(dh, "openssl.dh");
    return 1;
  }
  DH_free(dh);
  return openssl_pushresult(L, ret);
#endif
}

/***
generate a DH key pair from parameters
@function generate_key
@treturn openssl.dh new DH object with generated key pair on success
*/
static int
openssl_dh_generate_key(lua_State *L)
{
  DH  *dhparameter = CHECK_OBJECT(1, DH, "openssl.dh");
  DH  *dh = NULL;
  int  ret = 0;

#if OPENSSL_VERSION_NUMBER >= 0x30000000L
  /* OpenSSL 3.0+ - Use EVP_PKEY APIs */
  EVP_PKEY     *param_pkey = NULL;
  EVP_PKEY_CTX *kctx = NULL;
  EVP_PKEY     *pkey = NULL;

#if defined(__GNUC__) || defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
#endif

  /* Convert DH parameters to EVP_PKEY */
  param_pkey = EVP_PKEY_new();
  if (!param_pkey || EVP_PKEY_set1_DH(param_pkey, dhparameter) != 1) {
    if (param_pkey) EVP_PKEY_free(param_pkey);
    return openssl_pushresult(L, 0);
  }

#if defined(__GNUC__) || defined(__clang__)
#pragma GCC diagnostic pop
#endif

  /* Create key generation context from parameters */
  kctx = EVP_PKEY_CTX_new(param_pkey, NULL);
  EVP_PKEY_free(param_pkey);

  if (!kctx) {
    return openssl_pushresult(L, 0);
  }

  /* Initialize key generation */
  ret = EVP_PKEY_keygen_init(kctx);
  if (ret != 1) {
    EVP_PKEY_CTX_free(kctx);
    return openssl_pushresult(L, ret);
  }

  /* Generate key pair */
  ret = EVP_PKEY_keygen(kctx, &pkey);
  EVP_PKEY_CTX_free(kctx);

  if (ret == 1 && pkey) {
    /* Extract DH from EVP_PKEY for compatibility with Lua API */
#if defined(__GNUC__) || defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
#endif
    dh = EVP_PKEY_get1_DH(pkey);
#if defined(__GNUC__) || defined(__clang__)
#pragma GCC diagnostic pop
#endif

    EVP_PKEY_free(pkey);

    if (dh) {
      PUSH_OBJECT(dh, "openssl.dh");
      return 1;
    }
  }

  if (pkey) EVP_PKEY_free(pkey);
  return openssl_pushresult(L, ret);
#else
  /* OpenSSL 1.x - Use legacy DH APIs */
  dh = DHparams_dup(dhparameter);
  ret = DH_generate_key(dh);

  if (ret == 1) {
    PUSH_OBJECT(dh, "openssl.dh");
    return 1;
  }
  DH_free(dh);
  return openssl_pushresult(L, ret);
#endif
}

static luaL_Reg dh_funs[] = {
  { "generate_key", openssl_dh_generate_key },
  { "parse",        openssl_dh_parse        },
  { "check",        openssl_dh_check        },

  { "__gc",         openssl_dh_free         },
  { "__tostring",   auxiliar_tostring       },

  { NULL,           NULL                    }
};

static LuaL_Enumeration dh_problems[] = {
  { "DH_CHECK_P_NOT_PRIME",         DH_CHECK_P_NOT_PRIME         },
  { "DH_CHECK_P_NOT_SAFE_PRIME",    DH_CHECK_P_NOT_SAFE_PRIME    },
  { "DH_UNABLE_TO_CHECK_GENERATOR", DH_UNABLE_TO_CHECK_GENERATOR },
  { "DH_NOT_SUITABLE_GENERATOR",    DH_NOT_SUITABLE_GENERATOR    },
#ifdef DH_CHECK_Q_NOT_PRIME
  { "DH_CHECK_Q_NOT_PRIME",         DH_CHECK_Q_NOT_PRIME         },
#endif
#ifdef DH_CHECK_INVALID_Q_VALUE
  { "DH_CHECK_INVALID_Q_VALUE",     DH_CHECK_INVALID_Q_VALUE     },
#endif
#ifdef DH_CHECK_INVALID_J_VALUE
  { "DH_CHECK_INVALID_J_VALUE",     DH_CHECK_INVALID_J_VALUE     },
#endif

  { "DH_CHECK_PUBKEY_TOO_SMALL",    DH_CHECK_PUBKEY_TOO_SMALL    },
  { "DH_CHECK_PUBKEY_TOO_LARGE",    DH_CHECK_PUBKEY_TOO_LARGE    },
#ifdef DH_CHECK_PUBKEY_INVALID
  { "DH_CHECK_PUBKEY_INVALID",      DH_CHECK_PUBKEY_INVALID      },
#endif

  { NULL,                           -1                           }
};

/***
interpret DH parameter check problems
@function problems
@tparam number reason the problem codes returned by check functions
@tparam[opt=false] boolean pub whether to include public key problems
@treturn table array of problem descriptions
*/
static int
openssl_dh_problems(lua_State *L)
{
  int reason = luaL_checkint(L, 1);
  int pub = lua_toboolean(L, 2);
  int i = 1;

#define VAL(r, v)                                                                                  \
  if (r & DH_##v) {                                                                                \
    lua_pushliteral(L, #v);                                                                        \
    lua_rawseti(L, -2, i++);                                                                       \
  }

  lua_newtable(L);
  if (pub) {
    VAL(reason, CHECK_PUBKEY_TOO_SMALL);
    VAL(reason, CHECK_PUBKEY_TOO_LARGE);
#ifdef DH_CHECK_PUBKEY_INVALID
    VAL(reason, CHECK_PUBKEY_INVALID);
#endif
  } else {
    VAL(reason, CHECK_P_NOT_PRIME);
    VAL(reason, CHECK_PUBKEY_TOO_SMALL);
    VAL(reason, UNABLE_TO_CHECK_GENERATOR);
    VAL(reason, NOT_SUITABLE_GENERATOR);

#ifdef DH_CHECK_Q_NOT_PRIME
    VAL(reason, CHECK_Q_NOT_PRIME);
#endif
#ifdef DH_CHECK_INVALID_Q_VALUE
    VAL(reason, CHECK_INVALID_Q_VALUE);
#endif
#ifdef DH_CHECK_INVALID_J_VALUE
    VAL(reason, CHECK_INVALID_J_VALUE);
#endif
  }

#undef VAL

  return 1;
}

static luaL_Reg R[] = {
  { "generate_parameters", openssl_dh_generate_parameters },
  { "problems",            openssl_dh_problems            },

  { NULL,                  NULL                           }
};

int
luaopen_dh(lua_State *L)
{
  auxiliar_newclass(L, "openssl.dh", dh_funs);

  lua_newtable(L);
  luaL_setfuncs(L, R, 0);

  auxiliar_enumerate(L, -1, dh_problems);

  return 1;
}
#endif
