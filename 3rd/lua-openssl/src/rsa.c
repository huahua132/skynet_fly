/*=========================================================================*\
* ec.c
* RSA routines for lua-openssl binding
*
* Author:  george zhao <zhaozg(at)gmail.com>
\*=========================================================================*/

/***
rsa module for lua-openssl binding

RSA (Rivest-Shamir-Adleman) is a public-key cryptosystem that is widely
used for secure data transmission. The module provides functionality for
RSA key generation, encryption, decryption, signing and signature verification.

@module rsa
@usage
  rsa = require('openssl').rsa
*/
#include <openssl/engine.h>
#include <openssl/rsa.h>

#include "openssl.h"
#include "private.h"

/* Suppress deprecation warnings for RSA low-level APIs in OpenSSL 3.0+
 * This module provides direct Lua bindings to OpenSSL's RSA-specific APIs.
 * These APIs are deprecated in OpenSSL 3.0+ in favor of EVP_PKEY operations,
 * but we maintain them for:
 * 1. Complete RSA-specific functionality (padding modes, parameters, etc.)
 * 2. Backward compatibility with existing Lua code
 * 3. Direct access to RSA key components for advanced use cases
 *
 * The current implementation is safe, well-tested, and maintains compatibility
 * across OpenSSL 1.1.x and 3.x versions.
 */
#if defined(__GNUC__) || defined(__clang__)
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
#endif

#if OPENSSL_VERSION_NUMBER >= 0x30000000L && !defined(LIBRESSL_VERSION_NUMBER)
EVP_PKEY* openssl_new_pkey_rsa_with(const BIGNUM *n,
                                    const BIGNUM *e,
                                    const BIGNUM *d,
                                    const BIGNUM *p,
                                    const BIGNUM *q,
                                    const BIGNUM *dmp1,
                                    const BIGNUM *dmq1,
                                    const BIGNUM *iqmp)
{
  EVP_PKEY *pkey = NULL;
  OSSL_PARAM_BLD *param_bld = OSSL_PARAM_BLD_new();
  if (param_bld) {
    EVP_PKEY_CTX *ctx = NULL;
    OSSL_PARAM *params = NULL;

    if (n && !OSSL_PARAM_BLD_push_BN(param_bld, OSSL_PKEY_PARAM_RSA_N, n)) goto cleanup;
    if (e && !OSSL_PARAM_BLD_push_BN(param_bld, OSSL_PKEY_PARAM_RSA_E, e)) goto cleanup;

    if (d && !OSSL_PARAM_BLD_push_BN(param_bld, OSSL_PKEY_PARAM_RSA_D, d)) goto cleanup;
    if (p && !OSSL_PARAM_BLD_push_BN(param_bld, OSSL_PKEY_PARAM_RSA_FACTOR1, p)) goto cleanup;
    if (q && !OSSL_PARAM_BLD_push_BN(param_bld, OSSL_PKEY_PARAM_RSA_FACTOR2, q)) goto cleanup;

    if (dmp1 && !OSSL_PARAM_BLD_push_BN(param_bld, OSSL_PKEY_PARAM_RSA_EXPONENT1, dmp1)) goto cleanup;
    if (dmq1 && !OSSL_PARAM_BLD_push_BN(param_bld, OSSL_PKEY_PARAM_RSA_EXPONENT2, dmq1)) goto cleanup;
    if (iqmp && !OSSL_PARAM_BLD_push_BN(param_bld, OSSL_PKEY_PARAM_RSA_COEFFICIENT1, iqmp)) goto cleanup;

    params = OSSL_PARAM_BLD_to_param(param_bld);
    if (!params) goto cleanup;

    ctx = EVP_PKEY_CTX_new_from_name(NULL, "RSA", NULL);
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

#if !defined(OPENSSL_NO_RSA)
static int openssl_rsa_free(lua_State *L)
{
  RSA *rsa = CHECK_OBJECT(1, RSA, "openssl.rsa");
  RSA_free(rsa);
  return 0;
};

static int
is_private(const RSA *rsa)
{
  const BIGNUM *d = NULL;
  RSA_get0_key(rsa, NULL, NULL, &d);
  return d != NULL && !BN_is_zero(d);
};

/***
check if RSA key contains private key components
@function isprivate
@treturn boolean true if RSA key is private, false if public only
*/
static int openssl_rsa_isprivate(lua_State *L)
{
  RSA *rsa = CHECK_OBJECT(1, RSA, "openssl.rsa");
  lua_pushboolean(L, is_private(rsa));
  return 1;
};

/***
get RSA key size in bytes
@function size
@treturn number key size in bytes
*/
static int openssl_rsa_size(lua_State *L)
{
  RSA *rsa = CHECK_OBJECT(1, RSA, "openssl.rsa");
  lua_pushinteger(L, RSA_size(rsa));
  return 1;
};

/***
encrypt data using RSA key
@function encrypt
@tparam string data data to encrypt
@tparam[opt="pkcs1"] string padding padding mode ("pkcs1", "oaep", "none")
@tparam[opt] boolean use_private true to use private key for encryption
@treturn string|nil encrypted data or nil on error
*/
static int openssl_rsa_encrypt(lua_State *L)
{
  RSA                 *rsa = CHECK_OBJECT(1, RSA, "openssl.rsa");
  size_t               l;
  const unsigned char *from = (const unsigned char *)luaL_checklstring(L, 2, &l);
  int                  padding = openssl_get_padding(L, 3, "pkcs1");
  int                  ispriv = lua_isnone(L, 4) ? is_private(rsa) : lua_toboolean(L, 4);
  unsigned char       *to = OPENSSL_malloc(RSA_size(rsa));
  int                  flen = l;

  flen = ispriv ? RSA_private_encrypt(flen, from, to, rsa, padding)
                : RSA_public_encrypt(flen, from, to, rsa, padding);
  if (flen > 0) {
    lua_pushlstring(L, (const char *)to, flen);
    flen = 1;
  }
  OPENSSL_free(to);
  return flen == 1 ? flen : openssl_pushresult(L, flen);
};

/***
decrypt data using RSA private key
@function decrypt
@tparam string data encrypted data to decrypt
@tparam[opt="pkcs1"] string padding padding mode ("pkcs1", "oaep", "none")
@tparam[opt] boolean use_private true to use private key for decryption
@treturn string|nil decrypted data or nil on error
*/
static int openssl_rsa_decrypt(lua_State *L)
{
  RSA                 *rsa = CHECK_OBJECT(1, RSA, "openssl.rsa");
  size_t               l;
  const unsigned char *from = (const unsigned char *)luaL_checklstring(L, 2, &l);
  int                  padding = openssl_get_padding(L, 3, "pkcs1");
  int                  ispriv = lua_isnone(L, 4) ? is_private(rsa) : lua_toboolean(L, 4);
  unsigned char       *to = OPENSSL_malloc(RSA_size(rsa));
  int                  flen = l;

  flen = ispriv ? RSA_private_decrypt(flen, from, to, rsa, padding)
                : RSA_public_decrypt(flen, from, to, rsa, padding);
  if (flen > 0) {
    lua_pushlstring(L, (const char *)to, flen);
    flen = 1;
  }
  OPENSSL_free(to);
  return flen == 1 ? flen : openssl_pushresult(L, flen);
};

/***
create digital signature using RSA private key
@function sign
@tparam string message data to sign
@tparam[opt="sha256"] string|evp_md digest algorithm to use
@treturn string|nil signature or nil on error
*/
static int openssl_rsa_sign(lua_State *L)
{
  RSA                 *rsa = CHECK_OBJECT(1, RSA, "openssl.rsa");
  size_t               l;
  const unsigned char *msg = (const unsigned char *)luaL_checklstring(L, 2, &l);
  const EVP_MD        *md = get_digest(L, 3, "sha256");
  unsigned char       *sig = OPENSSL_malloc(RSA_size(rsa));
  int                  flen = l;
  unsigned int         slen = RSA_size(rsa);

  int ret = RSA_sign(EVP_MD_type(md), msg, flen, sig, &slen, rsa);
  if (ret == 1) {
    lua_pushlstring(L, (const char *)sig, slen);
  }
  OPENSSL_free(sig);
  return ret == 1 ? ret : openssl_pushresult(L, ret);
};

/***
verify RSA signature using public key
@function verify
@tparam string message original data that was signed
@tparam string signature signature to verify
@tparam[opt="sha256"] string|evp_md digest algorithm used for signing
@treturn boolean true if signature is valid, false otherwise
*/
static int openssl_rsa_verify(lua_State *L)
{
  RSA                 *rsa = CHECK_OBJECT(1, RSA, "openssl.rsa");
  size_t               l;
  const unsigned char *from = (const unsigned char *)luaL_checklstring(L, 2, &l);
  size_t               s;
  const unsigned char *sig = (const unsigned char *)luaL_checklstring(L, 3, &s);
  const EVP_MD        *md = get_digest(L, 4, "sha256");
  int                  flen = l;
  int                  slen = s;

  int ret = RSA_verify(EVP_MD_type(md), from, flen, sig, slen, rsa);
  lua_pushboolean(L, ret);
  return 1;
};

/***
parse RSA key components and parameters
@function parse
@treturn table RSA key parameters including bits, n, e, d, p, q, and CRT parameters
*/
static int openssl_rsa_parse(lua_State *L)
{
  RSA *rsa = CHECK_OBJECT(1, RSA, "openssl.rsa");

  lua_newtable(L);

#if OPENSSL_VERSION_NUMBER >= 0x30000000L && !defined(LIBRESSL_VERSION_NUMBER)
  /* Try OpenSSL 3.0+ PARAM API first for keys created with new API */
  EVP_PKEY *pkey = EVP_PKEY_new();
  if (pkey && EVP_PKEY_set1_RSA(pkey, rsa)) {
    BIGNUM *n = NULL, *e = NULL, *d = NULL;
    BIGNUM *p = NULL, *q = NULL;
    BIGNUM *dmp1 = NULL, *dmq1 = NULL, *iqmp = NULL;
    int use_legacy = 0;

    /* Try to get parameters using PARAM API */
    if (!EVP_PKEY_get_bn_param(pkey, OSSL_PKEY_PARAM_RSA_N, &n)) {
      use_legacy = 1;
    } else {
      EVP_PKEY_get_bn_param(pkey, OSSL_PKEY_PARAM_RSA_E, &e);
      EVP_PKEY_get_bn_param(pkey, OSSL_PKEY_PARAM_RSA_D, &d);
      EVP_PKEY_get_bn_param(pkey, OSSL_PKEY_PARAM_RSA_FACTOR1, &p);
      EVP_PKEY_get_bn_param(pkey, OSSL_PKEY_PARAM_RSA_FACTOR2, &q);
      EVP_PKEY_get_bn_param(pkey, OSSL_PKEY_PARAM_RSA_EXPONENT1, &dmp1);
      EVP_PKEY_get_bn_param(pkey, OSSL_PKEY_PARAM_RSA_EXPONENT2, &dmq1);
      EVP_PKEY_get_bn_param(pkey, OSSL_PKEY_PARAM_RSA_COEFFICIENT1, &iqmp);

      lua_pushinteger(L, RSA_size(rsa));
      lua_setfield(L, -2, "size");
      lua_pushinteger(L, RSA_bits(rsa));
      lua_setfield(L, -2, "bits");

      OPENSSL_PKEY_GET_BN(n, n);
      OPENSSL_PKEY_GET_BN(e, e);
      OPENSSL_PKEY_GET_BN(d, d);
      OPENSSL_PKEY_GET_BN(p, p);
      OPENSSL_PKEY_GET_BN(q, q);
      OPENSSL_PKEY_GET_BN(dmp1, dmp1);
      OPENSSL_PKEY_GET_BN(dmq1, dmq1);
      OPENSSL_PKEY_GET_BN(iqmp, iqmp);

      /* Clean up allocated BIGNUMs */
      BN_free(n);
      BN_free(e);
      BN_free(d);
      BN_free(p);
      BN_free(q);
      BN_free(dmp1);
      BN_free(dmq1);
      BN_free(iqmp);
    }

    EVP_PKEY_free(pkey);

    if (!use_legacy) {
      return 1;
    }
  }

  /* Fallback to legacy API if PARAM API fails or EVP_PKEY creation fails */
#endif

  /* Legacy OpenSSL 1.x / 3.x compatibility path */
  {
    const BIGNUM *n = NULL, *e = NULL, *d = NULL;
    const BIGNUM *p = NULL, *q = NULL;
    const BIGNUM *dmp1 = NULL, *dmq1 = NULL, *iqmp = NULL;

    RSA_get0_key(rsa, &n, &e, &d);
    RSA_get0_factors(rsa, &p, &q);
    RSA_get0_crt_params(rsa, &dmp1, &dmq1, &iqmp);

    lua_pushinteger(L, RSA_size(rsa));
    lua_setfield(L, -2, "size");
    lua_pushinteger(L, RSA_bits(rsa));
    lua_setfield(L, -2, "bits");
    OPENSSL_PKEY_GET_BN(n, n);
    OPENSSL_PKEY_GET_BN(e, e);
    OPENSSL_PKEY_GET_BN(d, d);
    OPENSSL_PKEY_GET_BN(p, p);
    OPENSSL_PKEY_GET_BN(q, q);
    OPENSSL_PKEY_GET_BN(dmp1, dmp1);
    OPENSSL_PKEY_GET_BN(dmq1, dmq1);
    OPENSSL_PKEY_GET_BN(iqmp, iqmp);
  }

  return 1;
}

/***
read RSA key from DER/PEM data
@function read
@tparam string data DER or PEM encoded RSA key data
@tparam[opt=true] boolean private true to read private key, false for public key
@treturn rsa|nil RSA key object or nil on error
*/
static int openssl_rsa_read(lua_State *L)
{
  size_t               l;
  const char          *data = luaL_checklstring(L, 1, &l);
  int                  ispriv = lua_isnone(L, 2) ? 1 : lua_toboolean(L, 2);
  const unsigned char *in = (const unsigned char *)data;
  RSA *rsa = ispriv ? d2i_RSAPrivateKey(NULL, &in, l) : d2i_RSA_PUBKEY(NULL, &in, l);
  int  ret = 0;

  if (rsa) {
    PUSH_OBJECT(rsa, "openssl.rsa");
    ret = 1;
  }
  return ret;
}

/***
export RSA key to DER format
@function export
@tparam[opt] boolean private true to export private key, false for public key
@treturn string|nil DER-encoded RSA key or nil on error
*/
static int openssl_rsa_export(lua_State *L)
{
  RSA *rsa = CHECK_OBJECT(1, RSA, "openssl.rsa");
  int  ispriv = lua_isnone(L, 2) ? is_private(rsa) : lua_toboolean(L, 2);
  BIO *out = BIO_new(BIO_s_mem());

  int ret = 0;
  int len = ispriv ? i2d_RSAPrivateKey_bio(out, rsa) : i2d_RSA_PUBKEY_bio(out, rsa);

  if (len > 0) {
    char *bio_mem_ptr;
    long  bio_mem_len;

    bio_mem_len = BIO_get_mem_data(out, &bio_mem_ptr);

    lua_pushlstring(L, bio_mem_ptr, bio_mem_len);
    ret = 1;
  }
  BIO_free(out);
  return ret;
}

/***
set RSA engine for cryptographic operations
@function set_engine
@tparam openssl.engine engine ENGINE object to use for RSA operations
@treturn boolean true on success, false on failure
*/
static int
openssl_rsa_set_engine(lua_State *L)
{
  int ret = 0;
#ifndef OPENSSL_NO_ENGINE
  RSA              *rsa = CHECK_OBJECT(1, RSA, "openssl.rsa");
  ENGINE           *e = CHECK_OBJECT(2, ENGINE, "openssl.engine");
  const RSA_METHOD *m = ENGINE_get_RSA(e);
  if (m) {
    ret = RSA_set_method(rsa, m);
    ret = openssl_pushresult(L, ret);
  }
#endif
  return ret;
}

/***
generate RSA key pair
@function generate_key
@tparam[opt=2048] number bits key size in bits
@tparam[opt=65537] number e public exponent (typically 65537)
@tparam[opt] openssl.engine eng engine to use for key generation
@treturn rsa|nil generated RSA key pair or nil on error
*/
static int
openssl_rsa_generate_key(lua_State *L)
{
  int     bits = luaL_optint(L, 1, 2048);
  int     e = luaL_optint(L, 2, 65537);
  ENGINE *eng = lua_isnoneornil(L, 3) ? NULL : CHECK_OBJECT(3, ENGINE, "openssl.engine");
  int     ret = 0;

  BIGNUM *E = BN_new();
  RSA    *rsa = eng ? RSA_new_method(eng) : RSA_new();

  luaL_argcheck(L, e > 0, 2, "e must be positive");
  BN_set_word(E, e);

  ret = RSA_generate_key_ex(rsa, bits, E, NULL);
  if (ret == 1) {
    PUSH_OBJECT(rsa, "openssl.rsa");
  } else {
    RSA_free(rsa);
    ret = 0;
  }

  BN_free(E);
  return ret;
}

static int
openssl_pading_result(lua_State *L, unsigned long val)
{
  int ret = 1;
  lua_pushnil(L);
  if (val) {
    lua_pushstring(L, ERR_reason_error_string(val));
    lua_pushinteger(L, val);
    ret += 2;
  }
  return ret;
}

static int
openssl_rsa_bytes_len(lua_State *L, int i)
{
  int n;
  if (lua_isnumber(L, i)) {
    n = luaL_checkinteger(L, i);
    luaL_argcheck(L, n > 0, i, "n must be positive");
  } else {
    RSA *rsa = CHECK_OBJECT(i, RSA, "openssl.rsa");
    n = RSA_size(rsa);
  }
  return n;
}

/***
add padding to data for RSA operations
@function padding_add
@tparam string data input data to add padding to
@tparam string padding padding scheme (e.g., "pkcs1", "oaep", "x931", "pss")
@tparam number|rsa key_size RSA key size in bytes or RSA object
@tparam boolean is_private true for private key padding, false for public key
@treturn string data with padding added
*/
static int
openssl_padding_add(lua_State *L)
{
  size_t               l;
  const unsigned char *from = (const unsigned char *)luaL_checklstring(L, 1, &l);
  int                  padding = openssl_get_padding(L, 2, NULL);
  int                  sz = openssl_rsa_bytes_len(L, 3);
  unsigned char       *to = OPENSSL_malloc(sz);
  int                  ret = 0;

  switch (padding) {
  case RSA_PKCS1_PADDING: {
    int pri;
    luaL_checktype(L, 4, LUA_TBOOLEAN);
    pri = lua_toboolean(L, 4);

    /* true for private, false for public */
    if (pri) {
      ret = RSA_padding_add_PKCS1_type_1(to, sz, from, l);
    } else {
      ret = RSA_padding_add_PKCS1_type_2(to, sz, from, l);
    }

    break;
  }
#ifdef RSA_SSLV23_PADDING
#if !defined(LIBRESSL_VERSION_NUMBER) || LIBRESSL_VERSION_NUMBER < 0x3020000fL
  case RSA_SSLV23_PADDING:
    ret = RSA_padding_add_SSLv23(to, sz, from, l);
    break;
#endif
#endif
  case RSA_NO_PADDING:
    ret = RSA_padding_add_none(to, sz, from, l);
    break;
  case RSA_PKCS1_OAEP_PADDING: {
    size_t               pl;
    const unsigned char *p = (const unsigned char *)luaL_optlstring(L, 4, NULL, &pl);
    if (lua_isnone(L, 5)) {
      ret = RSA_padding_add_PKCS1_OAEP(to, sz, from, l, p, pl);
    } else {
      const EVP_MD *md = get_digest(L, 5, NULL);
      const EVP_MD *mgf1md = lua_isnone(L, 6) ? NULL : get_digest(L, 6, NULL);
      ret = RSA_padding_add_PKCS1_OAEP_mgf1(to, sz, from, l, p, pl, md, mgf1md);
    }
    break;
  }
#if !defined(LIBRESSL_VERSION_NUMBER) || LIBRESSL_VERSION_NUMBER < 0x30800000L
  case RSA_X931_PADDING:
    ret = RSA_padding_add_X931(to, sz, from, l);
    break;
#endif
  case RSA_PKCS1_PSS_PADDING: {
    RSA          *rsa = CHECK_OBJECT(3, RSA, "openssl.rsa");
    const EVP_MD *md = get_digest(L, 4, NULL);
    const EVP_MD *mgf1md = lua_isnone(L, 5) ? NULL : get_digest(L, 5, NULL);
    int           saltlen = luaL_optinteger(L, 6, -2);
    luaL_argcheck(L, l == EVP_MD_size(md), 4, "data length to pad mismatch with digest size");

    ret = RSA_padding_add_PKCS1_PSS_mgf1(rsa, to, from, md, mgf1md, saltlen);
  }
  default:
    break;
  }
  if (ret == 1) {
    lua_pushlstring(L, (const char *)to, sz);
  } else {
    ret = openssl_pading_result(L, RSA_R_UNKNOWN_PADDING_TYPE);
  }
  OPENSSL_free(to);
  return ret;
}

/***
check and remove padding from data
@function padding_check
@tparam string data padded data to check
@tparam string padding padding mode to check
@tparam number size expected output size
@treturn string unpadded data or nil if padding check failed
*/
static int
openssl_padding_check(lua_State *L)
{
  size_t               l;
  const unsigned char *from = (const unsigned char *)luaL_checklstring(L, 1, &l);
  int                  padding = openssl_get_padding(L, 2, NULL);
  int                  sz = openssl_rsa_bytes_len(L, 3);
  unsigned char       *to = OPENSSL_malloc(sz);
  int                  ret = 0;

  switch (padding) {
  case RSA_PKCS1_PADDING: {
    int pri;
    luaL_checktype(L, 4, LUA_TBOOLEAN);
    pri = lua_toboolean(L, 4);

    /* true for private, false for public */
#ifdef LIBRESSL_VERSION_NUMBER
    /* NOTE: iibressl not compat with openssl */
    if (pri) {
      ret = RSA_padding_check_PKCS1_type_1(to, sz, from + 1, l - 1, sz);
    } else {
      ret = RSA_padding_check_PKCS1_type_2(to, sz, from + 1, l - 1, sz);
    }
#else
    if (pri) {
      ret = RSA_padding_check_PKCS1_type_1(to, sz, from, l, sz);
    } else {
      ret = RSA_padding_check_PKCS1_type_2(to, sz, from, l, sz);
    }
#endif
    break;
  }
#ifdef RSA_SSLV23_PADDING
#if !defined(LIBRESSL_VERSION_NUMBER) || LIBRESSL_VERSION_NUMBER < 0x3020000fL
  case RSA_SSLV23_PADDING:
    ret = RSA_padding_check_SSLv23(to, sz, from, l, sz);
    break;
#endif
#endif
  case RSA_PKCS1_OAEP_PADDING: {
    size_t               pl;
    const unsigned char *p = (const unsigned char *)luaL_optlstring(L, 4, NULL, &pl);
    if (lua_isnone(L, 5)) {
      ret = RSA_padding_check_PKCS1_OAEP(to, sz, from, l, sz, p, pl);
    } else {
      const EVP_MD *md = get_digest(L, 5, NULL);
      const EVP_MD *mgf1md = lua_isnone(L, 6) ? NULL : get_digest(L, 6, NULL);
      ret = RSA_padding_check_PKCS1_OAEP_mgf1(to, sz, from, l, sz, p, pl, md, mgf1md);
    }
    break;
  }
  case RSA_NO_PADDING:
    ret = RSA_padding_check_none(to, sz, from, l, sz);
    break;
#if !defined(LIBRESSL_VERSION_NUMBER) || LIBRESSL_VERSION_NUMBER < 0x30800000L
  case RSA_X931_PADDING:
    ret = RSA_padding_check_X931(to, sz, from, l, sz);
    break;
#endif
  case RSA_PKCS1_PSS_PADDING: {
    RSA          *rsa = CHECK_OBJECT(3, RSA, "openssl.rsa");
    const EVP_MD *md, *mgf1md;
    int           saltlen;

    luaL_argcheck(L, sz == RSA_size(rsa), 3, "padded data length mismatch with RSA size");
    OPENSSL_free(to);
    to = (unsigned char *)luaL_checklstring(L, 4, &l);

    md = get_digest(L, 5, NULL);
    mgf1md = lua_isnone(L, 6) ? NULL : get_digest(L, 6, NULL);
    saltlen = luaL_optinteger(L, 7, -2);
    luaL_argcheck(L, l == EVP_MD_size(md), 4, "unpadded data length mismatch with digest size");
    ret = RSA_verify_PKCS1_PSS_mgf1(rsa, to, md, mgf1md, from, saltlen);
    to = NULL;
  }
  default:
    break;
  }
  if (ret > 0) {
    if (to)
      lua_pushlstring(L, (const char *)to, ret);
    else
      lua_pushboolean(L, 1);
    ret = 1;
  } else {
    ret = openssl_pading_result(L, RSA_R_PADDING_CHECK_FAILED);
  }
  OPENSSL_free(to);
  return ret;
}

static luaL_Reg rsa_funs[] = {
  { "parse",      openssl_rsa_parse      },
  { "isprivate",  openssl_rsa_isprivate  },
  { "export",     openssl_rsa_export     },
  { "encrypt",    openssl_rsa_encrypt    },
  { "decrypt",    openssl_rsa_decrypt    },
  { "sign",       openssl_rsa_sign       },
  { "verify",     openssl_rsa_verify     },
  { "size",       openssl_rsa_size       },
  { "set_engine", openssl_rsa_set_engine },

  { "__gc",       openssl_rsa_free       },
  { "__tostring", auxiliar_tostring      },

  { NULL,         NULL                   }
};

static luaL_Reg R[] = {
  { "parse",         openssl_rsa_parse        },
  { "isprivate",     openssl_rsa_isprivate    },
  { "export",        openssl_rsa_export       },
  { "encrypt",       openssl_rsa_encrypt      },
  { "decrypt",       openssl_rsa_decrypt      },
  { "sign",          openssl_rsa_sign         },
  { "verify",        openssl_rsa_verify       },
  { "size",          openssl_rsa_size         },
  { "set_engine",    openssl_rsa_set_engine   },

  { "read",          openssl_rsa_read         },

  { "generate_key",  openssl_rsa_generate_key },

  { "padding_add",   openssl_padding_add      },
  { "padding_check", openssl_padding_check    },

  { NULL,            NULL                     }
};

int
luaopen_rsa(lua_State *L)
{
  auxiliar_newclass(L, "openssl.rsa", rsa_funs);
  lua_newtable(L);
  luaL_setfuncs(L, R, 0);

  return 1;
}

#if defined(__GNUC__) || defined(__clang__)
#pragma GCC diagnostic pop
#endif

#endif
