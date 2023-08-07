/*=========================================================================*\
* ec.c
* RSA routines for lua-openssl binding
*
* Author:  george zhao <zhaozg(at)gmail.com>
\*=========================================================================*/
#include "openssl.h"
#include "private.h"
#include <openssl/rsa.h>
#include <openssl/engine.h>

#if !defined(OPENSSL_NO_RSA)
static LUA_FUNCTION(openssl_rsa_free)
{
  RSA* rsa = CHECK_OBJECT(1, RSA, "openssl.rsa");
  RSA_free(rsa);
  return 0;
};

static int is_private(const RSA* rsa)
{
  const BIGNUM* d = NULL;
  RSA_get0_key(rsa, NULL, NULL, &d);
  return d != NULL && !BN_is_zero(d);
};

static LUA_FUNCTION(openssl_rsa_isprivate)
{
  RSA* rsa = CHECK_OBJECT(1, RSA, "openssl.rsa");
  lua_pushboolean(L, is_private(rsa));
  return 1;
};

static LUA_FUNCTION(openssl_rsa_size)
{
  RSA* rsa = CHECK_OBJECT(1, RSA, "openssl.rsa");
  lua_pushinteger(L, RSA_size(rsa));
  return 1;
};

static LUA_FUNCTION(openssl_rsa_encrypt)
{
  RSA* rsa = CHECK_OBJECT(1, RSA, "openssl.rsa");
  size_t l;
  const unsigned char* from = (const unsigned char *)luaL_checklstring(L, 2, &l);
  int padding = openssl_get_padding(L, 3, "pkcs1");
  int ispriv = lua_isnone(L, 4) ? is_private(rsa) : lua_toboolean(L, 4);
  unsigned char* to = OPENSSL_malloc(RSA_size(rsa));
  int flen = l;

  flen = ispriv
         ? RSA_private_encrypt(flen, from, to, rsa, padding)
         : RSA_public_encrypt(flen, from, to, rsa, padding);
  if (flen > 0)
  {
    lua_pushlstring(L, (const char*)to, flen);
    flen = 1;
  }
  OPENSSL_free(to);
  return flen == 1 ? flen : openssl_pushresult(L, flen);
};

static LUA_FUNCTION(openssl_rsa_decrypt)
{
  RSA* rsa = CHECK_OBJECT(1, RSA, "openssl.rsa");
  size_t l;
  const unsigned char* from = (const unsigned char *) luaL_checklstring(L, 2, &l);
  int padding = openssl_get_padding(L, 3, "pkcs1");
  int ispriv = lua_isnone(L, 4) ? is_private(rsa) : lua_toboolean(L, 4);
  unsigned char* to = OPENSSL_malloc(RSA_size(rsa));
  int flen = l;

  flen = ispriv
         ? RSA_private_decrypt(flen, from, to, rsa, padding)
         : RSA_public_decrypt(flen, from, to, rsa, padding);
  if (flen > 0)
  {
    lua_pushlstring(L, (const char*)to, flen);
    flen = 1;
  }
  OPENSSL_free(to);
  return flen == 1 ? flen : openssl_pushresult(L, flen);
};

static LUA_FUNCTION(openssl_rsa_sign)
{
  RSA* rsa = CHECK_OBJECT(1, RSA, "openssl.rsa");
  size_t l;
  const unsigned char* msg = (const unsigned char *)luaL_checklstring(L, 2, &l);
  const EVP_MD* md = get_digest(L, 3, "sha256");
  unsigned char* sig = OPENSSL_malloc(RSA_size(rsa));
  int flen = l;
  unsigned int slen = RSA_size(rsa);

  int ret = RSA_sign(EVP_MD_type(md), msg, flen, sig, &slen, rsa);
  if (ret == 1)
  {
    lua_pushlstring(L, (const char*)sig, slen);
  }
  OPENSSL_free(sig);
  return ret == 1 ? ret: openssl_pushresult(L, ret);
};

static LUA_FUNCTION(openssl_rsa_verify)
{
  RSA* rsa = CHECK_OBJECT(1, RSA, "openssl.rsa");
  size_t l;
  const unsigned char* from = (const unsigned char *)luaL_checklstring(L, 2, &l);
  size_t s;
  const unsigned char* sig = (const unsigned char *)luaL_checklstring(L, 3, &s);
  const EVP_MD* md = get_digest(L, 4, "sha256");
  int flen = l;
  int slen = s;

  int ret = RSA_verify(EVP_MD_type(md), from, flen, sig, slen, rsa);
  lua_pushboolean(L, ret);
  return 1;
};

static LUA_FUNCTION(openssl_rsa_parse)
{
  const BIGNUM *n = NULL, *e = NULL, *d = NULL;
  const BIGNUM *p = NULL, *q = NULL;
  const BIGNUM *dmp1 = NULL, *dmq1 = NULL, *iqmp = NULL;

  RSA* rsa = CHECK_OBJECT(1, RSA, "openssl.rsa");
  RSA_get0_key(rsa, &n, &e, &d);
  RSA_get0_factors(rsa, &p, &q);
  RSA_get0_crt_params(rsa, &dmp1, &dmq1, &iqmp);


  lua_newtable(L);
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
  return 1;
}

static LUA_FUNCTION(openssl_rsa_read)
{
  size_t l;
  const char* data = luaL_checklstring(L, 1, &l);
  int ispriv = lua_isnone(L, 2) ? 1 : lua_toboolean(L, 2);
  const unsigned char* in = (const unsigned char*)data;
  RSA *rsa = ispriv ? d2i_RSAPrivateKey(NULL, &in, l)
                    : d2i_RSA_PUBKEY(NULL, &in, l);
  int ret = 0;

  if (rsa)
  {
    PUSH_OBJECT(rsa, "openssl.rsa");
    ret = 1;
  }
  return ret;
}

static LUA_FUNCTION(openssl_rsa_export)
{
  RSA* rsa = CHECK_OBJECT(1, RSA, "openssl.rsa");
  int ispriv = lua_isnone(L, 2) ? is_private(rsa) : lua_toboolean(L, 2);
  BIO* out = BIO_new(BIO_s_mem());

  int ret = 0;
  int len = ispriv ? i2d_RSAPrivateKey_bio(out, rsa)
            : i2d_RSA_PUBKEY_bio(out, rsa);

  if (len>0)
  {
    char * bio_mem_ptr;
    long bio_mem_len;

    bio_mem_len = BIO_get_mem_data(out, &bio_mem_ptr);

    lua_pushlstring(L, bio_mem_ptr, bio_mem_len);
    ret  = 1;
  }
  BIO_free(out);
  return ret;
}

static int openssl_rsa_set_engine(lua_State *L)
{
  int ret = 0;
#ifndef OPENSSL_NO_ENGINE
  RSA* rsa = CHECK_OBJECT(1, RSA, "openssl.rsa");
  ENGINE *e = CHECK_OBJECT(2, ENGINE, "openssl.engine");
  const RSA_METHOD *m = ENGINE_get_RSA(e);
  if (m)
  {
    ret = RSA_set_method(rsa, m);
    ret = openssl_pushresult(L, ret);
  }
#endif
  return ret;
}

static int openssl_rsa_generate_key(lua_State *L)
{
  int bits = luaL_optint(L, 1, 2048);
  int e = luaL_optint(L, 2, 65537);
  ENGINE *eng = lua_isnoneornil(L, 3) ? NULL : CHECK_OBJECT(3, ENGINE, "openssl.engine");
  int ret = 0;

  BIGNUM *E = BN_new();
  RSA *rsa = eng ? RSA_new_method(eng) : RSA_new();
  BN_set_word(E, e);

  ret = RSA_generate_key_ex(rsa, bits, E, NULL);
  if (ret==1)
  {
    PUSH_OBJECT(rsa, "openssl.rsa");
  }
  else
  {
    RSA_free(rsa);
    ret = 0;
  }

  BN_free(E);
  return ret;
}

static int openssl_pading_result(lua_State*L, unsigned long val)
{
  int ret = 1;
  lua_pushnil(L);
  if (val)
  {
    lua_pushstring(L, ERR_reason_error_string(val));
    lua_pushinteger(L, val);
    ret += 2;
  }
  return ret;
}

static int openssl_rsa_bytes_len(lua_State *L, int i)
{
  int n;
  if (lua_isnumber(L, i))
  {
    n = luaL_checkinteger(L, i);
    luaL_argcheck(L, n > 0, i, "n must be positive");
  }
  else
  {
    RSA* rsa = CHECK_OBJECT(i, RSA, "openssl.rsa");
    n = RSA_size(rsa);
  }
  return n;
}

static int openssl_padding_add(lua_State *L)
{
  size_t l;
  const unsigned char* from = (const unsigned char *) luaL_checklstring(L, 1, &l);
  int padding = openssl_get_padding(L, 2, NULL);
  int sz = openssl_rsa_bytes_len(L, 3);
  unsigned char* to = OPENSSL_malloc(sz);
  int ret = 0;

  switch(padding)
  {
  case RSA_PKCS1_PADDING:
  {
    int pri;
    luaL_checktype(L, 4, LUA_TBOOLEAN);
    pri = lua_toboolean(L, 4);

    /* true for private, false for public */
    if (pri)
    {
      ret = RSA_padding_add_PKCS1_type_1(to, sz,from, l);
    }
    else
    {
      ret = RSA_padding_add_PKCS1_type_2(to, sz,from, l);
    }

    break;
  }
#ifdef RSA_SSLV23_PADDING
#if !defined(LIBRESSL_VERSION_NUMBER) || LIBRESSL_VERSION_NUMBER < 0x3020000fL
  case RSA_SSLV23_PADDING:
    ret = RSA_padding_add_SSLv23(to, sz,from, l);
    break;
#endif
#endif
  case RSA_NO_PADDING:
    ret = RSA_padding_add_none(to, sz,from, l);
    break;
  case RSA_PKCS1_OAEP_PADDING:
  {
    size_t pl;
    const unsigned char* p = (const unsigned char *) luaL_optlstring(L, 4, NULL, &pl);
    if (lua_isnone(L, 5))
    {
      ret = RSA_padding_add_PKCS1_OAEP(to, sz,from, l, p, pl);
    }
    else
    {
      const EVP_MD *md = get_digest(L, 5, NULL);
      const EVP_MD *mgf1md = lua_isnone(L, 6) ? NULL : get_digest(L, 6, NULL);
      ret = RSA_padding_add_PKCS1_OAEP_mgf1(to, sz,from, l, p, pl, md, mgf1md);
    }
    break;
  }
  case RSA_X931_PADDING:
    ret = RSA_padding_add_X931(to, sz, from, l);
    break;
#if OPENSSL_VERSION_NUMBER > 0x10000000L
  case RSA_PKCS1_PSS_PADDING:
  {
    RSA* rsa = CHECK_OBJECT(3, RSA, "openssl.rsa");
    const EVP_MD *md = get_digest(L, 4, NULL);
    const EVP_MD *mgf1md = lua_isnone(L, 5) ? NULL : get_digest(L, 5, NULL);
    int saltlen = luaL_optinteger(L, 6, -2);
    luaL_argcheck(L, l == EVP_MD_size(md), 4, "data length to pad mismatch with digest size");

    ret = RSA_padding_add_PKCS1_PSS_mgf1(rsa, to, from, md, mgf1md, saltlen);
  }
#endif
  default:
    break;
  }
  if (ret==1)
  {
    lua_pushlstring(L, (const char*)to, sz);
  }
  else
  {
    ret = openssl_pading_result(L, RSA_R_UNKNOWN_PADDING_TYPE);
  }
  OPENSSL_free(to);
  return ret;
}

static int openssl_padding_check(lua_State *L)
{
  size_t l;
  const unsigned char* from = (const unsigned char *) luaL_checklstring(L, 1, &l);
  int padding = openssl_get_padding(L, 2, NULL);
  int sz = openssl_rsa_bytes_len(L, 3);
  unsigned char* to = OPENSSL_malloc(sz);
  int ret = 0;

  switch(padding)
  {
  case RSA_PKCS1_PADDING:
  {
    int pri;
    luaL_checktype(L, 4, LUA_TBOOLEAN);
    pri = lua_toboolean(L, 4);

    /* true for private, false for public */
    if (pri)
    {
      ret = RSA_padding_check_PKCS1_type_1(to, sz, from, l, sz);
    }
    else
    {
      ret = RSA_padding_check_PKCS1_type_2(to, sz, from, l, sz);
    }
    break;
  }
#ifdef RSA_SSLV23_PADDING
#if !defined(LIBRESSL_VERSION_NUMBER) || LIBRESSL_VERSION_NUMBER < 0x3020000fL
  case RSA_SSLV23_PADDING:
    ret = RSA_padding_check_SSLv23(to, sz, from, l, sz);
    break;
#endif
#endif
  case RSA_PKCS1_OAEP_PADDING:
  {
    size_t pl;
    const unsigned char* p = (const unsigned char *) luaL_optlstring(L, 4, NULL, &pl);
    if (lua_isnone(L, 5))
    {
      ret = RSA_padding_check_PKCS1_OAEP(to, sz,from, l, sz, p, pl);
    }
    else
    {
      const EVP_MD *md = get_digest(L, 5, NULL);
      const EVP_MD *mgf1md = lua_isnone(L, 6) ? NULL : get_digest(L, 6, NULL);
      ret = RSA_padding_check_PKCS1_OAEP_mgf1(to, sz,from, l, sz, p, pl, md, mgf1md);
    }
    break;
  }
  case RSA_NO_PADDING:
    ret = RSA_padding_check_none(to, sz, from, l, sz);
    break;
  case RSA_X931_PADDING:
    ret = RSA_padding_check_X931(to, sz, from, l, sz);
    break;
#if OPENSSL_VERSION_NUMBER > 0x10000000L
  case RSA_PKCS1_PSS_PADDING:
  {
    RSA* rsa = CHECK_OBJECT(3, RSA, "openssl.rsa");
    const EVP_MD *md, *mgf1md;
    int saltlen;

    luaL_argcheck(L, sz == RSA_size(rsa), 3, "padded data length mismatch with RSA size");
    OPENSSL_free(to);
    to = (unsigned char*)luaL_checklstring(L, 4, &l);

    md = get_digest(L, 5, NULL);
    mgf1md = lua_isnone(L, 6) ? NULL : get_digest(L, 6, NULL);
    saltlen = luaL_optinteger(L, 7, -2);
    luaL_argcheck(L, l == EVP_MD_size(md), 4, "unpadded data length mismatch with digest size");
    ret = RSA_verify_PKCS1_PSS_mgf1(rsa, to, md, mgf1md, from, saltlen);
    to = NULL;
  }
#endif
  default:
    break;
  }
  if (ret>0)
  {
    if (to)
      lua_pushlstring(L, (const char*)to, ret);
    else
      lua_pushboolean(L, 1);
    ret = 1;
  }
  else
  {
    ret = openssl_pading_result(L, RSA_R_PADDING_CHECK_FAILED);
  }
  OPENSSL_free(to);
  return ret;
}

static luaL_Reg rsa_funs[] =
{
  {"parse",       openssl_rsa_parse},
  {"isprivate",   openssl_rsa_isprivate},
  {"export",      openssl_rsa_export},
  {"encrypt",     openssl_rsa_encrypt},
  {"decrypt",     openssl_rsa_decrypt},
  {"sign",        openssl_rsa_sign},
  {"verify",      openssl_rsa_verify},
  {"size",        openssl_rsa_size},
  {"set_engine",  openssl_rsa_set_engine},

  {"__gc",        openssl_rsa_free},
  {"__tostring",  auxiliar_tostring},

  { NULL, NULL }
};

static luaL_Reg R[] =
{
  {"parse",       openssl_rsa_parse},
  {"isprivate",   openssl_rsa_isprivate},
  {"export",      openssl_rsa_export},
  {"encrypt",     openssl_rsa_encrypt},
  {"decrypt",     openssl_rsa_decrypt},
  {"sign",        openssl_rsa_sign},
  {"verify",      openssl_rsa_verify},
  {"size",        openssl_rsa_size},
  {"set_engine",  openssl_rsa_set_engine},

  {"read",        openssl_rsa_read},

  {"generate_key", openssl_rsa_generate_key},

  {"padding_add",   openssl_padding_add},
  {"padding_check", openssl_padding_check},

  {NULL, NULL}
};

int luaopen_rsa(lua_State *L)
{
  auxiliar_newclass(L, "openssl.rsa",     rsa_funs);
  lua_newtable(L);
  luaL_setfuncs(L, R, 0);

  return 1;
}
#endif
