/***
x509 modules to create, parse, process X509 objects, sign CSR.

@module x509
@usage
 x509 = require'openssl'.x509
*/


#include "openssl.h"
#include "private.h"
#define CRYPTO_LOCK_REF
#include "sk.h"

#if OPENSSL_VERSION_NUMBER < 0x1010000fL || \
	(defined(LIBRESSL_VERSION_NUMBER) && (LIBRESSL_VERSION_NUMBER < 0x20700000L))
#define X509_get0_notBefore X509_get_notBefore
#define X509_get0_notAfter X509_get_notAfter
#define X509_set1_notBefore X509_set_notBefore
#define X509_set1_notAfter X509_set_notAfter
#endif

static int openssl_push_purpose(lua_State*L, X509_PURPOSE* purpose)
{
  lua_newtable(L);

  AUXILIAR_SET(L, -1, "purpose", purpose->purpose, integer);
  AUXILIAR_SET(L, -1, "trust", purpose->trust, integer);
  AUXILIAR_SET(L, -1, "flags", purpose->flags, integer);

  AUXILIAR_SET(L, -1, "name", purpose->name, string);
  AUXILIAR_SET(L, -1, "sname", purpose->sname, string);

  return 1;
};

/***
return all supported purpose as table
@function purpose
@treturn table
*/
/*
get special purpose info as table
@function purpose
@tparam number|string purpose id or short name
@treturn table
*/
static int openssl_x509_purpose(lua_State*L)
{
  int ret = lua_type(L, 1);

  luaL_argcheck(L,
                ret==LUA_TNONE || ret==LUA_TNUMBER || ret==LUA_TSTRING,
                1,
                "only accpet NONE, string or number as nid or short name");

  ret = 0;
  if (lua_isnone(L, 1))
  {
    int count = X509_PURPOSE_get_count();
    int i;
    lua_newtable(L);
    for (i = 0; i < count; i++)
    {
      X509_PURPOSE* purpose = X509_PURPOSE_get0(i);
      openssl_push_purpose(L, purpose);
      lua_rawseti(L, -2, i + 1);
    }
    ret = 1;
  }
  else if (lua_isnumber(L, 1))
  {
    int idx = X509_PURPOSE_get_by_id(lua_tointeger(L, 1));
    if (idx >= 0)
    {
      X509_PURPOSE* purpose = X509_PURPOSE_get0(idx);
      openssl_push_purpose(L, purpose);
      ret = 1;
    }
  }
  else if (lua_isstring(L, 1))
  {
    char* name = (char*)lua_tostring(L, 1);
    int idx = X509_PURPOSE_get_by_sname(name);
    if (idx >= 0)
    {
      X509_PURPOSE* purpose = X509_PURPOSE_get0(idx);
      openssl_push_purpose(L, purpose);
      ret = 1;
    }
  }

  return ret;
};

static const char* usage_mode[] =
{
  "standard",
  "netscape",
  "extend",
  NULL
};

/***
get support certtypes
@function certtypes
@tparam[opt='standard'] string type support 'standard','netscape','extend'
@treturn table if type is 'standard' or 'netscape', contains node with {lname=...,sname=...,bitname=...},
               if type is 'extend', contains node with {lname=...,sname=...,nid=...}
*/
static int openssl_x509_certtypes(lua_State*L)
{
  int mode = luaL_checkoption(L, 1, "standard", usage_mode);
  int i, ret=0;
  const BIT_STRING_BITNAME* bitname;

  switch (mode)
  {
  case 0:
  {
    const static BIT_STRING_BITNAME key_usage_type_table[] =
    {
      {0, "Digital Signature", "digitalSignature"},
      {1, "Non Repudiation", "nonRepudiation"},
      {2, "Key Encipherment", "keyEncipherment"},
      {3, "Data Encipherment", "dataEncipherment"},
      {4, "Key Agreement", "keyAgreement"},
      {5, "Certificate Sign", "keyCertSign"},
      {6, "CRL Sign", "cRLSign"},
      {7, "Encipher Only", "encipherOnly"},
      {8, "Decipher Only", "decipherOnly"},
      { -1, NULL, NULL}
    };
    lua_newtable(L);
    for (i = 0, bitname = &key_usage_type_table[i]; bitname->bitnum != -1; i++, bitname = &key_usage_type_table[i])
    {
      openssl_push_bit_string_bitname(L, bitname);
      lua_rawseti(L, -2, i + 1);
    }
    ret = 1;
  }
  case 1:
  {
    const static BIT_STRING_BITNAME ns_cert_type_table[] =
    {
      {0, "SSL Client", "client"},
      {1, "SSL Server", "server"},
      {2, "S/MIME", "email"},
      {3, "Object Signing", "objsign"},
      {4, "Unused", "reserved"},
      {5, "SSL CA", "sslCA"},
      {6, "S/MIME CA", "emailCA"},
      {7, "Object Signing CA", "objCA"},
      { -1, NULL, NULL}
    };
    lua_newtable(L);
    for (i = 0, bitname = &ns_cert_type_table[i]; bitname->bitnum != -1; i++, bitname = &ns_cert_type_table[i])
    {
      openssl_push_bit_string_bitname(L, bitname);
      lua_rawseti(L, -2, i + 1);
    }
    ret = 1;
  }
  case 2:
  {
    static const int ext_nids[] =
    {
      NID_server_auth,
      NID_client_auth,
      NID_email_protect,
      NID_code_sign,
      NID_ms_sgc,
      NID_ns_sgc,
      NID_OCSP_sign,
      NID_time_stamp,
      NID_dvcs,
      NID_anyExtendedKeyUsage
    };
    int count = sizeof(ext_nids) / sizeof(int);
    int nid;
    lua_newtable(L);
    for (i = 0; i < count; i++)
    {
      nid = ext_nids[i];
      lua_newtable(L);
      lua_pushstring(L, OBJ_nid2ln(nid));
      lua_setfield(L, -2, "lname");
      lua_pushstring(L, OBJ_nid2sn(nid));
      lua_setfield(L, -2, "sname");
      lua_pushinteger(L, nid);
      lua_setfield(L, -2, "nid");
      lua_rawseti(L, -2, i + 1);
    };
    ret = 1;
  }
  }
  return ret;
}

/***
get certificate verify result string message
@function verify_cert_error_string
@tparam number verify_result
@treturn string result message
*/
static int openssl_verify_cert_error_string(lua_State*L)
{
  int v = luaL_checkint(L, 1);
  const char*s = X509_verify_cert_error_string(v);
  lua_pushstring(L, s);
  return 1;
}

/***
read x509 from string or bio input
@function read
@tparam bio|string input input data
@tparam[opt='auto'] string format support 'auto','pem','der'
@treturn x509 certificate object
*/
static LUA_FUNCTION(openssl_x509_read)
{
  X509 *cert = NULL;
  BIO *in = load_bio_object(L, 1);
  int fmt = luaL_checkoption(L, 2, "auto", format);
  int ret = 0;

  if (fmt == FORMAT_AUTO)
  {
    fmt = bio_is_der(in) ? FORMAT_DER : FORMAT_PEM;
  }

  if (fmt == FORMAT_DER)
  {
    cert = d2i_X509_bio(in, NULL);
  }
  else if (fmt == FORMAT_PEM)
  {
    cert = PEM_read_bio_X509(in, NULL, NULL, NULL);
  }

  BIO_free(in);

  if (cert)
  {
    PUSH_OBJECT(cert, "openssl.x509");
    ret = 1;
  }
  return ret == 1 ? 1 : openssl_pushresult(L, ret);
}

/***
create or generate a new x509 object.
@function new
@tparam[opt] openssl.bn serial serial number
@tparam[opt] x509_req csr,copy x509_name, pubkey and extension to new object
@tparam[opt] x509_name subject subject name set to x509_req
@tparam[opt] stack_of_x509_extension extensions add to x509
@tparam[opt] stack_of_x509_attribute attributes add to x509
@treturn x509 certificate object
*/
static int openssl_x509_new(lua_State* L)
{
  int i = 1;
  int ret = 1;
  int n = lua_gettop(L);
  X509 *x = X509_new();

  ret = X509_set_version(x, 2);
  if (ret == 1 && ( auxiliar_getclassudata(L, "openssl.bn", i) ||
                    lua_isstring(L, i) || lua_isnumber(L, i) ))
  {
    BIGNUM *bn = BN_get(L, i);
    ASN1_INTEGER* ai = BN_to_ASN1_INTEGER(bn, NULL);
    BN_free(bn);
    ret = X509_set_serialNumber(x, ai);
    ASN1_INTEGER_free(ai);
    i++;
  }

  for (; i <= n && ret==1; i++)
  {
    if (ret == 1 && auxiliar_getclassudata(L, "openssl.x509_req", i))
    {
      X509_REQ* csr = CHECK_OBJECT(i, X509_REQ, "openssl.x509_req");
      X509_NAME* xn = X509_REQ_get_subject_name(csr);
      ret = X509_set_subject_name(x, xn);

      if (ret == 1)
      {
        STACK_OF(X509_EXTENSION) *exts = X509_REQ_get_extensions(csr);
        int j, n1;
        n1 = sk_X509_EXTENSION_num(exts);
        for (j = 0; ret == 1 && j < n1; j++)
        {
          ret = X509_add_ext(x, sk_X509_EXTENSION_value(exts, j), j);
        }
        sk_X509_EXTENSION_pop_free(exts, X509_EXTENSION_free);
      }
      if (ret == 1)
      {
        EVP_PKEY* pkey = X509_REQ_get_pubkey(csr);
        ret = X509_set_pubkey(x, pkey);
        EVP_PKEY_free(pkey);
      }
      i++;
    };

    if (ret == 1 && auxiliar_getclassudata(L, "openssl.x509_name", i))
    {
      X509_NAME *xn = CHECK_OBJECT(i, X509_NAME, "openssl.x509_name");
      ret = X509_set_subject_name(x, xn);
      i++;
    }
  }

  if (ret == 1)
    PUSH_OBJECT(x, "openssl.x509");
  else
  {
    X509_free(x);
    ret = openssl_pushresult(L, ret);
  }

  return ret;
};

static luaL_Reg R[] =
{
  {"new",           openssl_x509_new },
  {"read",          openssl_x509_read },
  {"purpose",       openssl_x509_purpose },
  {"certtypes",     openssl_x509_certtypes },
  {"verify_cert_error_string", openssl_verify_cert_error_string },

  {NULL,    NULL}
};

int openssl_push_general_name(lua_State*L, const GENERAL_NAME* general_name)
{
  if (general_name == NULL)
  {
    lua_pushnil(L);
    return 1;
  }
  lua_newtable(L);

  switch (general_name->type)
  {
  case GEN_OTHERNAME:
  {
    OTHERNAME *otherName = general_name->d.otherName;
    lua_newtable(L);
    openssl_push_asn1object(L, otherName->type_id);
    PUSH_ASN1_STRING(L, otherName->value->value.asn1_string);
    lua_settable(L, -3);
    lua_setfield(L, -2, "otherName");

    lua_pushstring(L, "otherName");
    lua_setfield(L, -2, "type");
    break;
  }
  case GEN_EMAIL:
    PUSH_ASN1_STRING(L, general_name->d.rfc822Name);
    lua_setfield(L, -2, "rfc822Name");

    lua_pushstring(L, "rfc822Name");
    lua_setfield(L, -2, "type");
    break;
  case GEN_DNS:
    PUSH_ASN1_STRING(L, general_name->d.dNSName);
    lua_setfield(L, -2, "dNSName");
    lua_pushstring(L, "dNSName");
    lua_setfield(L, -2, "type");
    break;
  case GEN_X400:
#if OPENSSL_VERSION_NUMBER >= 0x1010100fL && !defined(LIBRESSL_VERSION_NUMBER)
    PUSH_ASN1_STRING(L, general_name->d.x400Address);
#else
    openssl_push_asn1type(L, general_name->d.x400Address);
#endif
    lua_setfield(L, -2, "x400Address");
    lua_pushstring(L, "x400Address");
    lua_setfield(L, -2, "type");
    break;
  case GEN_DIRNAME:
  {
    X509_NAME* xn = general_name->d.directoryName;
    openssl_push_xname_asobject(L, xn);
    lua_setfield(L, -2, "directoryName");
    lua_pushstring(L, "directoryName");
    lua_setfield(L, -2, "type");
  }
  break;
  case GEN_URI:
    PUSH_ASN1_STRING(L, general_name->d.uniformResourceIdentifier);
    lua_setfield(L, -2, "uniformResourceIdentifier");
    lua_pushstring(L, "uniformResourceIdentifier");
    lua_setfield(L, -2, "type");
    break;
  case GEN_IPADD:
    PUSH_ASN1_OCTET_STRING(L, general_name->d.iPAddress);
    lua_setfield(L, -2, "iPAddress");
    lua_pushstring(L, "iPAddress");
    lua_setfield(L, -2, "type");
    break;
  case GEN_EDIPARTY:
    lua_newtable(L);
    PUSH_ASN1_STRING(L, general_name->d.ediPartyName->nameAssigner);
    lua_setfield(L, -2, "nameAssigner");
    PUSH_ASN1_STRING(L, general_name->d.ediPartyName->partyName);
    lua_setfield(L, -2, "partyName");
    lua_setfield(L, -2, "ediPartyName");

    lua_pushstring(L, "ediPartyName");
    lua_setfield(L, -2, "type");
    break;
  case GEN_RID:
    openssl_push_asn1object(L, general_name->d.registeredID);
    lua_setfield(L, -2, "registeredID");
    lua_pushstring(L, "registeredID");
    lua_setfield(L, -2, "type");
    break;
  default:
    lua_pushstring(L, "unsupport");
    lua_setfield(L, -2, "type");
  }
  return 1;
};

int openssl_push_x509_signature(lua_State *L, const X509_ALGOR *alg, const ASN1_STRING *sig, int i)
{
  if (i==0) lua_newtable(L); else i = lua_absindex(L, i);

  if (alg != NULL)
  {
    alg = X509_ALGOR_dup((X509_ALGOR*)alg);
    lua_pushliteral(L, "sig_alg");
    PUSH_OBJECT(alg, "openssl.x509_algor");
    lua_rawset(L, i==0 ? -3 : i);
  }
  if (sig != NULL)
  {
    lua_pushliteral(L, "sig");
    lua_pushlstring(L, (const char *)sig->data, sig->length);
    lua_rawset(L, i==0 ? -3 : i);
  }

  return  i==0 ? 1 : 0;
}

static int check_cert(X509_STORE *ca, X509 *x, STACK_OF(X509) *untrustedchain, int purpose)
{
  int ret = 0;
  X509_STORE_CTX *csc = X509_STORE_CTX_new();
  if (csc)
  {
    X509_STORE_set_flags(ca, X509_V_FLAG_CHECK_SS_SIGNATURE);
    if (X509_STORE_CTX_init(csc, ca, x, untrustedchain) == 1)
    {
      if (purpose > 0)
      {
        X509_STORE_CTX_set_purpose(csc, purpose);
      }
      ret = X509_verify_cert(csc);
      if (ret == 1)
        ret = X509_V_OK;
      else
        ret = X509_STORE_CTX_get_error(csc);
    }
    X509_STORE_CTX_cleanup(csc);
    X509_STORE_CTX_free(csc);
    return ret;
  }

  return X509_V_ERR_OUT_OF_MEM;
}

/***
openssl.x509 object
@type x509
*/
/***
export x509_req to string
@function export
@tparam[opt='pem'] string format, 'der' or 'pem' default
@treturn string
*/
static LUA_FUNCTION(openssl_x509_export)
{
  X509 *cert = CHECK_OBJECT(1, X509, "openssl.x509");
  int fmt = luaL_checkoption(L, 2, "pem", format);
  BIO* out = NULL;
  int ret = 0;

  out  = BIO_new(BIO_s_mem());

  ret = fmt == FORMAT_PEM ? PEM_write_bio_X509(out, cert)
                          : i2d_X509_bio(out, cert);
  if (ret)
  {
    BUF_MEM *bio_buf;
    BIO_get_mem_ptr(out, &bio_buf);
    lua_pushlstring(L, bio_buf->data, bio_buf->length);
    ret = 1;
  }

  BIO_free(out);
  return ret;
};

/***
parse x509 object as table
@function parse
@tparam[opt=true] shortname default will use short object name
@treturn table result which all x509 information
*/
static LUA_FUNCTION(openssl_x509_parse)
{
  int i;
  X509 * cert = CHECK_OBJECT(1, X509, "openssl.x509");
  int ca = lua_isnone(L, 2) ? X509_check_ca(cert) : lua_toboolean(L, 2);

  lua_newtable(L);
#if OPENSSL_VERSION_NUMBER < 0x10100000L
  if (cert->name)
  {
    AUXILIAR_SET(L, -1, "name", cert->name, string);
  }
  AUXILIAR_SET(L, -1, "valid", cert->valid, boolean);
#endif
  AUXILIAR_SET(L, -1, "version", X509_get_version(cert), integer);

  openssl_push_xname_asobject(L, X509_get_subject_name(cert));
  lua_setfield(L, -2, "subject");
  openssl_push_xname_asobject(L, X509_get_issuer_name(cert));
  lua_setfield(L, -2, "issuer");
  {
    char buf[32];
    snprintf(buf, sizeof(buf), "%08lx", X509_subject_name_hash(cert));
    AUXILIAR_SET(L, -1, "hash", buf, string);
  }

  PUSH_ASN1_INTEGER(L, X509_get0_serialNumber(cert));
  lua_setfield(L, -2, "serialNumber");

  PUSH_ASN1_TIME(L, X509_get0_notBefore(cert));
  lua_setfield(L, -2, "notBefore");
  PUSH_ASN1_TIME(L, X509_get0_notAfter(cert));
  lua_setfield(L, -2, "notAfter");

  {
    CONSTIFY_X509_get0 X509_ALGOR *palg = NULL;
    CONSTIFY_X509_get0 ASN1_BIT_STRING *psig = NULL;

    X509_get0_signature(&psig, &palg, cert);
    openssl_push_x509_signature(L, palg, psig, -1);
  }

  {
    int l = 0;
    char* tmpstr = (char *)X509_alias_get0(cert, &l);
    if (tmpstr)
    {
      AUXILIAR_SETLSTR(L, -1, "alias", tmpstr, l);
    }
  }

  AUXILIAR_SET(L, -1, "ca", X509_check_ca(cert), boolean);

  lua_newtable(L);
  for (i = 0; i < X509_PURPOSE_get_count(); i++)
  {
    int set;
    X509_PURPOSE *purp = X509_PURPOSE_get0(i);
    int id = X509_PURPOSE_get_id(purp);
    const char * pname = X509_PURPOSE_get0_sname(purp);

    set = X509_check_purpose(cert, id, ca);
    if (set)
    {
      AUXILIAR_SET(L, -1, pname, 1, boolean);
    }
  }
  lua_setfield(L, -2, "purposes");

  {
    int n = X509_get_ext_count(cert);
    if (n > 0)
    {
      lua_pushstring(L, "extensions");
      lua_newtable(L);
      for (i = 0; i < n; i++)
      {
        X509_EXTENSION *ext = X509_get_ext(cert, i);
        ext = X509_EXTENSION_dup(ext);
        lua_pushinteger(L, i + 1);
        PUSH_OBJECT(ext, "openssl.x509_extension");
        lua_rawset(L, -3);
      }
      lua_rawset(L, -3);
    }
  }

  return 1;
}

static LUA_FUNCTION(openssl_x509_free)
{
  X509 *cert = CHECK_OBJECT(1, X509, "openssl.x509");
  X509_free(cert);
  return 0;
}

/***
get public key of x509
@function pubkey
@treturn evp_pkey public key
*/
/***
set public key of x509
@function pubkey
@tparam evp_pkey pubkey public key set to x509
@treturn boolean result, true for success
*/
static LUA_FUNCTION(openssl_x509_public_key)
{
  X509 *cert = CHECK_OBJECT(1, X509, "openssl.x509");
  if (lua_isnone(L, 2))
  {
    EVP_PKEY *pkey = X509_get_pubkey(cert);
    PUSH_OBJECT(pkey, "openssl.evp_pkey");
    return 1;
  }
  else
  {
    EVP_PKEY* pkey = CHECK_OBJECT(2, EVP_PKEY, "openssl.evp_pkey");
    int ret = X509_set_pubkey(cert, pkey);
    return openssl_pushresult(L, ret);
  }
}

#if 0
static int verify_cb(int ok, X509_STORE_CTX *ctx)
{
  int err;
  X509 *err_cert;

  /*
  * it is ok to use a self signed certificate This case will catch both
  * the initial ok == 0 and the final ok == 1 calls to this function
  */
  err = X509_STORE_CTX_get_error(ctx);
  if (err == X509_V_ERR_DEPTH_ZERO_SELF_SIGNED_CERT)
    return 1;

  /*
  * BAD we should have gotten an error.  Normally if everything worked
  * X509_STORE_CTX_get_error(ctx) will still be set to
  * DEPTH_ZERO_SELF_....
  */
  if (ok)
  {
    //BIO_printf(bio_err, "error with certificate to be certified - should be self signed\n");
    return 0;
  }
  else
  {
    err_cert = X509_STORE_CTX_get_current_cert(ctx);
    //print_name(bio_err, NULL, X509_get_subject_name(err_cert), 0);
    //BIO_printf(bio_err, "error with certificate - error %d at depth %d\n%s\n", err, X509_STORE_CTX_get_error_depth(ctx), X509_verify_cert_error_string(err));
    return 1;
  }
}
#endif

/***
check x509 with ca certchian and option purpose
purpose can be one of: ssl_client, ssl_server, ns_ssl_server, smime_sign, smime_encrypt, crl_sign, any, ocsp_helper, timestamp_sign
@function check
@tparam x509_store cacerts
@tparam x509_store untrusted certs  containing a bunch of certs that are not trusted but may be useful in validating the certificate.
@tparam[opt] string purpose to check supported
@treturn boolean result true for check pass
@treturn integer verify result
@see verify_cert_error_string
*/
/***
check x509 with evp_pkey
@function check
@tparam evp_pkey pkey private key witch match with x509 pubkey
@treturn boolean result true for check pass
*/
static LUA_FUNCTION(openssl_x509_check)
{
  X509 * cert = CHECK_OBJECT(1, X509, "openssl.x509");
  if (auxiliar_getclassudata(L, "openssl.evp_pkey", 2))
  {
    EVP_PKEY * key = CHECK_OBJECT(2, EVP_PKEY, "openssl.evp_pkey");
    lua_pushboolean(L, X509_check_private_key(cert, key));
    return 1;
  }
  else
  {
    X509_STORE* store = CHECK_OBJECT(2, X509_STORE, "openssl.x509_store");
    STACK_OF(X509)* untrustedchain = lua_isnoneornil(L, 3) ?  NULL : openssl_sk_x509_fromtable(L, 3);
    int purpose = 0;
    int ret = 0;
    if (!lua_isnone(L, 4))
    {
      int purpose_id = X509_PURPOSE_get_by_sname((char*)luaL_optstring(L, 4, "any"));
      if (purpose_id >= 0)
      {
        X509_PURPOSE* ppurpose = X509_PURPOSE_get0(purpose_id);
        if (ppurpose) purpose = ppurpose->purpose;
      }
    }
#if 0
    X509_STORE_set_verify_cb_func(store, verify_cb);
#endif
    ret = check_cert(store, cert, untrustedchain, purpose);
    if (untrustedchain!=NULL) sk_X509_pop_free(untrustedchain, X509_free);
    lua_pushboolean(L, ret == X509_V_OK);
    lua_pushinteger(L, ret);

    return 2;
  }
}

/***
The functions return 1 for a successful match, 0 for a failed match and -1 for
an internal error: typically a memory allocation failure or an ASN.1 decoding
error.

All functions can also return -2 if the input is malformed. For example,
X509_check_host() returns -2 if the provided name contains embedded NULs.
*/
static int openssl_push_check_result(lua_State *L, int ret, const char* name)
{
  switch (ret)
  {
  case 1:
    lua_pushboolean(L, 1);
    if (name)
    {
      lua_pushstring(L, name);
      ret = 2;
    }
    break;
  case 0:
    lua_pushboolean(L, 0);
    ret = 1;
    break;
  case -1:
    lua_pushnil(L);
    lua_pushliteral(L, "internal");
    ret = 2;
  case -2:
    lua_pushnil(L);
    lua_pushliteral(L, "malformed");
    ret = 2;
  default:
    lua_pushnil(L);
    lua_pushinteger(L, ret);
    ret = 2;
  }
  return ret;
}

#if OPENSSL_VERSION_NUMBER > 0x10002000L
/***
check x509 for host (only for openssl 1.0.2 or greater)
@function check_host
@tparam string host hostname to check for match match with x509 subject
@treturn boolean result true if host is present and matches the certificate
*/
static LUA_FUNCTION(openssl_x509_check_host)
{
  X509 * cert = CHECK_OBJECT(1, X509, "openssl.x509");
  size_t sz;
  const char* hostname = luaL_checklstring(L, 2, &sz);
  int flags = luaL_optint(L, 3, 0);
  char *peer = NULL;

  int ret = X509_check_host(cert, hostname, sz, flags, &peer);
  ret = openssl_push_check_result(L, ret, peer);
  OPENSSL_free(peer);
  return ret;
}

/***
check x509 for email address (only for openssl 1.0.2 or greater)
@tparam string email to check for match match with x509 subject
@treturn boolean result true if host is present and matches the certificate
@function check_email
*/
static LUA_FUNCTION(openssl_x509_check_email)
{
  X509 * cert = CHECK_OBJECT(1, X509, "openssl.x509");
  size_t sz;
  const char *email = luaL_checklstring(L, 2, &sz);
  int flags = luaL_optint(L, 3, 0);
  int ret = X509_check_email(cert, email, sz, flags);
  return openssl_push_check_result(L, ret, NULL);
}

/***
check x509 for ip address (ipv4 or ipv6, only for openssl 1.0.2 or greater)
@function check_ip_asc
@tparam string ip to check for match match with x509 subject
@treturn boolean result true if host is present and matches the certificate
*/
static LUA_FUNCTION(openssl_x509_check_ip)
{
  X509 * cert = CHECK_OBJECT(1, X509, "openssl.x509");
  const char *ip = luaL_checkstring(L, 2);
  int flags = luaL_optint(L, 3, 0);
  int ret = X509_check_ip_asc(cert, ip, flags);
  return openssl_push_check_result(L, ret, NULL);
}
#endif

IMP_LUA_SK(X509, x509)

#if 0
static STACK_OF(X509) * load_all_certs_from_file(BIO *in)
{
  STACK_OF(X509) *stack = sk_X509_new_null();
  if (stack)
  {
    STACK_OF(X509_INFO) *sk = PEM_X509_INFO_read_bio(in, NULL, NULL, NULL);
    /* scan over it and pull out the certs */
    while (sk_X509_INFO_num(sk))
    {
      X509_INFO *xi = sk_X509_INFO_shift(sk);
      if (xi->x509 != NULL)
      {
        sk_X509_push(stack, xi->x509);
        xi->x509 = NULL;
      }
      X509_INFO_free(xi);
    }
    sk_X509_INFO_free(sk);
  };

  if (sk_X509_num(stack) == 0)
  {
    sk_X509_free(stack);
    stack = NULL;
  }
  return stack;
};
#endif

/***
get subject name of x509
@function subject
@treturn x509_name subject name
*/
/***
set subject name of x509
@function subject
@tparam x509_name subject
@treturn boolean result true for success
*/
static int openssl_x509_subject(lua_State* L)
{
  X509* cert = CHECK_OBJECT(1, X509, "openssl.x509");
  if (lua_isnone(L, 2))
  {
    X509_NAME* xn = X509_get_subject_name(cert);
    return openssl_push_xname_asobject(L, xn);
  }
  else
  {
    X509_NAME *xn = CHECK_OBJECT(2, X509_NAME, "openssl.x509_name");
    int ret = X509_set_subject_name(cert, xn);
    return openssl_pushresult(L, ret);
  }
}

/***
get issuer name of x509
@function issuer
@tparam[opt=false] boolean asobject, true for return as x509_name object, or as table
@treturn[1] x509_name issuer
@treturn[1] table issuer name as table
*/
/***
set issuer name of x509
@function issuer
@tparam x509_name name
@treturn boolean result true for success
*/
static int openssl_x509_issuer(lua_State* L)
{
  X509* cert = CHECK_OBJECT(1, X509, "openssl.x509");
  if (lua_isnone(L, 2))
  {
    X509_NAME* xn = X509_get_issuer_name(cert);
    return openssl_push_xname_asobject(L, xn);
  }
  else
  {
    X509_NAME* xn = CHECK_OBJECT(2, X509_NAME, "openssl.x509_name");
    int ret = X509_set_issuer_name(cert, xn);
    return openssl_pushresult(L, ret);
  }
}

/***
get digest of x509 object
@function digest
@tparam[opt='sha1'] evp_digest|string md_alg, default use 'sha1'
@treturn string digest result
*/
static int openssl_x509_digest(lua_State* L)
{
  unsigned int bytes;
  unsigned char buffer[EVP_MAX_MD_SIZE];
  X509 *cert = CHECK_OBJECT(1, X509, "openssl.x509");
  const EVP_MD *digest = get_digest(L, 2, "sha256");

  int ret = X509_digest(cert, digest, buffer, &bytes);
  if (ret == 1)
  {
    lua_pushlstring(L, (const char*)buffer, bytes);
  }
  return ret == 1 ? ret : openssl_pushresult(L, ret);
};

/***
get notbefore valid time of x509
@function notbefore
@treturn string notbefore time string
*/
/***
set notbefore valid time of x509
@function notbefore
@tparam string|number notbefore
*/
static int openssl_x509_notbefore(lua_State *L)
{
  X509* cert = CHECK_OBJECT(1, X509, "openssl.x509");
  if (lua_isnone(L, 2))
  {
    return PUSH_ASN1_TIME(L, X509_get0_notBefore(cert));
  }
  else
  {
    ASN1_TIME* at = NULL;
    int ret = 1;
    if (lua_isnumber(L, 2))
    {
      time_t time = lua_tointeger(L, 2);
      at = ASN1_TIME_new();
      ASN1_TIME_set(at, time);
    }
    else if (lua_isstring(L, 2))
    {
      const char* time = lua_tostring(L, 2);
      at = ASN1_TIME_new();
      if (ASN1_TIME_set_string(at, time) != 1)
      {
        ASN1_TIME_free(at);
        at = NULL;
      }
    }
    if (at)
    {
      ret = X509_set1_notBefore(cert, at);
      ASN1_TIME_free(at);
    }
    else
      ret = 0;
    return openssl_pushresult(L, ret);
  };
}

/***
get notafter valid time of x509
@function notafter
@treturn string notafter time string
*/
/***
set notafter valid time of x509
@function notafter
@tparam string|number notafter
*/
static int openssl_x509_notafter(lua_State *L)
{
  X509* cert = CHECK_OBJECT(1, X509, "openssl.x509");
  if (lua_isnone(L, 2))
  {
    return PUSH_ASN1_TIME(L, X509_get0_notAfter(cert));
  }
  else
  {
    ASN1_TIME* at = NULL;
    int ret = 1;
    if (lua_isnumber(L, 2))
    {
      time_t time = lua_tointeger(L, 2);
      at = ASN1_TIME_new();
      ASN1_TIME_set(at, time);
    }
    else if (lua_isstring(L, 2))
    {
      const char* time = lua_tostring(L, 2);
      at = ASN1_TIME_new();
      if (ASN1_TIME_set_string(at, time) != 1)
      {
        ASN1_TIME_free(at);
        at = NULL;
      }
    }
    if (at)
    {
      ret = X509_set1_notAfter(cert, at);
      ASN1_TIME_free(at);
    }
    else
      ret = 0;
    return openssl_pushresult(L, ret);
  }
}

/***
check x509 valid
@function validat
@tparam[opt] number time, default will use now time
@treturn boolean result true for valid, or for invalid
@treturn string notbefore
@treturn string notafter
*/
/***
set valid time, notbefore and notafter
@function validat
@tparam number notbefore
@tparam number notafter
@treturn boolean result, true for success
*/
static int openssl_x509_valid_at(lua_State* L)
{
  X509* cert = CHECK_OBJECT(1, X509, "openssl.x509");
  int ret = 0;

  if (lua_isnone(L, 2))
  {
    time_t now = 0;
    time(&now);

    lua_pushboolean(L, (X509_cmp_time(X509_get0_notAfter(cert), &now)     >= 0
                        && X509_cmp_time(X509_get0_notBefore(cert), &now) <= 0));
    PUSH_ASN1_TIME(L, X509_get0_notBefore(cert));
    PUSH_ASN1_TIME(L, X509_get0_notAfter(cert));
    ret = 3;
  }
  else if (lua_gettop(L) == 2)
  {
    time_t time = luaL_checkinteger(L, 2);
    lua_pushboolean(L, (X509_cmp_time(X509_get0_notAfter(cert), &time)     >= 0
                        && X509_cmp_time(X509_get0_notBefore(cert), &time) <= 0));
    PUSH_ASN1_TIME(L, X509_get0_notBefore(cert));
    PUSH_ASN1_TIME(L, X509_get0_notAfter(cert));
    ret = 3;
  }
  else if (lua_gettop(L) == 3)
  {
    time_t before, after;
    ASN1_TIME *ab, *aa;

    before = lua_tointeger(L, 2);
    after  = lua_tointeger(L, 3);

    ab = ASN1_TIME_new();
    aa = ASN1_TIME_new();
    ASN1_TIME_set(ab, before);
    ASN1_TIME_set(aa, after);
    ret = X509_set1_notBefore(cert, ab);
    if (ret == 1)
      ret = X509_set1_notAfter(cert, aa);

    ASN1_TIME_free(ab);
    ASN1_TIME_free(aa);

    ret = openssl_pushresult(L, ret);
  }
  return ret;
}

/***
get serial number of x509
@function serial
@tparam[opt=true] boolean asobject
@treturn[1] bn object
@treturn[2] string result
*/
/***
set serial number of x509
@function serial
@tparam string|number|bn serail
@treturn boolean result true for success
*/
static int openssl_x509_serial(lua_State *L)
{
  X509* cert = CHECK_OBJECT(1, X509, "openssl.x509");
  ASN1_INTEGER *serial = X509_get_serialNumber(cert);
  if (lua_isboolean(L, 2))
  {
    int asobj = lua_toboolean(L, 2);
    if (asobj)
    {
      PUSH_ASN1_INTEGER(L, serial);
    }
    else
    {
      BIGNUM *bn = ASN1_INTEGER_to_BN(serial, NULL);
      PUSH_OBJECT(bn, "openssl.bn");
    }
  }
  else if (lua_isnone(L, 2))
  {
    BIGNUM *bn = ASN1_INTEGER_to_BN(serial, NULL);
    char *tmp = BN_bn2hex(bn);
    lua_pushstring(L, tmp);
    OPENSSL_free(tmp);
    BN_free(bn);
  }
  else
  {
    int ret;
    if (auxiliar_getclassudata(L, "openssl.asn1_string", 2))
    {
      serial = CHECK_OBJECT(2, ASN1_STRING, "openssl.asn1_string");
    }
    else
    {
      BIGNUM *bn = BN_get(L, 2);
      serial = BN_to_ASN1_INTEGER(bn, NULL);
      BN_free(bn);
    }
    luaL_argcheck(L, serial != NULL, 2, "not accept");
    ret = X509_set_serialNumber(cert, serial);
    ASN1_INTEGER_free(serial);
    return openssl_pushresult(L, ret);
  }
  return 1;
}

/***
get version number of x509
@function version
@treturn number version of x509
*/
/***
set version number of x509
@function version
@tparam number version
@treturn boolean result true for result
*/
static int openssl_x509_version(lua_State *L)
{
  int version;
  X509* cert = CHECK_OBJECT(1, X509, "openssl.x509");
  if (lua_isnone(L, 2))
  {
    version = X509_get_version(cert);
    lua_pushinteger(L, version);
    return 1;
  }
  else
  {
    int ret;
    version = luaL_checkint(L, 2);
    ret = X509_set_version(cert, version);
    return openssl_pushresult(L, ret);
  }
}

/***
get extensions of x509 object
@function extensions
@tparam[opt=false] boolean asobject, true for return as stack_of_x509_extension or as table
@treturn[1] stack_of_x509_extension object when param set true
@treturn[2] table contain all x509_extension when param set false or nothing
*/
/***
set extension of x509 object
@function extensions
@tparam stack_of_x509_extension extensions
@treturn boolean result true for success
*/
static int openssl_x509_extensions(lua_State* L)
{
  X509 *self = CHECK_OBJECT(1, X509, "openssl.x509");
  STACK_OF(X509_EXTENSION) *exts = (STACK_OF(X509_EXTENSION) *)X509_get0_extensions(self);
  int ret = 0;

  if (lua_isnone(L, 2))
  {
    if (exts)
    {
      openssl_sk_x509_extension_totable(L, exts);
      ret = 1;
    }
  }
  else
  {
    STACK_OF(X509_EXTENSION) *others = (STACK_OF(X509_EXTENSION) *)openssl_sk_x509_extension_fromtable(L, 2);
#if OPENSSL_VERSION_NUMBER < 0x10100000L
    sk_X509_EXTENSION_pop_free(self->cert_info->extensions, X509_EXTENSION_free);
    self->cert_info->extensions = others;
#else
    int i, n;
    X509_EXTENSION* ext;

    if (exts != NULL)
    {
      for (n = sk_X509_EXTENSION_num(exts), i = n - 1; i >= 0; i--)
      {
        ext = sk_X509_EXTENSION_value(exts, i);
        X509_EXTENSION_free(ext);
        sk_X509_EXTENSION_delete(exts, i);
      }
      sk_X509_EXTENSION_zero(exts);
    }

    for (i = 0, n = sk_X509_EXTENSION_num(others); i < n; i++)
    {
      ext = sk_X509_EXTENSION_value(others, i);
      X509_add_ext(self, ext, -1);
    }
    sk_X509_EXTENSION_pop_free(others, X509_EXTENSION_free);
#endif
    ret = openssl_pushresult(L, 1);
  }
  return ret;
}

/***
sign x509
@function sign
@tparam evp_pkey pkey private key to sign x509
@tparam x509|x509_name cacert or cacert x509_name
@tparam[opt='sha1WithRSAEncryption'] string|md_digest md_alg
@treturn boolean result true for check pass
*/
static int openssl_x509_sign(lua_State*L)
{
  X509* x = CHECK_OBJECT(1, X509, "openssl.x509");
  int ret = 0;

  if (lua_isnone(L, 2))
  {
    unsigned char *out = NULL;
    ret = i2d_re_X509_tbs(x, &out);
    if (ret > 0)
    {
      lua_pushlstring(L, (const char *)out, ret);
      OPENSSL_free(out);
      ret = 1;
    }
    else
      ret = openssl_pushresult(L, ret);
  }
  else if (auxiliar_getclassudata(L, "openssl.evp_pkey", 2))
  {
    EVP_PKEY* pkey = CHECK_OBJECT(2, EVP_PKEY, "openssl.evp_pkey");
    const EVP_MD *md;
    int i = 3;

    if (auxiliar_getclassudata(L, "openssl.x509_name", i))
    {
      X509_NAME* xn = CHECK_OBJECT(i, X509_NAME, "openssl.x509_name");
      ret = X509_set_issuer_name(x, xn);
      i++;
    }
    else
    {
      X509* ca = CHECK_OBJECT(i, X509, "openssl.x509");
      X509_NAME* xn = X509_get_subject_name(ca);
      ret = X509_check_private_key(ca, pkey);
      if (ret == 1)
        ret = X509_set_issuer_name(x, xn);
      i++;
    }

    if (ret == 1)
    {
      md = get_digest(L, i, "sha256");
      ret = X509_sign(x, pkey, md);
      if (ret > 0) ret = 1;
    }
    ret = openssl_pushresult(L, ret);
  }
  else
  {
    size_t sig_len;
    const char* sig = luaL_checklstring(L, 2, &sig_len);
    ASN1_OBJECT *obj = openssl_get_asn1object(L, 3, 0);

    CONSTIFY_X509_get0 ASN1_BIT_STRING *psig = NULL;
    CONSTIFY_X509_get0 X509_ALGOR *palg = NULL;

    X509_get0_signature(&psig, &palg, x);
    ret = ASN1_BIT_STRING_set((ASN1_BIT_STRING*)psig, (unsigned char*)sig, (int)sig_len);
    if (ret == 1)
    {
      ret = X509_ALGOR_set0((X509_ALGOR*)palg, obj, V_ASN1_UNDEF, NULL);
    }
    else
      ASN1_OBJECT_free(obj);
    ret = openssl_pushresult(L, ret);
  }
  return ret;
}

static int openssl_x509_verify(lua_State*L)
{
  X509* x = CHECK_OBJECT(1, X509, "openssl.x509");
  int ret = 0;
  if (lua_isnone(L, 2))
  {
    unsigned char *out = NULL;
    ret = i2d_re_X509_tbs(x, &out);
    if (ret > 0)
    {
      CONSTIFY_X509_get0 ASN1_BIT_STRING *sig = NULL;
      CONSTIFY_X509_get0 X509_ALGOR *alg = NULL;

      lua_pushlstring(L, (const char *)out, ret);
      OPENSSL_free(out);

      X509_get0_signature(&sig, &alg, x);
      openssl_push_x509_signature(L, alg, sig, 0);

      ret = 2;
    }
    else
      ret = openssl_pushresult(L, ret);
  }
  else
  {
    EVP_PKEY *pkey = CHECK_OBJECT(2, EVP_PKEY, "openssl.evp_pkey");
    ret = X509_verify(x, pkey);
    ret = openssl_pushresult(L, ret);
  }
  return ret;
}

static int openssl_x509_equal(lua_State *L)
{
  X509* x = CHECK_OBJECT(1, X509, "openssl.x509");
  X509* y = CHECK_OBJECT(2, X509, "openssl.x509");
  lua_pushboolean(L, X509_cmp(x, y)==0);
  return 1;
}

static luaL_Reg x509_funcs[] =
{
  {"parse",       openssl_x509_parse},
  {"export",      openssl_x509_export},
  {"check",       openssl_x509_check},
#if OPENSSL_VERSION_NUMBER > 0x10002000L
  {"check_host",  openssl_x509_check_host},
  {"check_email", openssl_x509_check_email},
  {"check_ip_asc", openssl_x509_check_ip},
#endif
  {"pubkey",      openssl_x509_public_key},
  {"version",     openssl_x509_version},

  {"__gc",        openssl_x509_free},
  {"__eq",        openssl_x509_equal},
  {"__tostring",  auxiliar_tostring},

  {"equal",       openssl_x509_equal},

  {"digest",     openssl_x509_digest},
  {"extensions", openssl_x509_extensions},
  {"issuer",     openssl_x509_issuer},
  {"notbefore",  openssl_x509_notbefore},
  {"notafter",   openssl_x509_notafter},
  {"serial",     openssl_x509_serial},
  {"subject",    openssl_x509_subject},
  {"validat",    openssl_x509_valid_at},

  {"sign",       openssl_x509_sign},
  {"verify",     openssl_x509_verify},

  {NULL,      NULL},
};

#if OPENSSL_VERSION_NUMBER > 0x10002000L
static LuaL_Enumeration check_flags_const[] =
{
#define DEFINE_ENUM(x)  \
  {#x,  X509_CHECK_FLAG_##x}
  DEFINE_ENUM(ALWAYS_CHECK_SUBJECT),
#if OPENSSL_VERSION_NUMBER > 0x10100000L && !defined(LIBRESSL_VERSION_NUMBER)
  DEFINE_ENUM(NEVER_CHECK_SUBJECT),
#endif
  DEFINE_ENUM(NO_WILDCARDS),
  DEFINE_ENUM(NO_PARTIAL_WILDCARDS),
  DEFINE_ENUM(MULTI_LABEL_WILDCARDS),
  DEFINE_ENUM(SINGLE_LABEL_SUBDOMAINS),
#undef DEFINE_ENUM

  {NULL,           0}
};
#endif

static LuaL_Enumeration x509_vry_result[] =
{
  {"OK",     X509_V_OK},
#define DEFINE_ENUM(x)  {#x,  X509_V_ERR_##x}
  DEFINE_ENUM(UNSPECIFIED),
  DEFINE_ENUM(UNABLE_TO_GET_ISSUER_CERT),
  DEFINE_ENUM(UNABLE_TO_GET_CRL),
  DEFINE_ENUM(UNABLE_TO_DECRYPT_CERT_SIGNATURE),
  DEFINE_ENUM(UNABLE_TO_DECRYPT_CRL_SIGNATURE),
  DEFINE_ENUM(UNABLE_TO_DECODE_ISSUER_PUBLIC_KEY),
  DEFINE_ENUM(CERT_SIGNATURE_FAILURE),
  DEFINE_ENUM(CRL_SIGNATURE_FAILURE),
  DEFINE_ENUM(CERT_NOT_YET_VALID),
  DEFINE_ENUM(CERT_HAS_EXPIRED),
  DEFINE_ENUM(CRL_NOT_YET_VALID),
  DEFINE_ENUM(CRL_HAS_EXPIRED),
  DEFINE_ENUM(ERROR_IN_CERT_NOT_BEFORE_FIELD),
  DEFINE_ENUM(ERROR_IN_CERT_NOT_AFTER_FIELD),
  DEFINE_ENUM(ERROR_IN_CRL_LAST_UPDATE_FIELD),
  DEFINE_ENUM(ERROR_IN_CRL_NEXT_UPDATE_FIELD),
  DEFINE_ENUM(OUT_OF_MEM),
  DEFINE_ENUM(DEPTH_ZERO_SELF_SIGNED_CERT),
  DEFINE_ENUM(SELF_SIGNED_CERT_IN_CHAIN),
  DEFINE_ENUM(UNABLE_TO_GET_ISSUER_CERT_LOCALLY),
  DEFINE_ENUM(UNABLE_TO_VERIFY_LEAF_SIGNATURE),
  DEFINE_ENUM(CERT_CHAIN_TOO_LONG),
  DEFINE_ENUM(CERT_REVOKED),
  DEFINE_ENUM(INVALID_CA),
  DEFINE_ENUM(PATH_LENGTH_EXCEEDED),
  DEFINE_ENUM(INVALID_PURPOSE),
  DEFINE_ENUM(CERT_UNTRUSTED),
  DEFINE_ENUM(CERT_REJECTED),
  DEFINE_ENUM(SUBJECT_ISSUER_MISMATCH),
  DEFINE_ENUM(AKID_SKID_MISMATCH),
  DEFINE_ENUM(AKID_ISSUER_SERIAL_MISMATCH),
  DEFINE_ENUM(KEYUSAGE_NO_CERTSIGN),
  DEFINE_ENUM(UNABLE_TO_GET_CRL_ISSUER),
  DEFINE_ENUM(UNHANDLED_CRITICAL_EXTENSION),
  DEFINE_ENUM(KEYUSAGE_NO_CRL_SIGN),
  DEFINE_ENUM(UNHANDLED_CRITICAL_CRL_EXTENSION),
  DEFINE_ENUM(INVALID_NON_CA),
  DEFINE_ENUM(PROXY_PATH_LENGTH_EXCEEDED),
  DEFINE_ENUM(KEYUSAGE_NO_DIGITAL_SIGNATURE),
  DEFINE_ENUM(PROXY_CERTIFICATES_NOT_ALLOWED),
  DEFINE_ENUM(INVALID_EXTENSION),
  DEFINE_ENUM(INVALID_POLICY_EXTENSION),
  DEFINE_ENUM(NO_EXPLICIT_POLICY),
  DEFINE_ENUM(DIFFERENT_CRL_SCOPE),
  DEFINE_ENUM(UNSUPPORTED_EXTENSION_FEATURE),
  DEFINE_ENUM(UNNESTED_RESOURCE),
  DEFINE_ENUM(PERMITTED_VIOLATION),
  DEFINE_ENUM(EXCLUDED_VIOLATION),
  DEFINE_ENUM(SUBTREE_MINMAX),
  DEFINE_ENUM(APPLICATION_VERIFICATION),
  DEFINE_ENUM(UNSUPPORTED_CONSTRAINT_TYPE),
  DEFINE_ENUM(UNSUPPORTED_CONSTRAINT_SYNTAX),
  DEFINE_ENUM(UNSUPPORTED_NAME_SYNTAX),
  DEFINE_ENUM(CRL_PATH_VALIDATION_ERROR),
#if OPENSSL_VERSION_NUMBER > 0x10101000L && !defined(LIBRESSL_VERSION_NUMBER)
  DEFINE_ENUM(PATH_LOOP),
  DEFINE_ENUM(SUITE_B_INVALID_VERSION),
  DEFINE_ENUM(SUITE_B_INVALID_ALGORITHM),
  DEFINE_ENUM(SUITE_B_INVALID_CURVE),
  DEFINE_ENUM(SUITE_B_INVALID_SIGNATURE_ALGORITHM),
  DEFINE_ENUM(SUITE_B_LOS_NOT_ALLOWED),
  DEFINE_ENUM(SUITE_B_CANNOT_SIGN_P_384_WITH_P_256),
  DEFINE_ENUM(HOSTNAME_MISMATCH),
  DEFINE_ENUM(EMAIL_MISMATCH),
  DEFINE_ENUM(IP_ADDRESS_MISMATCH),
  DEFINE_ENUM(DANE_NO_MATCH),
  DEFINE_ENUM(EE_KEY_TOO_SMALL),
  DEFINE_ENUM(CA_KEY_TOO_SMALL),
  DEFINE_ENUM(CA_MD_TOO_WEAK),
  DEFINE_ENUM(INVALID_CALL),
  DEFINE_ENUM(STORE_LOOKUP),
  DEFINE_ENUM(NO_VALID_SCTS),
  DEFINE_ENUM(PROXY_SUBJECT_NAME_VIOLATION),
  DEFINE_ENUM(OCSP_VERIFY_NEEDED),
  DEFINE_ENUM(OCSP_VERIFY_FAILED),
  DEFINE_ENUM(OCSP_CERT_UNKNOWN),
#ifdef X509_V_ERR_SIGNATURE_ALGORITHM_MISMATCH
  DEFINE_ENUM(SIGNATURE_ALGORITHM_MISMATCH),
#endif
#ifdef X509_V_ERR_NO_ISSUER_PUBLIC_KEY
  DEFINE_ENUM(NO_ISSUER_PUBLIC_KEY),
#endif
#ifdef X509_V_ERR_UNSUPPORTED_SIGNATURE_ALGORITHM
  DEFINE_ENUM(UNSUPPORTED_SIGNATURE_ALGORITHM),
#endif
#ifdef EC_KEY_EXPLICIT_PARAMS
  DEFINE_ENUM(EC_KEY_EXPLICIT_PARAMS),
#endif
#endif
#undef DEFINE_ENUM
  {NULL, 0}
};

int luaopen_x509(lua_State *L)
{
  auxiliar_newclass(L, "openssl.x509", x509_funcs);

  lua_newtable(L);
  luaL_setfuncs(L, R, 0);

  openssl_register_xname(L);
  lua_setfield(L, -2, "name");
  openssl_register_xattribute(L);
  lua_setfield(L, -2, "attribute");
  openssl_register_xextension(L);
  lua_setfield(L, -2, "extension");
  openssl_register_xstore(L);
  lua_setfield(L, -2, "store");
  openssl_register_xalgor(L);
  lua_setfield(L, -2, "algor");

  luaopen_x509_req(L);
  lua_setfield(L, -2, "req");
  luaopen_x509_crl(L);
  lua_setfield(L, -2, "crl");

#if OPENSSL_VERSION_NUMBER > 0x10002000L
  lua_pushliteral(L, "check_flag");
  lua_newtable(L);
  auxiliar_enumerate(L, -1, check_flags_const);
  lua_settable(L, -3);
#endif

  lua_pushliteral(L, "verify_result");
  lua_newtable(L);
  auxiliar_enumerate(L, -1, x509_vry_result);
  lua_settable(L, -3);

  return 1;
}
