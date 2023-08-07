/*=========================================================================*\
* misc.h
* misc routines for lua-openssl binding
*
* Author:  george zhao <zhaozg(at)gmail.com>
\*=========================================================================*/
#include "openssl.h"
#include "private.h"
const char* format[] =
{
  "auto",
  "der",
  "pem",
  "smime",
  NULL
};

BIO* load_bio_object(lua_State* L, int idx)
{
  BIO* bio = NULL;
  if (lua_isstring(L, idx))
  {
    size_t l = 0;
    const char* ctx = lua_tolstring(L, idx, &l);
    /* read only */
    bio = (BIO*)BIO_new_mem_buf((void*)ctx, l);
  }
  else if (auxiliar_getclassudata(L, "openssl.bio", idx))
  {
    bio = CHECK_OBJECT(idx, BIO, "openssl.bio");
    BIO_up_ref(bio);
  }
  else
    luaL_argerror(L, idx, "only support string or openssl.bio");
  return bio;
}

int  bio_is_der(BIO* bio)
{
  byte head[1];
  int len = BIO_read(bio, head, sizeof(head));
  (void)BIO_reset(bio);
  if (len == sizeof(head) && head[0] == 0x30)
    return 1;

  return 0;
}

const EVP_MD* opt_digest(lua_State* L, int idx, const char* alg)
{
  const EVP_MD* md = NULL;
  switch (lua_type(L, idx))
  {
  case LUA_TSTRING:
    md = EVP_get_digestbyname(lua_tostring(L, idx));
    break;
  case LUA_TNUMBER:
    md = EVP_get_digestbynid(lua_tointeger(L, idx));
    break;
  case LUA_TUSERDATA:
    if (auxiliar_getclassudata(L, "openssl.asn1_object", idx))
      md = EVP_get_digestbyobj(CHECK_OBJECT(idx, ASN1_OBJECT, "openssl.asn1_object"));
    else if (auxiliar_getclassudata(L, "openssl.evp_digest", idx))
      md = CHECK_OBJECT(idx, EVP_MD, "openssl.evp_digest");
    break;
  case LUA_TNONE:
  case LUA_TNIL:
    if (alg != NULL)
      md = EVP_get_digestbyname(alg);
    break;
  }

  if (alg != NULL && md==NULL)
  {
    luaL_argerror(L, idx, "must be a string, NID number or asn1_object identity digest method");
  }

  return md;
}

const EVP_MD* get_digest(lua_State* L, int idx, const char* alg)
{
  const EVP_MD* md = opt_digest(L, idx, alg);
  if (md == NULL)
    luaL_argerror(L, idx, "must be a string, NID number or asn1_object identity digest method");
  return md;
}

const EVP_CIPHER* opt_cipher(lua_State*L, int idx, const char* alg)
{
  const EVP_CIPHER* cipher = NULL;

  switch (lua_type(L, idx))
  {
  case LUA_TSTRING:
    cipher = EVP_get_cipherbyname(lua_tostring(L, idx));
    break;
  case LUA_TNUMBER:
    cipher = EVP_get_cipherbynid(lua_tointeger(L, idx));
    break;
  case LUA_TUSERDATA:
    if (auxiliar_getclassudata(L, "openssl.asn1_object", idx))
      cipher = EVP_get_cipherbyobj(CHECK_OBJECT(idx, ASN1_OBJECT, "openssl.asn1_object"));
    else if (auxiliar_getclassudata(L, "openssl.evp_cipher", idx))
      cipher = CHECK_OBJECT(idx, EVP_CIPHER, "openssl.evp_cipher");
    break;
  case LUA_TNONE:
  case LUA_TNIL:
    if (alg != NULL)
      cipher = EVP_get_cipherbyname(alg);
    break;
  }

  if (alg != NULL && cipher==NULL)
    luaL_argerror(L, idx, "must be a string, NID number or asn1_object identity cipher method");

  return cipher;
}

const EVP_CIPHER* get_cipher(lua_State*L, int idx, const char* alg)
{
  const EVP_CIPHER* c = opt_cipher(L, idx, alg);
  if (c==NULL)
    luaL_argerror(L, idx, "must be a string, NID number or asn1_object identity cipher method");
  return c;
}

BIGNUM *BN_get(lua_State *L, int i)
{
  BIGNUM *x = BN_new();
  switch (lua_type(L, i))
  {
  case LUA_TNUMBER:
    BN_set_word(x, lua_tointeger(L, i));
    break;
  case LUA_TSTRING:
  {
    const char *s = lua_tostring(L, i);
    if (s[0] == 'X' || s[0] == 'x') BN_hex2bn(&x, s + 1);
    else BN_dec2bn(&x, s);
    break;
  }
  case LUA_TUSERDATA:
    BN_copy(x, CHECK_OBJECT(i, BIGNUM, "openssl.bn"));
    break;
  case LUA_TNIL:
    BN_free(x);
    x = NULL;
    break;
  }
  return x;
}

void openssl_add_method_or_alias(const OBJ_NAME *name, void *arg)
{
  lua_State *L = (lua_State *)arg;
  int i = lua_rawlen(L, -1);
  lua_pushstring(L, name->name);
  lua_rawseti(L, -2, i + 1);
}

void openssl_add_method(const OBJ_NAME *name, void *arg)
{
  if (name->alias == 0)
  {
    openssl_add_method_or_alias(name, arg);
  }
}

int openssl_pushresult(lua_State*L, int result)
{
  if (result >= 1)
  {
    lua_pushboolean(L, 1);
    return 1;
  }
  else
  {
    unsigned long val = ERR_get_error();
    lua_pushnil(L);
    if (val)
    {
      lua_pushstring(L, ERR_reason_error_string(val));
      lua_pushinteger(L, val);
    }
    else
    {
      lua_pushstring(L, "UNKNOWN ERROR");
      lua_pushnil(L);
    }
    return 3;
  }
}

static const char* hex_tab = "0123456789abcdef";

void to_hex(const char* in, int length, char* out)
{
  int i;
  for (i = 0; i < length; i++)
  {
    out[i * 2] = hex_tab[(in[i] >> 4) & 0xF];
    out[i * 2 + 1] = hex_tab[(in[i]) & 0xF];
  }
  out[i * 2] = '\0';
}

int openssl_push_bit_string_bitname(lua_State* L, const BIT_STRING_BITNAME* name)
{
  lua_newtable(L);
  lua_pushinteger(L, name->bitnum);
  lua_setfield(L, -2, "bitnum");
  lua_pushstring(L, name->lname);
  lua_setfield(L, -2, "lname");
  lua_pushstring(L, name->sname);
  lua_setfield(L, -2, "sname");
  return 1;
}

static const char* sPadding[] =
{
  "pkcs1",
#ifdef RSA_SSLV23_PADDING
#if !defined(LIBRESSL_VERSION_NUMBER) || LIBRESSL_VERSION_NUMBER < 0x3020000fL
  "sslv23",
#endif
#endif
  "no",
  "oaep",
  "x931",
  "pss",
  NULL,
};

static int iPadding[] =
{
  RSA_PKCS1_PADDING,
#ifdef RSA_SSLV23_PADDING
#if !defined(LIBRESSL_VERSION_NUMBER) || LIBRESSL_VERSION_NUMBER < 0x3020000fL
  RSA_SSLV23_PADDING,
#endif
#endif
  RSA_NO_PADDING,
  RSA_PKCS1_OAEP_PADDING,
  RSA_X931_PADDING,
  RSA_PKCS1_PSS_PADDING
};

int openssl_get_padding(lua_State *L, int idx, const char *defval)
{
  return auxiliar_checkoption(L, idx, defval, sPadding, iPadding);
}

size_t posrelat(ptrdiff_t pos, size_t len)
{
  if (pos >= 0) return (size_t)pos;
  else if (0u - (size_t)pos > len) return 0;
  else return len - ((size_t) - pos) + 1;
}

static const char hex[] = { '0', '1', '2', '3', '4', '5', '6', '7',
                            '8', '9', 'a', 'b', 'c', 'd', 'e', 'f'
                          };
static const char bin[256] =
{
  /*       0, 1, 2, 3, 4, 5, 6, 7, 8, 9, a, b, c, d, e, f */
  /* 00 */ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  /* 10 */ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  /* 20 */ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  /* 30 */ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0, 0, 0, 0, 0, 0,
  /* 40 */ 0, 10, 11, 12, 13, 14, 15, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  /* 50 */ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  /* 60 */ 0, 10, 11, 12, 13, 14, 15, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  /* 70 */ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  /* 80 */ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  /* 90 */ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  /* a0 */ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  /* b0 */ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  /* c0 */ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  /* d0 */ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  /* e0 */ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
  /* f0 */ 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
};

int hex2bin(const char * src, unsigned char *dst, int len)
{
  int i;
  if (len == 0) len = strlen(src);
  for (i = 0; i < len; i += 2)
  {
    unsigned char h = src[i];
    unsigned char l = src[i + 1];
    dst[i / 2] = bin[h] << 4 | bin[l];
  }
  return i / 2;
}
int bin2hex(const unsigned char * src, char *dst, int len)
{
  int i;
  for (i = 0; i < len; i++)
  {
    unsigned char c = src[i];
    dst[i * 2] = hex[c >> 4];
    dst[i * 2 + 1] = hex[c & 0xf];
  }
  dst[i * 2] = '\0';
  return i * 2;
}

int openssl_pusherror (lua_State *L, const char *fmt, ...)
{
  va_list argp;
  va_start(argp, fmt);
  luaL_where(L, 1);
  lua_pushvfstring(L, fmt, argp);
  va_end(argp);
  lua_concat(L, 2);
  return 1;
}

int openssl_pushargerror (lua_State *L, int arg, const char *extramsg)
{
  lua_Debug ar;
  const char* name;

  if (lua_getstack(L, 0, &ar))  /* have stack frame? */
  {
    lua_getinfo(L, "n", &ar);
    if (strcmp(ar.namewhat, "method") == 0)
    {
      arg--;
      /* do not count 'self' */
      if (arg == 0)  /* error is in the self argument itself? */
        return openssl_pusherror(L, "calling '%s' on bad self (%s)",
                                 ar.name, extramsg);
    }
    if (ar.name == NULL)
#if defined(COMPAT53_C_) || LUA_VERSION_NUM != 502
      name = "?";
#else
      name = (compat53_pushglobalfuncname(L, &ar)) ? lua_tostring(L, -1) : "?";
#endif
  }

  return openssl_pusherror(L, "bad argument #%d to '%s' (%s)",
                           arg, name, extramsg);
}
