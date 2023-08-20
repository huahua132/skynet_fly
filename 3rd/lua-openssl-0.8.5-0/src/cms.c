/***
cms module for lua-openssl binding

The Cryptographic Message Syntax (CMS) is the IETF's standard for
cryptographically protected messages. It can be used to digitally sign, digest,
authenticate or encrypt any form of digital data. CMS is based on the syntax of
PKCS#7, which in turn is based on the Privacy-Enhanced Mail standard. The
newest version of CMS is specified in RFC 5652.

The architecture of CMS is built around certificate-based key management, such
as the profile defined by the PKIX working group. CMS is used as the key
cryptographic component of many other cryptographic standards, such as S/MIME,
PKCS #12 and the RFC 3161 Digital timestamping protocol.

OpenSSL is open source software that can encrypt, decrypt, sign and verify,
compress and uncompress CMS documents.


CMS are based on apps/cms.c from the OpenSSL dist, so for more information,
you better see the documentation for OpenSSL.
cms api need flags, not support "detached", "nodetached", "text", "nointern",
"noverify", "nochain", "nocerts", "noattr", "binary", "nosigs"

OpenSSL not give full document about CMS api, so some function will be dangers.

@module cms
@usage
  cms = require('openssl').cms
*/
#include "openssl.h"
#include "private.h"
#ifndef OPENSSL_NO_CMS
#include <openssl/cms.h>

static LuaL_Enumeration cms_flags[] =
{
  {"text",                  0x1},
  {"nocerts",               0x2},
  {"no_content_verify",     0x04},
  {"no_attr_verify",        0x8},
  {"nosigs",                (CMS_NO_CONTENT_VERIFY | CMS_NO_ATTR_VERIFY)},
  {"nointern",              0x10},
  {"no_signer_cert_verify", 0x20},
  {"noverify",              0x20},
  {"detached",              0x40},
  {"binary",                0x80},
  {"noattr",                0x100},
  {"nosmimecap",            0x200},
  {"nooldmimetype",         0x400},
  {"crlfeol",               0x800},
  {"stream",                0x1000},
  {"nocrl",                 0x2000},
  {"partial",               0x4000},
  {"reuse_digest",          0x8000},
  {"use_keyid",             0x10000},
  {"debug_decrypt",         0x20000},
  {NULL,                    -1}
};

/***
read cms object from input bio or string

@function read
@tparam bio|string input
@tparam[opt='auto'] string format, support 'auto','smime','der','pem'
  auto will only try 'der' or 'pem'
@tparam[opt=nil] bio content, only used when format is 'smime'
@treturn cms
*/
static int openssl_cms_read(lua_State *L)
{
  BIO* in = load_bio_object(L, 1);
  int fmt = luaL_checkoption(L, 2, "auto", format);
  BIO* data = NULL;
  int ret = 0;

  CMS_ContentInfo *cms = NULL;
  if (fmt == FORMAT_AUTO)
  {
    fmt = bio_is_der(in) ? FORMAT_DER : FORMAT_PEM;
  }
  if (fmt == FORMAT_DER)
  {
    cms = d2i_CMS_bio(in, NULL);
  }
  else if (fmt == FORMAT_PEM)
  {
    cms = PEM_read_bio_CMS(in, NULL, NULL, NULL);
  }
  else if (fmt == FORMAT_SMIME)
  {
    cms = SMIME_read_CMS(in, &data);
  }

  BIO_free(in);

  if (cms)
  {
    PUSH_OBJECT(cms, "openssl.cms");
    ret = 1;
    if(data!=NULL)
    {
      PUSH_OBJECT(data, "openssl.bio");
      ret = 2;
    }
  }
  return ret;
}

/***
write cms object to bio object

@function export
@tparam cms cms
@tparam[opt] bio data
@tparam[opt=0] number flags
@tparam[opt='smime'] string format
@treturn string
@return nil, and followed by error message
*/
static int openssl_cms_export(lua_State *L)
{
  CMS_ContentInfo *cms = CHECK_OBJECT(1, CMS_ContentInfo, "openssl.cms");
  BIO *in = lua_isnoneornil(L, 2) ? NULL : load_bio_object(L, 2);
  int flags = luaL_optint(L, 3, 0);
  int fmt = luaL_checkoption(L, 4, "smime", format);
  int ret = 0;
  BIO *out = BIO_new(BIO_s_mem());

  if (fmt == FORMAT_SMIME)
    ret = SMIME_write_CMS(out, cms, in, flags);
  else if (fmt == FORMAT_PEM)
    ret = PEM_write_bio_CMS_stream(out, cms, in, flags);
  else if (fmt == FORMAT_DER)
    ret = i2d_CMS_bio_stream(out, cms, in, flags);

  if (ret==1)
  {
    BUF_MEM *mem;
    BIO_get_mem_ptr(out, &mem);
    lua_pushlstring(L, mem->data, mem->length);
  }

  if(in!=NULL) BIO_free(in);
  if(out!=NULL) BIO_free(out);

  return (ret==1) ? 1 : openssl_pushresult(L, ret);
}

/***
create empty cms object
@function create
@treturn cms
*/

static int openssl_cms_new(lua_State*L)
{
  CMS_ContentInfo *cms = CMS_ContentInfo_new();
  int ret = 0;
  if (cms) {
    PUSH_OBJECT(cms, "openssl.cms");
    ret = 1;
  }
  return ret;
}

/***
create cms object from string or bio object
@function create
@tparam bio input
@tparam[opt=0] number flags
@treturn cms
*/
static int openssl_cms_data_create(lua_State *L)
{
  BIO* in = load_bio_object(L, 1);
  int flags = luaL_optint(L, 2, 0);
  int ret = 0;
  CMS_ContentInfo *cms = CMS_data_create(in, flags);
  BIO_free(in);
  if (cms) {
    PUSH_OBJECT(cms, "openssl.cms");
    ret = 1;
  }
  return ret;
}

static int openssl_compress_nid[] = {
  NID_zlib_compression,
#ifdef NID_rle_compression
  NID_rle_compression,
#endif
  NID_undef
};

/***
create compress cms object
@function compress
@tparam bio input
@tparam string alg, zlib or rle
@tparam[opt=0] number flags
@treturn cms
*/
static int openssl_cms_compress(lua_State *L)
{
  BIO* in = load_bio_object(L, 1);
  int ret = 0, nid = NID_undef;
  unsigned int flags = 0;
  const char* compress_options[] =
  {
    "zlib",
#ifdef NID_rle_compression
    "rle",
#endif
    NULL
  };
  CMS_ContentInfo *cms;

  nid = luaL_checkoption(L, 2, "zlib", compress_options);
  flags = luaL_optint(L, 3, 0);
  nid = openssl_compress_nid[nid];

  cms = CMS_compress(in, nid, flags);
  BIO_free(in);

  if (cms)
  {
    PUSH_OBJECT(cms, "openssl.cms");
    ret = 1;
  }
  else
    ret = openssl_pushresult(L, 0);

  return ret;
}

/***
uncompress cms object
@function uncompress
@tparam cms cms
@tparam bio input
@tparam[opt=0] number flags
@treturn string
*/
static int openssl_cms_uncompress(lua_State *L)
{
  CMS_ContentInfo *cms = CHECK_OBJECT(1, CMS_ContentInfo, "openssl.cms");
  BIO *in = load_bio_object(L, 2);
  int flags = luaL_optint(L, 3, 0);
  BIO *out = BIO_new(BIO_s_mem());

  int ret = CMS_uncompress(cms, in, out, flags);
  if (ret==1)
  {
    BUF_MEM *mem;
    BIO_get_mem_ptr(out, &mem);
    lua_pushlstring(L, mem->data, mem->length);
  }
  BIO_free(in);
  BIO_free(out);
  return ret == 1 ? 1 : openssl_pushresult(L, ret);
}

/***
make signed cms object

@function sign
@tparam x509 signer cert
@tparam evp_pkey pkey
@tparam bio input_data
@tparam[opt] stack_of_x509 certs include in the CMS
@tparam[opt=0] number flags
@treturn cms object
*/
static int openssl_cms_sign(lua_State *L)
{
  /* look aat apps/cms.c operation & SMIME_SIGNERS */
  X509* signcert = CHECK_OBJECT(1, X509, "openssl.x509");
  EVP_PKEY* pkey = CHECK_OBJECT(2, EVP_PKEY, "openssl.evp_pkey");
  BIO* data = load_bio_object(L, 3);
  STACK_OF(X509)* certs = openssl_sk_x509_fromtable(L, 4);
  unsigned int flags = luaL_optint(L, 5, 0);
  int ret = 0;

  CMS_ContentInfo *cms = CMS_sign(signcert, pkey, certs, data, flags);
  BIO_free(data);

  sk_X509_pop_free(certs, X509_free);
  if (cms)
  {
    PUSH_OBJECT(cms, "openssl.cms");
    ret = 1;
  }
  return ret;
}

/***
verfiy signed cms object
@function verify
@tparam cms signed
@tparam stack_of_x509 signers
@tparam[opt] x509_store store trust certificates store
@tparam[opt] bio message
@tparam[opt=0] number flags
@treturn string content
@return nil, and followed by error message
*/
static int openssl_cms_verify(lua_State *L)
{
  CMS_ContentInfo *cms = CHECK_OBJECT(1, CMS_ContentInfo, "openssl.cms");
  STACK_OF(X509)* signers = openssl_sk_x509_fromtable(L, 2);
  X509_STORE* trust = CHECK_OBJECT(3, X509_STORE, "openssl.x509_store");
  BIO* in = lua_isnoneornil(L, 4) ? NULL : load_bio_object(L, 4);
  unsigned int flags = luaL_optint(L, 5, 0);
  BIO* out = BIO_new(BIO_s_mem());
  int ret = CMS_verify(cms, signers, trust, in, out, flags);
  if (ret==1)
  {
    BUF_MEM *mem;
    BIO_get_mem_ptr(out, &mem);
    lua_pushlstring(L, mem->data, mem->length);
  }
  sk_X509_pop_free(signers, X509_free);

  if (in!=NULL) BIO_free(in);
  if (out!=NULL) BIO_free(out);

  return ret == 1 ? 1 : openssl_pushresult(L, ret);
}

/***
create enryptdata cms
@function EncryptedData_encrypt
@tparam bio|string input
@tparam strig key
@tparam[opt='des-ede3-cbc'] string|evp_cipher cipher_alg
@tparam[opt=0] number flags
@treturn cms object
@return nil, followed by error message
*/
static int openssl_cms_EncryptedData_encrypt(lua_State*L)
{
  BIO* in = load_bio_object(L, 1);
  size_t klen;
  const char* key = luaL_checklstring(L, 2, &klen);
  const EVP_CIPHER* ciphers = get_cipher(L, 3, "aes-128-cbc");
  unsigned int flags = luaL_optint(L, 4, 0);
  int ret = 0;

  CMS_ContentInfo *cms = CMS_EncryptedData_encrypt(in, ciphers,
                                                   (const unsigned char*) key,
                                                   klen,
                                                   flags);
  BIO_free(in);
  if (cms)
  {
    PUSH_OBJECT(cms, "openssl.cms");
    ret = 1;
  }
  return ret;
}

/***
decrypt encryptdata cms
@function EncryptedData_decrypt
@tparam cms encrypted
@tparam string key
@tparam[opt] bio dcont
@tparam[opt=0] number flags
@treturn boolean result
*/
static int openssl_cms_EncryptedData_decrypt(lua_State*L)
{
  CMS_ContentInfo *cms = CHECK_OBJECT(1, CMS_ContentInfo, "openssl.cms");
  size_t klen;
  const char* key = luaL_checklstring(L, 2, &klen);
  BIO* dcont = lua_isnoneornil(L, 3) ? NULL : load_bio_object(L, 3);
  unsigned int flags = luaL_optint(L, 4, 0);
  BIO *out = BIO_new(BIO_s_mem());

  int ret = CMS_EncryptedData_decrypt(cms, (const unsigned char*)key, klen, dcont, out, flags);
  if(ret==1)
  {
    BUF_MEM *mem;
    BIO_get_mem_ptr(out, &mem);
    lua_pushlstring(L, mem->data, mem->length);
  }
  BIO_free(dcont);
  BIO_free(out);
  return ret==1 ? 1 : openssl_pushresult(L, ret);
}

/***
create digest cms
@function digest_create
@tparam bio|string input
@tparam[opt='sha256'] string|evp_md digest_alg
@tparam[opt=0] number flags
@treturn cms object
@return nil, followed by error message
*/
static int openssl_cms_digest_create(lua_State*L)
{
  BIO* in = load_bio_object(L, 1);
  const EVP_MD* md = get_digest(L, 2, "sha256");
  unsigned int flags = luaL_optint(L, 3, 0);
  int ret = 0;

  CMS_ContentInfo *cms = CMS_digest_create(in, md, flags);
  BIO_free(in);
  if (cms)
  {
    PUSH_OBJECT(cms, "openssl.cms");
    ret = 1;
  }
  return ret;
}

/***
verify digest cms
@function digest_verify
@tparam cms digested
@tparam[opt] string|bio dcont
@tparam[opt=0] number flags
@treturn boolean result
*/
static int openssl_cms_digest_verify(lua_State*L)
{
  CMS_ContentInfo *cms = CHECK_OBJECT(1, CMS_ContentInfo, "openssl.cms");
  BIO *dcont = lua_isnoneornil(L, 2) ? NULL : load_bio_object(L, 2);
  unsigned int flags = luaL_optint(L, 3, 0);
  BIO *out = BIO_new(BIO_s_mem());

  int ret = CMS_digest_verify(cms, dcont, out, flags);
  if(ret==1)
  {
    BUF_MEM *mem;
    BIO_get_mem_ptr(out, &mem);
    lua_pushlstring(L, mem->data, mem->length);
  }
  BIO_free(dcont);
  BIO_free(out);

  return ret==1 ? 1 : openssl_pushresult(L, ret);
}

static char *memdup(const char *src, size_t len)
{
  int add = 0;
  char *buffer;

  if (src && len > 0)
  {
    add = 1;
  }
  else
    /* no len and a NULL src pointer! */
    return strdup("");

  buffer = malloc(len + add);
  if (!buffer) return NULL; /* fail */

  memcpy(buffer, src, len);

  /* if len unknown do null termination */
  if (add) buffer[len] = '\0';

  return buffer;
}

/***
encrypt with recipt certs
@function encrypt
@tparam stack_of_x509 recipt certs
@tparam bio|string input
@tparam[opt='des-ede3-cbc'] string|evp_cipher cipher_alg
@tparam[opt=0] number flags
@tparam[opt=nil] table options, support key, keyid, password fields,
  and values must be string type
@treturn cms
*/
static int openssl_cms_encrypt(lua_State *L)
{
  BIO* in = load_bio_object(L, 1);
  STACK_OF(X509)* encerts = openssl_sk_x509_fromtable(L, 2);
  const EVP_CIPHER* ciphers = get_cipher(L, 3, "aes-128-cbc");
  unsigned int flags = luaL_optint(L, 4, CMS_PARTIAL);

  CMS_ContentInfo *cms = CMS_encrypt(encerts, in, ciphers, flags);
  int ret = 1;
  if (cms)
  {
    if (lua_istable(L, 2))
    {
      CMS_RecipientInfo *recipient;

      lua_getfield(L, 2, "key");
      lua_getfield(L, 2, "keyid");
      if (lua_isstring(L, -1) && lua_isstring(L, -2))
      {
        size_t keylen, keyidlen;

        const char* key = luaL_checklstring(L, -2, &keylen);
        const char* keyid = luaL_checklstring(L, -1, &keyidlen);

        key = memdup(key, keylen);
        keyid =  memdup(keyid, keyidlen);

        recipient = CMS_add0_recipient_key(cms, NID_undef,
                                           (unsigned char*)key, keylen,
                                           (unsigned char*)keyid, keyidlen,
                                           NULL, NULL, NULL);
        if (!recipient)
          ret = 0;
      }
      else if (!lua_isnil(L, -1) || !lua_isnil(L, -2))
      {
        luaL_argerror(L, 2, "key and keyid field must be string");
      }
      lua_pop(L, 2);

      if (ret)
      {
        lua_getfield(L, 2, "password");
        if (lua_isstring(L, -1))
        {
          const char *passwd = lua_tostring(L, -1);
          passwd = OPENSSL_strdup(passwd);
          recipient = CMS_add0_recipient_password(cms,
                                                  -1, NID_undef, NID_undef,
                                                  (unsigned char *)passwd, -1, NULL);
          if (!recipient)
            ret = 0;
          passwd = NULL;
        }
        else if (!lua_isnil(L, -1))
        {
          luaL_argerror(L, 2, "password field must be string");
        }
        lua_pop(L, 1);
      }
    }

    if (ret)
    {
      if (!(flags & CMS_STREAM))
        ret = CMS_final(cms, in, NULL, flags);
    }
  }
  BIO_free(in);
  sk_X509_pop_free(encerts, X509_free);
  if (ret == 1)
    PUSH_OBJECT(cms, "openssl.cms");
  else
    ret = openssl_pushresult(L, ret);
  return ret;
}

/***
decrypt cms message
@function decrypt
@tparam cms message
@tparam evp_pkey pkey
@tparam x509 recipt
@tparam[opt] bio dcount output object
@tparam[opt=0] number flags
@tparam[opt=nil] table options may have key, keyid, password field,
  and values must be string type
@treturn string decrypted message
@return nil, and followed by error message
*/
static int openssl_cms_decrypt(lua_State *L)
{
  CMS_ContentInfo *cms = CHECK_OBJECT(1, CMS_ContentInfo, "openssl.cms");
  EVP_PKEY* pkey = CHECK_OBJECT(2, EVP_PKEY, "openssl.evp_pkey");
  X509* x509 = CHECK_OBJECT(3, X509, "openssl.x509");
  BIO* dcont = lua_isnoneornil(L, 4) ? NULL : load_bio_object(L, 4);
  unsigned int flags = luaL_optint(L, 5, 0);
  int ret = 1;
  BIO* out = BIO_new(BIO_s_mem());

  if (lua_istable(L, 6))
  {
    lua_getfield(L, 6, "password");
    if (lua_isstring(L, -1))
    {
      unsigned char*passwd = (unsigned char*)lua_tostring(L, -1);
      ret = CMS_decrypt_set1_password(cms, passwd, -1);
    }
    else if (!lua_isnil(L, -1))
    {
      luaL_argerror(L, 7, "password field must be string");
    }
    lua_pop(L, 1);
    if (ret)
    {
      lua_getfield(L, 6, "key");
      lua_getfield(L, 6, "keyid");
      if (lua_isstring(L, -1) && lua_isstring(L, -2))
      {
        size_t keylen, keyidlen;
        unsigned char*key = (unsigned char*)lua_tolstring(L, -2, &keylen);
        unsigned char*keyid = (unsigned char*)lua_tolstring(L, -1, &keyidlen);
        ret = CMS_decrypt_set1_key(cms, key, keylen, keyid, keyidlen);
      }
      else if (!lua_isnil(L, -1) || !lua_isnil(L, -2))
      {
        luaL_argerror(L, 6, "key and keyid field must be string");
      }
      lua_pop(L, 2);
    }
  }

  if (ret == 1)
  {
    ret = CMS_decrypt_set1_pkey(cms, pkey, x509);
    if (ret == 1)
    {
      ret = CMS_decrypt(cms, NULL, NULL, dcont, out, flags);

      if (ret == 1)
      {
        BUF_MEM *mem;
        BIO_get_mem_ptr(out, &mem);
        lua_pushlstring(L, mem->data, mem->length);
      }
    }
  }


  if (dcont) BIO_free(dcont);
  BIO_free(out);

  return ret == 1 ? 1 : openssl_pushresult(L, ret);
}

static const luaL_Reg R[] =
{
  {"read",                  openssl_cms_read},
  {"export",                openssl_cms_export},

  {"new",                   openssl_cms_new},
  {"data",                  openssl_cms_data_create},
  {"compress",              openssl_cms_compress},
  {"uncompress",            openssl_cms_uncompress},

  {"sign",                  openssl_cms_sign},
  {"verify",                openssl_cms_verify},
  {"encrypt",               openssl_cms_encrypt},
  {"decrypt",               openssl_cms_decrypt},

  {"digest",                openssl_cms_digest_create},
  {"digest_create",         openssl_cms_digest_create},
  {"digest_verify",         openssl_cms_digest_verify},

  {"EncryptedData_encrypt", openssl_cms_EncryptedData_encrypt},
  {"EncryptedData_decrypt", openssl_cms_EncryptedData_decrypt},

  {NULL,  NULL}
};

/*****************************************************************************/
/***
openssl.cms object
@type cms
@warning some api undocumented, dangers!!!
*/

/***
get type of cms object
@function cms
@treturn asn1_object type of cms
*/
static int openssl_cms_type(lua_State *L)
{
  CMS_ContentInfo *cms = CHECK_OBJECT(1, CMS_ContentInfo, "openssl.cms");
  const ASN1_OBJECT *obj = CMS_get0_type(cms);
  PUSH_OBJECT(obj, "openssl.asn1_object");

  return 1;
}

/***
get detached state
@function detached
@treturn boolean true for detached
@tparam bio cmsbio bio returned by datainit
@treturn boolean true for success, others value will followed by error message
@warning inner use
*/
/***
set detached state
@function detached
@tparam boolean detach
@treturn boolean for success, others value will followed by error message
@warning inner use
*/
static int openssl_cms_detached(lua_State *L)
{
  CMS_ContentInfo *cms = CHECK_OBJECT(1, CMS_ContentInfo, "openssl.cms");
  int ret = 0;
  if (lua_isnone(L, 2))
  {
    ret = CMS_is_detached(cms);
    lua_pushboolean(L, ret);
    return 1;
  }
  else
  {
    int detached = auxiliar_checkboolean(L, 2);
    ret = CMS_set_detached(cms, detached);
  }
  return 1;
}

/***
get content of cms object
@function content
@treturn string content, if have no content will return nil
@warning inner use
*/
static int openssl_cms_content(lua_State *L)
{
  CMS_ContentInfo *cms = CHECK_OBJECT(1, CMS_ContentInfo, "openssl.cms");
  ASN1_OCTET_STRING** content = CMS_get0_content(cms);
  int ret = 0;
  if (content && *content)
  {
    ASN1_OCTET_STRING* s = *content;
    lua_pushlstring(L, (const char*)ASN1_STRING_get0_data(s), ASN1_STRING_length(s));
    ret = 1;
  }
  return ret;
}

static int openssl_cms_get_signers(lua_State*L)
{
  CMS_ContentInfo *cms = CHECK_OBJECT(1, CMS_ContentInfo, "openssl.cms");
  STACK_OF(X509) *signers = CMS_get0_signers(cms);
  int ret = 0;
  if (signers)
  {
    openssl_sk_x509_totable(L, signers);
    sk_X509_free(signers);
    ret = 1;
  }
  return ret;
}

static int openssl_cms_data(lua_State *L)
{
  CMS_ContentInfo *cms = CHECK_OBJECT(1, CMS_ContentInfo, "openssl.cms");
  unsigned int flags = luaL_optint(L, 2, 0);
  BIO *out = BIO_new(BIO_s_mem());

  int ret = CMS_data(cms, out, flags);
  if (ret==1)
  {
    BUF_MEM *mem;
    BIO_get_mem_ptr(out, &mem);
    lua_pushlstring(L, mem->data, mem->length);
  }else
    ret = openssl_pushresult(L, ret);
  BIO_free(out);
  return ret;
}

static int openssl_cms_final(lua_State*L)
{
  CMS_ContentInfo *cms = CHECK_OBJECT(1, CMS_ContentInfo, "openssl.cms");
  BIO* in = load_bio_object(L, 2);
  int flags = luaL_optint(L, 3, CMS_STREAM);

  int ret = CMS_final(cms, in, NULL, flags);
  BIO_free(in);
  return openssl_pushresult(L, ret);
}

/*
 * FIXME: fix and enable this
static int openssl_cms_sign_receipt(lua_State*L)
{
  CMS_ContentInfo *cms = CHECK_OBJECT(1, CMS_ContentInfo, "openssl.cms");
  X509 *signcert = CHECK_OBJECT(2, X509, "openssl.x509");
  EVP_PKEY* pkey = CHECK_OBJECT(3, EVP_PKEY, "openssl.evp_pkey");
  STACK_OF(X509) *other = openssl_sk_x509_fromtable(L, 4);
  unsigned int flags = luaL_optint(L, 5, 0);

  STACK_OF(CMS_SignerInfo) *sis = CMS_get0_SignerInfos(cms);
  if (sis)
  {
    CMS_SignerInfo *si = sk_CMS_SignerInfo_value(sis, 0);
    CMS_ContentInfo *srcms = CMS_sign_receipt(si, signcert, pkey, other, flags);
    if (srcms)
    {
      PUSH_OBJECT(srcms, "openssl.cms");
      sk_X509_pop_free(other, X509_free);
      return 1;
    }
  }
  sk_X509_pop_free(other, X509_free);
  return openssl_pushresult(L, 0);
}

static int openssl_cms_verify_receipt(lua_State*L)
{
  CMS_ContentInfo *rcms = CHECK_OBJECT(1, CMS_ContentInfo, "openssl.cms");
  CMS_ContentInfo *cms = CHECK_OBJECT(2, CMS_ContentInfo, "openssl.cms");
  STACK_OF(X509) *other = openssl_sk_x509_fromtable(L, 3);
  X509_STORE* store = CHECK_OBJECT(4, X509_STORE, "openssl.x509_store");
  unsigned int flags = luaL_optint(L, 5, 0);

  int ret = CMS_verify_receipt(rcms, cms, other, store, flags);
  lua_pushboolean(L, ret>0);
  return 1;
}
*/

static int openssl_cms_free(lua_State *L)
{
  CMS_ContentInfo *cms = CHECK_OBJECT(1, CMS_ContentInfo, "openssl.cms");
  CMS_ContentInfo_free(cms);

  return 0;
}

static luaL_Reg cms_ctx_funs[] =
{
  {"type",          openssl_cms_type},
  {"content",       openssl_cms_content},

  {"detached",      openssl_cms_detached},
  {"export",        openssl_cms_export},

  /* data */
  {"data",          openssl_cms_data},
  /* digest */
  {"verify",        openssl_cms_digest_verify},

  {"signers",       openssl_cms_get_signers},

/*
  {"sign_receipt",  openssl_cms_sign_receipt},
  {"verify_receipt",openssl_cms_verify_receipt},
*/

  {"final",         openssl_cms_final},

  {"__tostring",    auxiliar_tostring},
  {"__gc",          openssl_cms_free},
  {NULL,            NULL}
};

/* int CMS_stream(unsigned char ***boundary, CMS_ContentInfo *cms); */
#endif

int luaopen_cms(lua_State *L)
{
#ifndef OPENSSL_NO_CMS
#if OPENSSL_VERSION_NUMBER < 0x30000000
  ERR_load_CMS_strings();
#endif

  auxiliar_newclass(L, "openssl.cms",  cms_ctx_funs);

  lua_newtable(L);
  luaL_setfuncs(L, R, 0);

#if !defined(OPENSSL_NO_COMP)
  lua_newtable(L);
  lua_pushliteral(L, "zlib");
  lua_rawseti(L, -2, 1);
#ifdef NID_rle_compression
  lua_pushliteral(L, "rle");
  lua_rawseti(L, -2, 1);
#endif
  lua_setfield(L, -2, "compression");
#endif

  auxiliar_enumerate(L, -1, cms_flags);
#else
  lua_pushnil(L);
#endif
  return 1;
}
