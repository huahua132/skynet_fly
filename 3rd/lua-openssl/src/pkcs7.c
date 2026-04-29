/***
pkcs7 module to create and process PKCS#7 files. That only understands PKCS#7 v 1.5 as specified in
IETF RFC 2315, and not currently parse CMS as described in IETF RFC 2630.

@module pkcs7
@usage
  pkcs7 = require('openssl').pkcs7
*/
#include <openssl/pkcs7.h>

#include "openssl.h"
#include "private.h"

#if (OPENSSL_VERSION_NUMBER < 0x10100000L)                                                         \
  || (defined(LIBRESSL_VERSION_NUMBER) && LIBRESSL_VERSION_NUMBER < 0x2090000fL)
#define OPENSSL_USE_M_ASN1
#endif

/***
read string or bio object, which include pkcs7 content

@function read
@tparam bio|string input
@tparam[opt='auto'] string format allow 'auto','der','pem','smime'
 auto will only try 'der' or 'pem'
@treturn openssl.pkcs7 object or nil
@treturn string content exist only smime format
*/
static int openssl_pkcs7_read(lua_State *L)
{
  BIO   *bio = load_bio_object(L, 1);
  int    fmt = luaL_checkoption(L, 2, "auto", format);
  PKCS7 *p7 = NULL;
  BIO   *ctx = NULL;
  int    ret = 0;

  if (fmt == FORMAT_AUTO) fmt = bio_is_der(bio) ? FORMAT_DER : FORMAT_PEM;

  if (fmt == FORMAT_DER) {
    p7 = d2i_PKCS7_bio(bio, NULL);
    BIO_reset(bio);
  } else if (fmt == FORMAT_PEM) {
    p7 = PEM_read_bio_PKCS7(bio, NULL, NULL, NULL);
    BIO_reset(bio);
  } else if (fmt == FORMAT_SMIME) {
    p7 = SMIME_read_PKCS7(bio, &ctx);
  }

  BIO_free(bio);
  if (p7) {
    PUSH_OBJECT(p7, "openssl.pkcs7");
    ret = 1;
    if (ctx) {
      BUF_MEM *mem;
      BIO_get_mem_ptr(ctx, &mem);
      lua_pushlstring(L, mem->data, mem->length);
      BIO_free(ctx);
      ret = 2;
    }
  }
  return ret;
}

/***
create new empty pkcs7 object, which support flexible sign methods.

@function new
@tparam[opt=NID_pkcs7_signed] int oid given pkcs7 type
@tparam[opt=NID_pkcs7_data] int content given pkcs7 content type
@treturn openssl.pkcs7 object
*/
static int openssl_pkcs7_new(lua_State *L)
{
  const char *options[]
    = { "data", "signed", "enveloped", "signedAndEnveloped", "digest", "encrypted", NULL };

  const int opt[] = { NID_pkcs7_data,
                      NID_pkcs7_signed,
                      NID_pkcs7_enveloped,
                      NID_pkcs7_signedAndEnveloped,
                      NID_pkcs7_digest,
                      NID_pkcs7_encrypted,
                      NID_undef };

  int type = auxiliar_checkoption(L, 1, "signed", options, opt);
  int content_nid = auxiliar_checkoption(L, 2, "data", options, opt);
  int ret = 0;

  PKCS7 *p7 = PKCS7_new();
  if (p7) {
    if (PKCS7_set_type(p7, type)) {
      if (PKCS7_content_new(p7, content_nid)) {
        PUSH_OBJECT(p7, "openssl.pkcs7");
        ret = 1;
      }
    }

    if (ret == 0) PKCS7_free(p7);
  }

  return ret;
}

/***
create PKCS7 structure with certificates and CRLs
@function create
@tparam table certs array of X509 certificates
@tparam[opt] table crls array of X509 CRLs
@treturn pkcs7|nil new PKCS7 object or nil on error
*/
static int openssl_pkcs7_create(lua_State *L)
{
  PKCS7        *p7 = NULL;
  PKCS7_SIGNED *p7s = NULL;

  STACK_OF(X509) *certs = openssl_sk_x509_fromtable(L, 1);
  STACK_OF(X509_CRL) *crls = lua_isnoneornil(L, 2) ? NULL : openssl_sk_x509_crl_fromtable(L, 2);

  p7 = PKCS7_new();
  p7s = PKCS7_SIGNED_new();
  if (p7 != NULL && p7s != NULL) {
    p7->type = OBJ_nid2obj(NID_pkcs7_signed);
    p7->d.sign = p7s;
    p7s->contents->type = OBJ_nid2obj(NID_pkcs7_data);

    ASN1_INTEGER_set(p7s->version, 1);
    p7s->crl = crls;
    p7s->cert = certs;

    PUSH_OBJECT(p7, "openssl.pkcs7");
    return 1;
  }
  PKCS7_free(p7);
  PKCS7_SIGNED_free(p7s);

  return 0;
}

/***
set content for PKCS7 structure
@function set_content
@tparam openssl.pkcs7 content PKCS7 content to set
@treturn boolean true on success, false on failure
*/
static int openssl_pkcs7_set_content(lua_State *L)
{
  PKCS7 *p7 = CHECK_OBJECT(1, PKCS7, "openssl.pkcs7");
  PKCS7 *content = CHECK_OBJECT(2, PKCS7, "openssl.pkcs7");

  int ret = PKCS7_set_content(p7, PKCS7_dup(content));
  return openssl_pushresult(L, ret);
}

/***
add certificates or CRLs to PKCS7 structure
@function add
@tparam x509|x509_crl... objects one or more X509 certificates or CRL objects to add
@treturn boolean true on success, false on failure
*/
static int openssl_pkcs7_add(lua_State *L)
{
  PKCS7 *p7 = CHECK_OBJECT(1, PKCS7, "openssl.pkcs7");
  int    n = lua_gettop(L);
  int    i, ret = 1;

  luaL_argcheck(L, lua_isuserdata(L, 2), 2, "must supply certificate or crl object");

  for (i = 2; i <= n; i++) {
    luaL_argcheck(L,
                  auxiliar_getclassudata(L, "openssl.x509", i)
                    || auxiliar_getclassudata(L, "openssl.x509_crl", i),
                  i,
                  "must supply certificate or crl object");

    if (auxiliar_getclassudata(L, "openssl.x509", i)) {
      X509 *x = CHECK_OBJECT(i, X509, "openssl.x509");
      ret = PKCS7_add_certificate(p7, x);
    } else {
      X509_CRL *crl = CHECK_OBJECT(i, X509_CRL, "openssl.x509_crl");
      ret = PKCS7_add_crl(p7, crl);
    }
    luaL_argcheck(L, ret, i, "add to pkcs7 fail");
  }

  return openssl_pushresult(L, ret);
}

/***
sign message with signcert and signpkey to create pkcs7 object

@function sign
@tparam string|bio msg
@tparam openssl.x509 signcert
@tparam openssl.evp_pkey signkey
@tparam[opt] stack_of_x509 cacerts
@tparam[opt=0] number flags
@treturn openssl.pkcs7 object
*/
static int openssl_pkcs7_sign(lua_State *L)
{
  int ret = 0;

  BIO      *in = load_bio_object(L, 1);
  X509     *cert = CHECK_OBJECT(2, X509, "openssl.x509");
  EVP_PKEY *privkey = CHECK_OBJECT(3, EVP_PKEY, "openssl.evp_pkey");
  STACK_OF(X509) *others = lua_isnoneornil(L, 4) ? 0 : openssl_sk_x509_fromtable(L, 4);
  long   flags = luaL_optint(L, 5, 0);
  PKCS7 *p7 = NULL;

  luaL_argcheck(L, X509_check_private_key(cert, privkey), 3, "sigcert and private key not match");

  p7 = PKCS7_sign(cert, privkey, others, in, flags);
  BIO_free(in);
  if (others) sk_X509_pop_free(others, X509_free);

  if (p7) {
    PUSH_OBJECT(p7, "openssl.pkcs7");
    ret = 1;
  }

  return ret;
}

/***
verify pkcs7 object, and return msg content or verify result

@function verify
@tparam openssl.pkcs7 in
@tparam[opt] stack_of_x509 signercerts
@tparam[opt] x509_store cacerts
@tparam[opt] string|bio msg
@tparam[opt=0] number flags
@treturn[1] string content
@treturn[1] boolean result
*/

static int openssl_pkcs7_verify(lua_State *L)
{
  int    ret = 0;
  PKCS7 *p7 = CHECK_OBJECT(1, PKCS7, "openssl.pkcs7");
  STACK_OF(X509) *signers = lua_isnoneornil(L, 2) ? NULL : openssl_sk_x509_fromtable(L, 2);
  X509_STORE *store
    = lua_isnoneornil(L, 3) ? NULL : CHECK_OBJECT(3, X509_STORE, "openssl.x509_store");
  BIO *in = lua_isnoneornil(L, 4) ? NULL : load_bio_object(L, 4);
  long flags = luaL_optint(L, 5, 0);
  BIO *out = NULL;

  if ((flags & PKCS7_DETACHED) == 0) out = BIO_new(BIO_s_mem());

  if (PKCS7_verify(p7, signers, store, in, out, flags) == 1) {
    if (out) {
      BUF_MEM *bio_buf;

      BIO_get_mem_ptr(out, &bio_buf);
      lua_pushlstring(L, bio_buf->data, bio_buf->length);
    } else
      lua_pushboolean(L, 1);

    ret = 1;
  }

  if (signers) sk_X509_pop_free(signers, X509_free);
  if (out) BIO_free(out);
  if (in) BIO_free(in);

  return ret;
}

/***
encrypt message with recipcerts certificates return encrypted pkcs7 object

@function encrypt
@tparam string|bio msg
@tparam stack_of_x509 recipcerts
@tparam[opt='aes-128-cbc'] string|evp_cipher cipher
@tparam[opt] number flags
@treturn openssl.pkcs7 encrypted PKCS7 object or nil on failure
*/
static int openssl_pkcs7_encrypt(lua_State *L)
{
  int    ret = 0;
  PKCS7 *p7 = NULL;
  BIO   *in = load_bio_object(L, 1);
  STACK_OF(X509) *recipcerts = openssl_sk_x509_fromtable(L, 2);
  const EVP_CIPHER *cipher = get_cipher(L, 3, "aes-128-cbc");
  long              flags = luaL_optint(L, 4, 0);

  p7 = PKCS7_encrypt(recipcerts, in, cipher, flags);
  BIO_free(in);
  sk_X509_pop_free(recipcerts, X509_free);
  if (p7) {
    PUSH_OBJECT(p7, "openssl.pkcs7");
    ret = 1;
  }

  return ret;
}

/***
decrypt encrypted pkcs7 message

@function decrypt
@tparam openssl.pkcs7 input
@tparam openssl.x509 recipcert
@tparam openssl.evp_pkey recipkey
@treturn string decrypt message
*/
static int openssl_pkcs7_decrypt(lua_State *L)
{
  int ret = 0;

  PKCS7    *p7 = CHECK_OBJECT(1, PKCS7, "openssl.pkcs7");
  X509     *cert = CHECK_OBJECT(2, X509, "openssl.x509");
  EVP_PKEY *key = CHECK_OBJECT(3, EVP_PKEY, "openssl.evp_pkey");
  long      flags = luaL_optint(L, 4, 0);
  BIO      *out = BIO_new(BIO_s_mem());

  if (PKCS7_decrypt(p7, key, cert, out, flags)) {
    BUF_MEM *mem;
    BIO_get_mem_ptr(out, &mem);
    lua_pushlstring(L, mem->data, mem->length);
    ret = 1;
  }
  BIO_free(out);

  return ret;
}

/***
openssl.pkcs7 object

@type pkcs7
*/
static int openssl_pkcs7_gc(lua_State *L)
{
  PKCS7 *p7 = CHECK_OBJECT(1, PKCS7, "openssl.pkcs7");
  PKCS7_free(p7);
  return 0;
}

/***
export pkcs7 as string

@function export
@tparam[opt='pem'] string support export as 'pem' or 'der' format, default is 'pem'
@treturn string
*/
static int openssl_pkcs7_export(lua_State *L)
{
  int    ret = 0;
  PKCS7 *p7 = CHECK_OBJECT(1, PKCS7, "openssl.pkcs7");
  int    fmt = luaL_checkoption(L, 2, "pem", format);

  BIO *bio_out = NULL;

  luaL_argcheck(L,
                fmt == FORMAT_PEM || fmt == FORMAT_DER || fmt == FORMAT_SMIME,
                2,
                "only accept pem, der or smime, default is pem");

  bio_out = BIO_new(BIO_s_mem());
  if (fmt == FORMAT_PEM)
    ret = PEM_write_bio_PKCS7(bio_out, p7);
  else if (fmt == FORMAT_DER)
    ret = i2d_PKCS7_bio(bio_out, p7);
  else if (fmt == FORMAT_SMIME)
    ret = SMIME_write_PKCS7(bio_out, p7, NULL, 0);

  if (ret == 1) {
    BUF_MEM *bio_buf;
    BIO_get_mem_ptr(bio_out, &bio_buf);
    lua_pushlstring(L, bio_buf->data, bio_buf->length);
    ret = 1;
  }

  BIO_free(bio_out);
  return ret == 1 ? 1 : openssl_pushresult(L, ret);
}

static int
openssl_push_pkcs7_signer_info(lua_State *L, PKCS7_SIGNER_INFO *info)
{
  lua_newtable(L);
  AUXILIAR_SET(L, -1, "version", ASN1_INTEGER_get(info->version), integer);

  if (info->issuer_and_serial != NULL) {
    X509_NAME    *i = X509_NAME_dup(info->issuer_and_serial->issuer);
    ASN1_INTEGER *s = ASN1_INTEGER_dup(info->issuer_and_serial->serial);
    if (info->issuer_and_serial->issuer)
      AUXILIAR_SETOBJECT(L, i, "openssl.x509_name", -1, "issuer");

    if (info->issuer_and_serial->serial)
      AUXILIAR_SETOBJECT(L, s, "openssl.asn1_integer", -1, "serial");
  }

  if (info->digest_alg) {
    X509_ALGOR *dup = X509_ALGOR_dup(info->digest_alg);
    AUXILIAR_SETOBJECT(L, dup, "openssl.x509_algor", -1, "digest_alg");
  }
  if (info->digest_enc_alg) {
    X509_ALGOR *dup = X509_ALGOR_dup(info->digest_alg);
    AUXILIAR_SETOBJECT(L, dup, "openssl.x509_algor", -1, "digest_enc_alg");
  }
  if (info->enc_digest) {
    ASN1_STRING *dup = ASN1_STRING_dup(info->enc_digest);
    AUXILIAR_SETOBJECT(L, dup, "openssl.asn1_string", -1, "enc_digest");
  }

  if (info->pkey) {
    EVP_PKEY_up_ref(info->pkey);
    AUXILIAR_SETOBJECT(L, info->pkey, "openssl.evp_pkey", -1, "pkey");
  }

  if (info->auth_attr) {
    openssl_sk_x509_attribute_totable(L, info->auth_attr);
    lua_setfield(L, -2, "auth_attr");
  }

  if (info->unauth_attr) {
    openssl_sk_x509_attribute_totable(L, info->unauth_attr);
    lua_setfield(L, -2, "unauth_attr");
  }

  return 1;
}

/***
get PKCS7 object type information
@function type
@treturn string short name of PKCS7 type
@treturn string long name of PKCS7 type
*/
static int openssl_pkcs7_type(lua_State *L)
{
  PKCS7 *p7 = CHECK_OBJECT(1, PKCS7, "openssl.pkcs7");
  int    i = OBJ_obj2nid(p7->type);

  lua_pushstring(L, OBJ_nid2sn(i));
  lua_pushstring(L, OBJ_nid2ln(i));
  return 2;
}

/***
export pkcs7 as a string

@function parse
@treturn table a table has pkcs7 infomation, include type,and other things relate to types
*/
static int openssl_pkcs7_parse(lua_State *L)
{
  PKCS7 *p7 = CHECK_OBJECT(1, PKCS7, "openssl.pkcs7");
  STACK_OF(X509) *certs = NULL;
  STACK_OF(X509_CRL) *crls = NULL;
  int i = OBJ_obj2nid(p7->type);

  lua_newtable(L);
  AUXILIAR_SET(L, -1, "type", OBJ_nid2ln(i), string);
  switch (i) {
  case NID_pkcs7_signed: {
    PKCS7_SIGNED *sign = p7->d.sign;
    certs = sign->cert ? sign->cert : NULL;
    crls = sign->crl ? sign->crl : NULL;

    AUXILIAR_SET(L, -1, "version", ASN1_INTEGER_get(sign->version), integer);
    AUXILIAR_SET(L, -1, "detached", PKCS7_is_detached(p7), boolean);
    lua_pushstring(L, "md_algs");
    openssl_sk_x509_algor_totable(L, sign->md_algs);
    lua_rawset(L, -3);

    if (sign->signer_info) {
      int j, n;
      n = sk_PKCS7_SIGNER_INFO_num(sign->signer_info);
      lua_pushstring(L, "signer_info");
      lua_newtable(L);
      for (j = 0; j < n; j++) {
        PKCS7_SIGNER_INFO *info = sk_PKCS7_SIGNER_INFO_value(sign->signer_info, j);
        lua_pushinteger(L, j + 1);
        openssl_push_pkcs7_signer_info(L, info);
        lua_rawset(L, -3);
      }
      lua_rawset(L, -3);
    }

    if (!PKCS7_is_detached(p7)) {
      PKCS7 *c = sign->contents;
      c = PKCS7_dup(c);
      AUXILIAR_SETOBJECT(L, c, "openssl.pkcs7", -1, "contents");
    }
  } break;
  case NID_pkcs7_signedAndEnveloped:
    certs = p7->d.signed_and_enveloped->cert;
    crls = p7->d.signed_and_enveloped->crl;
    break;
  case NID_pkcs7_enveloped: {
    /*
    BIO * mem = BIO_new(BIO_s_mem());
    BIO * v_p7bio = PKCS7_dataDecode(p7,pkey,NULL,NULL);
    BUF_MEM *bptr = NULL;
    unsigned char src[4096];
    int len;

    while((len = BIO_read(v_p7bio,src,4096))>0){
     BIO_write(mem, src, len);
    }
    BIO_free(v_p7bio);
    BIO_get_mem_ptr(mem, &bptr);
    if((int)*puiDataLen < bptr->length)
    {
     *puiDataLen = bptr->length;
     ret = SAR_MemoryErr;
    }else{
     *puiDataLen =  bptr->length;
     memcpy(pucData,bptr->data, bptr->length);
    }
    */
  } break;
  case NID_pkcs7_digest: {
    PKCS7_DIGEST *d = p7->d.digest;
    PUSH_ASN1_OCTET_STRING(L, d->digest);
    lua_setfield(L, -2, "digest");
  } break;
  case NID_pkcs7_data: {
    PUSH_ASN1_OCTET_STRING(L, p7->d.data);
    lua_setfield(L, -2, "data");
  } break;
  default:
    break;
  }

  /* NID_pkcs7_signed or NID_pkcs7_signedAndEnveloped */
  if (certs != NULL) {
    lua_pushstring(L, "certs");
    openssl_sk_x509_totable(L, certs);
    lua_rawset(L, -3);
  }
  if (crls != NULL) {
    lua_pushstring(L, "crls");
    openssl_sk_x509_crl_totable(L, crls);
    lua_rawset(L, -3);
  }
  return 1;
}

/***
set digest algorithm for PKCS7 structure
@function set_digest
@tparam string|evp_md digest algorithm name or digest object
@treturn boolean true on success, false on failure
*/
static int openssl_pkcs7_set_digest(lua_State *L)
{
  PKCS7        *p7 = CHECK_OBJECT(1, PKCS7, "openssl.pkcs7");
  const EVP_MD *md = get_digest(L, 2, NULL);

  int ret = PKCS7_set_digest(p7, md);
  openssl_pushresult(L, ret);

  return 1;
}

/***
finalize PKCS7 structure with data
@function final
@tparam openssl.pkcs7 p7 PKCS7 object to finalize
@tparam bio|string data data to finalize with
@tparam[opt=0] number flags finalization flags
@treturn boolean true on success, false on failure
*/
static int openssl_pkcs7_final(lua_State *L)
{
  PKCS7 *p7 = CHECK_OBJECT(1, PKCS7, "openssl.pkcs7");
  BIO   *data = load_bio_object(L, 2);
  int    flags = luaL_optint(L, 3, 0);

  int ret = PKCS7_final(p7, data, flags);
  openssl_pushresult(L, ret);
  BIO_free(data);

  return 1;
}

/***
verify pkcs7 object, and return msg content or verify result

@function verify
@tparam[opt] stack_of_x509 signercerts
@tparam[opt] x509_store cacerts
@tparam[opt] string|bio msg
@tparam[opt=0] number flags
@treturn[1] string content
@treturn[1] boolean result
*/

/***
decrypt encrypted pkcs7 message

@function decrypt
@tparam openssl.x509 recipcert
@tparam openssl.evp_pkey recipkey
@treturn string decrypt message
*/

static luaL_Reg pkcs7_funcs[] = {
  { "type",        openssl_pkcs7_type        },
  { "parse",       openssl_pkcs7_parse       },
  { "export",      openssl_pkcs7_export      },
  { "decrypt",     openssl_pkcs7_decrypt     },
  { "verify",      openssl_pkcs7_verify      },
  { "add",         openssl_pkcs7_add         },
  { "set_content", openssl_pkcs7_set_content },
  { "set_digest",  openssl_pkcs7_set_digest  },
  { "final",       openssl_pkcs7_final       },

  { "__gc",        openssl_pkcs7_gc          },
  { "__tostring",  auxiliar_tostring         },

  { NULL,          NULL                      }
};

static const luaL_Reg R[] = {
  { "new",     openssl_pkcs7_new     },
  { "create",  openssl_pkcs7_create  },
  { "read",    openssl_pkcs7_read    },
  { "sign",    openssl_pkcs7_sign    },
  { "verify",  openssl_pkcs7_verify  },
  { "encrypt", openssl_pkcs7_encrypt },
  { "decrypt", openssl_pkcs7_decrypt },

  { NULL,      NULL                  }
};

static LuaL_Enumeration pkcs7_const[] = {
  { "TEXT",          PKCS7_TEXT          },
  { "NOCERTS",       PKCS7_NOCERTS       },
  { "NOSIGS",        PKCS7_NOSIGS        },
  { "NOCHAIN",       PKCS7_NOCHAIN       },
  { "NOINTERN",      PKCS7_NOINTERN      },
  { "NOVERIFY",      PKCS7_NOVERIFY      },
  { "DETACHED",      PKCS7_DETACHED      },
  { "BINARY",        PKCS7_BINARY        },
  { "NOATTR",        PKCS7_NOATTR        },
  { "NOSMIMECAP",    PKCS7_NOSMIMECAP    },
  { "NOOLDMIMETYPE", PKCS7_NOOLDMIMETYPE },
  { "CRLFEOL",       PKCS7_CRLFEOL       },
  { "STREAM",        PKCS7_STREAM        },
  { "NOCRL",         PKCS7_NOCRL         },
  { "PARTIAL",       PKCS7_PARTIAL       },
  { "REUSE_DIGEST",  PKCS7_REUSE_DIGEST  },

  { NULL,            0                   }
};

int
luaopen_pkcs7(lua_State *L)
{
  auxiliar_newclass(L, "openssl.pkcs7", pkcs7_funcs);

  lua_newtable(L);
  luaL_setfuncs(L, R, 0);

  auxiliar_enumerate(L, -1, pkcs7_const);
  return 1;
}
