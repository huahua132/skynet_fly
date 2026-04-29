/*=========================================================================*\
* dsa.c
* DSA routines for lua-openssl binding
*
* Author:  george zhao <zhaozg(at)gmail.com>
\*=========================================================================*/

/***
dsa module for lua-openssl binding

Digital Signature Algorithm (DSA) is a Federal Information Processing
Standard for digital signatures. DSA is used for digital signing and
signature verification. The module provides functionality for DSA key
generation, signature creation and verification.

@module dsa
@usage
  dsa = require('openssl').dsa
*/
#include <openssl/dsa.h>
#include <openssl/engine.h>

#include "openssl.h"
#include "private.h"

#if !defined(OPENSSL_NO_DSA)

#if OPENSSL_VERSION_NUMBER >= 0x30000000L && !defined(LIBRESSL_VERSION_NUMBER)
EVP_PKEY* openssl_new_pkey_dsa_with(const BIGNUM *p,
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

    ctx = EVP_PKEY_CTX_new_from_name(NULL, "DSA", NULL);
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

static int openssl_dsa_free(lua_State *L)
{
  DSA *dsa = CHECK_OBJECT(1, DSA, "openssl.dsa");
#if defined(__GNUC__) || defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
#endif
  DSA_free(dsa);
#if defined(__GNUC__) || defined(__clang__)
#pragma GCC diagnostic pop
#endif
  return 0;
};

/***
parse DSA key parameters and components
@function parse
@treturn table DSA parameters including bits, p, q, g, public key, and private key (if present)
*/
static int openssl_dsa_parse(lua_State *L)
{
  const BIGNUM *p = NULL, *q = NULL, *g = NULL, *pub = NULL, *pri = NULL;
  DSA          *dsa = CHECK_OBJECT(1, DSA, "openssl.dsa");
  lua_newtable(L);

#if defined(__GNUC__) || defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
#endif
  lua_pushinteger(L, DSA_bits(dsa));
  lua_setfield(L, -2, "bits");

  DSA_get0_pqg(dsa, &p, &q, &g);
  DSA_get0_key(dsa, &pub, &pri);
#if defined(__GNUC__) || defined(__clang__)
#pragma GCC diagnostic pop
#endif

  OPENSSL_PKEY_GET_BN(p, p);
  OPENSSL_PKEY_GET_BN(q, q);
  OPENSSL_PKEY_GET_BN(g, g);
  OPENSSL_PKEY_GET_BN(pri, priv_key);
  OPENSSL_PKEY_GET_BN(pub, pub_key);
  return 1;
}

/***
set engine for DSA operations
@function set_engine
@tparam openssl.engine engine the engine to use for DSA operations
@treturn boolean true on success, false on failure
*/
static int
openssl_dsa_set_engine(lua_State *L)
{
#ifndef OPENSSL_NO_ENGINE
  DSA              *dsa = CHECK_OBJECT(1, DSA, "openssl.dsa");
  ENGINE           *e = CHECK_OBJECT(2, ENGINE, "openssl.engine");
#if defined(__GNUC__) || defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
#endif
  const DSA_METHOD *m = ENGINE_get_DSA(e);
  if (m) {
    int r = DSA_set_method(dsa, m);
    return openssl_pushresult(L, r);
  }
#if defined(__GNUC__) || defined(__clang__)
#pragma GCC diagnostic pop
#endif
#endif
  return 0;
}

/***
generate DSA key pair with specified parameters
@function generate_key
@tparam[opt=1024] number bits key size in bits
@tparam[opt] string seed random seed for parameter generation
@tparam[opt] openssl.engine eng engine to use for key generation
@treturn dsa|nil generated DSA key pair or nil on error
*/
static int
openssl_dsa_generate_key(lua_State *L)
{
  int         bits = luaL_optint(L, 1, 1024);
  size_t      seed_len = 0;
  const char *seed = luaL_optlstring(L, 2, NULL, &seed_len);
  ENGINE     *eng = lua_isnoneornil(L, 3) ? NULL : CHECK_OBJECT(3, ENGINE, "openssl.engine");
  DSA        *dsa = NULL;
  int         ret = 0;

#if OPENSSL_VERSION_NUMBER >= 0x30000000L && !defined(LIBRESSL_VERSION_NUMBER)
  /* OpenSSL 3.0+ - Use EVP_PKEY APIs to avoid deprecation warnings */
  EVP_PKEY_CTX *pctx = NULL;
  EVP_PKEY_CTX *kctx = NULL;
  EVP_PKEY     *param_pkey = NULL;
  EVP_PKEY     *pkey = NULL;

  /* Create context for parameter generation */
  pctx = EVP_PKEY_CTX_new_from_name(NULL, "DSA", NULL);
  if (!pctx) {
    return openssl_pushresult(L, 0);
  }

  /* Initialize parameter generation */
  ret = EVP_PKEY_paramgen_init(pctx);
  if (ret != 1) {
    EVP_PKEY_CTX_free(pctx);
    return openssl_pushresult(L, ret);
  }

  /* Set key size */
  ret = EVP_PKEY_CTX_set_dsa_paramgen_bits(pctx, bits);
  if (ret != 1) {
    EVP_PKEY_CTX_free(pctx);
    return openssl_pushresult(L, ret);
  }

  /* Set seed if provided */
  if (seed && seed_len > 0) {
    ret = EVP_PKEY_CTX_ctrl(pctx, EVP_PKEY_DSA, EVP_PKEY_OP_PARAMGEN,
                            EVP_PKEY_CTRL_DSA_PARAMGEN_MD, 0, (void *)seed);
    /* Note: seed handling may not work the same way in OpenSSL 3.0 */
    /* We continue even if this fails, as the seed is optional */
  }

  /* Generate parameters */
  ret = EVP_PKEY_paramgen(pctx, &param_pkey);
  EVP_PKEY_CTX_free(pctx);

  if (ret != 1 || !param_pkey) {
    if (param_pkey) EVP_PKEY_free(param_pkey);
    return openssl_pushresult(L, ret);
  }

  /* Create key generation context from parameters */
  kctx = EVP_PKEY_CTX_new(param_pkey, eng);
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
    /* Extract DSA from EVP_PKEY for compatibility with Lua API */
#if defined(__GNUC__) || defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
#endif
    dsa = EVP_PKEY_get1_DSA(pkey);
#if defined(__GNUC__) || defined(__clang__)
#pragma GCC diagnostic pop
#endif

    EVP_PKEY_free(pkey);

    if (dsa) {
      PUSH_OBJECT(dsa, "openssl.dsa");
      return 1;
    }
  }

  if (pkey) EVP_PKEY_free(pkey);
  return openssl_pushresult(L, ret);
#else
  /* OpenSSL 1.x - Use legacy DSA APIs */
  dsa = eng ? DSA_new_method(eng) : DSA_new();
  ret = DSA_generate_parameters_ex(dsa, bits, (byte *)seed, seed_len, NULL, NULL, NULL);
  if (ret == 1) ret = DSA_generate_key(dsa);
  if (ret == 1) {
    PUSH_OBJECT(dsa, "openssl.dsa");
    return 1;
  }
  DSA_free(dsa);
  return openssl_pushresult(L, ret);
#endif
}

static luaL_Reg dsa_funs[] = {
  { "parse",      openssl_dsa_parse      },
  { "set_engine", openssl_dsa_set_engine },

  { "__gc",       openssl_dsa_free       },
  { "__tostring", auxiliar_tostring      },

  { NULL,         NULL                   }
};

static luaL_Reg R[] = {
  { "generate_key", openssl_dsa_generate_key },

  { NULL,           NULL                     }
};

int
luaopen_dsa(lua_State *L)
{
  auxiliar_newclass(L, "openssl.dsa", dsa_funs);

  lua_newtable(L);
  luaL_setfuncs(L, R, 0);

  return 1;
}
#endif
