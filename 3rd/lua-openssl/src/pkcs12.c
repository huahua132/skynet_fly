/***
pkcs12 module to create and parse PKCS#12(PFX) files.

@module pkcs12
@usage
  pkcs12 = require('openssl').pkcs12
*/

#include "openssl.h"
#include "private.h"

/***
create and export pkcs12 data

@function export
@tparam x509 cert
@tparam evp_pkey pkey
@tparam string password
@tparam[opt=nil] string friendlyname
@tparam[opt] table|stak_of_x509 extracerts
@tparam[opt] boolean keytype flag to private key used by MSIE, true for KEY_SIG, or KEY_EX
@treturn string data
*/
static LUA_FUNCTION(openssl_pkcs12_export)
{
  X509 * cert = CHECK_OBJECT(1, X509, "openssl.x509");
  EVP_PKEY *priv_key = CHECK_OBJECT(2, EVP_PKEY, "openssl.evp_pkey");
  char * pass = (char*)luaL_checkstring(L, 3);
  int keytype = 0;
  int top = lua_gettop(L);

  BIO * bio_out = NULL;
  PKCS12 * p12 = NULL;
  const char * friendly_name = NULL;
  STACK_OF(X509) *ca = NULL;
  int ret = 0;

  luaL_argcheck(L, openssl_pkey_is_private(priv_key), 2, "must be private key");

  if (top > 3)
  {
    int idx = 4;
    if (lua_isstring(L, idx))
    {
      friendly_name = lua_tostring(L, idx);
      idx++;
    }

    if (lua_istable(L, idx))
    {
      ca = openssl_sk_x509_fromtable(L, idx);
      if (ca == NULL)
        luaL_argerror(L, idx, "must be table contians x509 object as cacets");
      idx++;
    }

    if (lua_isboolean(L, idx))
    {
      keytype = lua_toboolean(L, idx) ? KEY_SIG : KEY_EX;
    }
  }

  if (cert && !X509_check_private_key(cert, priv_key))
  {
    luaL_error(L, "private key does not correspond to cert");
  }

  /* end parse extra config */

  /*
   * PKCS12 *PKCS12_create(char *pass,
   *                       char *name,
   *                       EVP_PKEY *pkey,
   *                       X509 *cert,
   *                       STACK_OF(X509) *ca,
   *                       int nid_key,
   *                       int nid_cert,
   *                       int iter,
   *                       int mac_iter,
   *                       int keytype);
   */

  p12 = PKCS12_create(pass, (char*)friendly_name, priv_key, cert, ca, NID_aes_128_cbc, 0, 0, 0, keytype);
  if (!p12)
    luaL_error(L, "PKCS12_create failed,pleases get more error info");

  bio_out = BIO_new(BIO_s_mem());
  if (i2d_PKCS12_bio(bio_out, p12))
  {
    BUF_MEM *bio_buf;

    BIO_get_mem_ptr(bio_out, &bio_buf);
    lua_pushlstring(L, bio_buf->data, bio_buf->length);
    ret = 1;
  }
  if (ca!=NULL)
    sk_X509_pop_free(ca, X509_free);
  BIO_free(bio_out);
  PKCS12_free(p12);

  return ret;
}

/***
parse pkcs12 data as lua table

@function read
@tparam string|bio input pkcs12 content
@tparam string password for pkcs12
@treturn table result contain 'cert', 'pkey', 'extracerts' keys
*/
static LUA_FUNCTION(openssl_pkcs12_read)
{
  PKCS12 * p12 = NULL;
  EVP_PKEY * pkey = NULL;
  X509 * cert = NULL;
  STACK_OF(X509) * ca = NULL;
  int ret = 0;

  BIO * bio_in = load_bio_object(L, 1);
  const char *pass = luaL_checkstring(L, 2);

  if (d2i_PKCS12_bio(bio_in, &p12) && PKCS12_parse(p12, pass, &pkey, &cert, &ca))
  {
    lua_newtable(L);

    AUXILIAR_SETOBJECT(L, cert, "openssl.x509", -1, "cert");
    AUXILIAR_SETOBJECT(L, pkey, "openssl.evp_pkey", -1, "pkey");
    if (ca != NULL) {
      lua_pushstring(L, "extracerts");
      openssl_sk_x509_totable(L, ca);
      lua_rawset(L, -3);
      sk_X509_pop_free(ca, X509_free);
    }

    ret = 1;
  }
  BIO_free(bio_in);
  PKCS12_free(p12);
  return ret;
}

static luaL_Reg R[] =
{
  {"read",    openssl_pkcs12_read },
  {"export",  openssl_pkcs12_export },

  {NULL,    NULL}
};

int luaopen_pkcs12(lua_State *L)
{
  lua_newtable(L);
  luaL_setfuncs(L, R, 0);

  return 1;
}
