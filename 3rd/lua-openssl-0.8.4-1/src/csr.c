/***
x509.req module to mapping `X509_REQ` to lua object, creates and processes certificate requests (CSRs) in PKCS#10 format.

@module x509.req
@usage
  req = require'openssl'.x509.req
*/

#include "openssl.h"
#include "private.h"

#if OPENSSL_VERSION_NUMBER < 0x1010000fL || \
	(defined(LIBRESSL_VERSION_NUMBER) && (LIBRESSL_VERSION_NUMBER < 0x20700000L))
#define X509_get0_notBefore X509_get_notBefore
#define X509_get0_notAfter X509_get_notAfter
#define X509_set1_notBefore X509_set_notBefore
#define X509_set1_notAfter X509_set_notAfter
#endif

/***
read x509_req from string or bio input
@function read
@tparam bio|string input input data
@tparam[opt='auto'] string format support 'auto','pem','der'
@treturn x509_req certificate sign request object
*/
static LUA_FUNCTION(openssl_csr_read)
{
  BIO * in = load_bio_object(L, 1);
  int fmt = luaL_checkoption(L, 2, "auto", format);
  X509_REQ * csr = NULL;

  if (fmt == FORMAT_AUTO)
  {
    fmt = bio_is_der(in) ? FORMAT_DER : FORMAT_PEM;
  }

  if (fmt == FORMAT_PEM)
  {
    csr = PEM_read_bio_X509_REQ(in, NULL, NULL, NULL);
    (void)BIO_reset(in);
  }
  else if (fmt == FORMAT_DER)
  {
    csr = d2i_X509_REQ_bio(in, NULL);
    (void)BIO_reset(in);
  }
  BIO_free(in);

  if (csr)
    PUSH_OBJECT(csr, "openssl.x509_req");
  return csr ? 1 : openssl_pushresult(L, 0);
}

/***
create or generate a new x509_req object.
Note if not give evp_pkey, will create a new x509_req object,or will generate a signed x509_req object.
@function new
@tparam[opt] x509_name subject subject name set to x509_req
@tparam[opt] stack_of_x509_extension extensions add to x509_req
@tparam[opt] stack_of_x509_attribute attributes add to x509_req
@tparam[opt] evp_pkey pkey private key sign the x509_req, and set as public key
@tparam[opt='sha1WithRSAEncryption'] evp_digest|string md_alg,  only used when pkey exist, and should fellow pkey
@treturn x509_req certificate sign request object
@see x509_req
*/
static LUA_FUNCTION(openssl_csr_new)
{
  X509_REQ *csr = X509_REQ_new();
  int i;
  int n = lua_gettop(L);
  int ret = X509_REQ_set_version(csr, 0L);

  for (i = 1; ret == 1 && i <= n; i++)
  {
    luaL_argcheck(L,
                  auxiliar_getclassudata(L, "openssl.x509_name", i) ||
                  auxiliar_getclassudata(L, "openssl.evp_pkey", i),
                  i, "must be x509_name or evp_pkey");
    if (auxiliar_getclassudata(L, "openssl.x509_name", i))
    {
      X509_NAME * subject = CHECK_OBJECT(i, X509_NAME, "openssl.x509_name");
      ret = X509_REQ_set_subject_name(csr, subject);
    }
    if (auxiliar_getclassudata(L, "openssl.evp_pkey", i))
    {
      EVP_PKEY *pkey;
      const EVP_MD *md;
      luaL_argcheck(L, i == n || i == n - 1, i, "must is evp_pkey object");

      pkey = CHECK_OBJECT(i, EVP_PKEY, "openssl.evp_pkey");

      if (i == n - 1)
        md = get_digest(L, n, NULL);
      else
        md = EVP_get_digestbyname("sha256");

      ret = X509_REQ_set_pubkey(csr, pkey);
      if (ret == 1)
      {
        ret = X509_REQ_sign(csr, pkey, md);
        if (ret > 0)
          ret = 1;
      }
      break;
    }
  };

  if (ret == 1)
    PUSH_OBJECT(csr, "openssl.x509_req");
  else
  {
    X509_REQ_free(csr);
    csr = NULL;
  }
  return csr ? 1 : openssl_pushresult(L, ret);
}

static luaL_Reg R[] =
{
  {"new",       openssl_csr_new },
  {"read",      openssl_csr_read  },

  {NULL,    NULL}
};

static int copy_extensions(X509 *x, X509_REQ *req, int override)
{
  STACK_OF(X509_EXTENSION) *exts = NULL;
  X509_EXTENSION *ext, *tmpext;
  ASN1_OBJECT *obj;
  int i, idx, ret = 0;
  if (!x || !req)
    return 1;
  exts = X509_REQ_get_extensions(req);

  for (i = 0; i < sk_X509_EXTENSION_num(exts); i++) {
    ext = sk_X509_EXTENSION_value(exts, i);
    obj = X509_EXTENSION_get_object(ext);
    idx = X509_get_ext_by_OBJ(x, obj, -1);
    /* Does extension exist? */
    if (idx != -1) {
      /* If normal copy don't override existing extension */
      if (override == 0)
        continue;
      /* Delete all extensions of same type */
      do {
        tmpext = X509_get_ext(x, idx);
        X509_delete_ext(x, idx);
        X509_EXTENSION_free(tmpext);
        idx = X509_get_ext_by_OBJ(x, obj, -1);
      } while (idx != -1);
    }
    if (!X509_add_ext(x, ext, -1))
      goto end;
  }

  ret = 1;

 end:

  sk_X509_EXTENSION_pop_free(exts, X509_EXTENSION_free);

  return ret;
}
static int X509_REQ_to_X509_ex(X509_REQ *r, int days, EVP_PKEY *pkey, const EVP_MD* md, X509 **x)
{
  X509 *ret = NULL;
  X509_NAME *xn = NULL;
  EVP_PKEY *pubkey = NULL;
  ASN1_TIME *notBefore = NULL, *notAfter = NULL;
  ASN1_INTEGER *serial = NULL;

  time_t tm;
  int res;

  if ((ret = X509_new()) == NULL)
  {
    return ERR_R_MALLOC_FAILURE;
  }

  /* duplicate the request */
  X509_set_version(ret, 2);

  serial = ASN1_INTEGER_new();
  if (serial == NULL)
    return ERR_R_MALLOC_FAILURE;

  if ( (res = ASN1_INTEGER_set(serial, 0xca)) != 1 ||
    (res = X509_set_serialNumber(ret, serial)) != 1)
    goto err;
  ASN1_INTEGER_free(serial);
  serial = NULL;

  xn = X509_REQ_get_subject_name(r);
  if ((res = X509_set_subject_name(ret, xn)) != 1)
    goto err;
  if ((res = X509_set_issuer_name(ret, xn)) != 1)
    goto err;

  tm = time(NULL);
  notBefore = ASN1_TIME_adj(NULL, tm, 0, 0);
  if (notBefore == NULL)
  {
    res = ERR_R_MALLOC_FAILURE;
    goto err;
  }

  if ((res = X509_set1_notBefore(ret, notBefore)) != 1)
    goto err;
  ASN1_TIME_free(notBefore);
  notBefore = NULL;

  notAfter = ASN1_TIME_adj(NULL, tm, days, 0);
  if (notAfter == NULL)
  {
    res = ERR_R_MALLOC_FAILURE;
    goto err;
  }
  if ((res = X509_set1_notAfter(ret, notAfter)) != 1)
    goto err;
  ASN1_TIME_free(notAfter);
  notAfter = NULL;

  if ((res = copy_extensions(ret, r, 1))!=1)
    goto err;

  pubkey = X509_REQ_get_pubkey(r);
  res = X509_set_pubkey(ret, pubkey);
  EVP_PKEY_free(pubkey);
  if (res != 1)
    goto err;

  if ((res = X509_sign(ret, pkey, md)) == 0)
    goto err;
  res = 1;

  *x = ret;
  return res;

err:
  X509_free(ret);
  return (res);
}

/***
openssl.x509_req object
@type x509_req
*/

/***
convert x509_req to x509 object and sign it
@function to_x509
@tparam x509_req csr
@tparam evp_pkey prikey
@tparam[opt=365] number days
@tparam[opt='sha256'] evp_md|string md_alg default use sha256
@treturn x509 object not signed
*/
static LUA_FUNCTION(openssl_csr_to_x509)
{
  X509_REQ * csr  = CHECK_OBJECT(1, X509_REQ, "openssl.x509_req");
  EVP_PKEY * pkey = CHECK_OBJECT(2, EVP_PKEY, "openssl.evp_pkey");
  int days = luaL_optint(L, 3, 365);
  const EVP_MD* md = get_digest(L, 4, "sha256");
  X509* cert = NULL;
  int ret;

  /*
    X509_REQ_to_X509 default use EVP_md5() as digest method
    X509* cert = X509_REQ_to_X509(csr, days, pkey);
  */
  ret = X509_REQ_to_X509_ex(csr, days, pkey, md, &cert);

  if (ret == 1 && cert)
  {
    PUSH_OBJECT(cert, "openssl.x509");
  } else
    ret = openssl_pushresult(L, ret);
  return ret;
}

/***
export x509_req to string
@function export
@tparam[opt='pem'] string format
@treturn string
*/
static LUA_FUNCTION(openssl_csr_export)
{
  X509_REQ * csr = CHECK_OBJECT(1, X509_REQ, "openssl.x509_req");
  int fmt = luaL_checkoption(L, 2, "pem", format);
  BIO *out  = NULL;
  int ret;

  luaL_argcheck(L,
                fmt == FORMAT_DER || fmt == FORMAT_PEM,
                2,
                "only accept der or pem");
  out = BIO_new(BIO_s_mem());

  ret = fmt == FORMAT_PEM ? PEM_write_bio_X509_REQ(out, csr)
                          : i2d_X509_REQ_bio(out, csr);
  if (ret==1)
  {
    BUF_MEM *bio_buf;

    BIO_get_mem_ptr(out, &bio_buf);
    lua_pushlstring(L, bio_buf->data, bio_buf->length);
  }

  BIO_free(out);
  return ret==1 ? 1 : openssl_pushresult(L, ret);
}

/***
get digest of x509_req
@function digest
@tparam[opt='sha256'] evp_md|string md_alg default use sha256
@treturn string digest result
*/
static LUA_FUNCTION(openssl_csr_digest)
{
  X509_REQ *csr = CHECK_OBJECT(1, X509_REQ, "openssl.x509_req");
  unsigned char buf[EVP_MAX_MD_SIZE];
  unsigned int len = sizeof(buf);
  const EVP_MD *md = get_digest(L, 2, "sha256");

  int ret = X509_REQ_digest(csr, md, buf, &len);
  if (ret == 1)
    lua_pushlstring(L, (const char*)buf, len);
  return ret==1 ? 1 : openssl_pushresult(L, ret);
};

/***
check x509_req with evp_pkey
@function check
@tparam evp_pkey pkey
@treturn boolean result true for check pass
*/
static LUA_FUNCTION(openssl_csr_check)
{
  X509_REQ *csr = CHECK_OBJECT(1, X509_REQ, "openssl.x509_req");
  EVP_PKEY *pkey = CHECK_OBJECT(2, EVP_PKEY, "openssl.evp_pkey");
  int ret = X509_REQ_check_private_key(csr, pkey);
  return openssl_pushresult(L, ret);
};

/***
clone x509_req object
@function dup
@treturn x509_req object
*/
static LUA_FUNCTION(openssl_csr_dup)
{
  X509_REQ *csr = CHECK_OBJECT(1, X509_REQ, "openssl.x509_req");
  csr = X509_REQ_dup(csr);
  PUSH_OBJECT(csr, "openssl.x509_req");
  return 1;
};

/***
verify x509_req signature
@function verify
@treturn boolean result true for verify pass
*/
static LUA_FUNCTION(openssl_csr_verify)
{
  X509_REQ *csr = CHECK_OBJECT(1, X509_REQ, "openssl.x509_req");
  EVP_PKEY * self_key = X509_REQ_get_pubkey(csr);
  if (self_key)
  {
    lua_pushboolean(L, X509_REQ_verify(csr, self_key) == 1);
    EVP_PKEY_free(self_key);
  }
  else
    lua_pushboolean(L, 0);
  return 1;
};

/***
sign x509_req object

@function sign
@tparam evp_pkey pkey private key which to sign x509_req object
@tparam number|string|evp_md md message digest alg used to sign
@treturn boolean result true for suceess
*/
static LUA_FUNCTION(openssl_csr_sign)
{
  X509_REQ * csr = CHECK_OBJECT(1, X509_REQ, "openssl.x509_req");
  EVP_PKEY *pubkey = X509_REQ_get_pubkey(csr);

  if (auxiliar_getclassudata(L, "openssl.evp_pkey", 2))
  {
    EVP_PKEY *pkey = CHECK_OBJECT(2, EVP_PKEY, "openssl.evp_pkey");
    const EVP_MD* md = get_digest(L, 3, "sha256");
    int ret = 0;

    if (pubkey == NULL)
    {
      BIO* bio = BIO_new(BIO_s_mem());
      ret = i2d_PUBKEY_bio(bio, pkey);
      if (ret == 1)
      {
        ret = 0;
        pubkey = d2i_PUBKEY_bio(bio, NULL);
        if (pubkey)
        {
          ret = X509_REQ_set_pubkey(csr, pubkey);
          EVP_PKEY_free(pubkey);
        }
      }

      BIO_free(bio);
    }
    else
    {
      EVP_PKEY_free(pubkey);
    }
    if (ret == 1)
      ret = X509_REQ_sign(csr, pkey, md);
    return openssl_pushresult(L, ret);
  }
  else if (lua_isstring(L, 2))
  {
    size_t siglen;
    unsigned char* sigdata = (unsigned char*)luaL_checklstring(L, 2, &siglen);
    const EVP_MD* md = get_digest(L, 3, NULL);
    ASN1_BIT_STRING *sig = NULL;
    X509_ALGOR *alg = NULL;

    luaL_argcheck(L, pubkey != NULL, 1, "has not set public key!!!");

    X509_REQ_get0_signature(csr, (const ASN1_BIT_STRING **)&sig, (const X509_ALGOR **)&alg);
    /* (pkey->ameth->pkey_flags & ASN1_PKEY_SIGPARAM_NULL) ? V_ASN1_NULL : V_ASN1_UNDEF, */
    X509_ALGOR_set0((X509_ALGOR *)alg, OBJ_nid2obj(EVP_MD_pkey_type(md)), V_ASN1_NULL, NULL);

    ASN1_BIT_STRING_set((ASN1_BIT_STRING *)sig, sigdata, siglen);
    /*
    * In the interests of compatibility, I'll make sure that the bit string
    * has a 'not-used bits' value of 0
    */
    sig->flags &= ~(ASN1_STRING_FLAG_BITS_LEFT | 0x07);
    sig->flags |= ASN1_STRING_FLAG_BITS_LEFT;
    lua_pushboolean(L, 1);
    return 1;
  }
  else
  {
    int inl;
    unsigned char* tosign = NULL;
    luaL_argcheck(L, pubkey != NULL, 1, "has not set public key!!!");

    inl = i2d_re_X509_REQ_tbs(csr, &tosign);
    if (inl > 0 && tosign)
    {
      lua_pushlstring(L, (const char*)tosign, inl);
      OPENSSL_free(tosign);
      return 1;
    }
    return openssl_pushresult(L, 0);
  }
}

/***
parse x509_req object as table
@function parse
@tparam[opt=true] shortname default will use short object name
@treturn table result
*/
static LUA_FUNCTION(openssl_csr_parse)
{
  X509_REQ *csr = CHECK_OBJECT(1, X509_REQ, "openssl.x509_req");
  X509_NAME *subject = X509_REQ_get_subject_name(csr);
  STACK_OF(X509_EXTENSION) *exts  = X509_REQ_get_extensions(csr);

  lua_newtable(L);
  {
    const ASN1_BIT_STRING *sig = NULL;
    const X509_ALGOR *alg = NULL;

    X509_REQ_get0_signature(csr, &sig, &alg);

    if (OBJ_obj2nid(alg->algorithm)!=NID_undef)
    {
      alg = X509_ALGOR_dup((X509_ALGOR *)alg);
      PUSH_OBJECT(alg, "openssl.x509_algor");
      lua_setfield(L, -2, "sig_alg");
    }
    if (sig->length)
    {
      openssl_push_asn1(L, sig, V_ASN1_BIT_STRING);
      lua_setfield(L, -2, "signature");

    }
  }

  lua_newtable(L);
  AUXILIAR_SET(L, -1, "version", X509_REQ_get_version(csr), integer);
  openssl_push_xname_asobject(L, subject);
  lua_setfield(L, -2, "subject");
  if (exts)
  {
    lua_pushstring(L, "extensions");
    openssl_sk_x509_extension_totable(L, exts);
    lua_rawset(L, -3);
    sk_X509_EXTENSION_pop_free(exts, X509_EXTENSION_free);
  }

  {
    X509_PUBKEY *xpub = X509_REQ_get_X509_PUBKEY(csr);
    EVP_PKEY *pubkey = X509_PUBKEY_get(xpub);
    ASN1_OBJECT *oalg = NULL;
    int c;

    lua_newtable(L);
    c = X509_REQ_get_attr_count(csr);
    if (c > 0)
    {
      int i;
      lua_newtable(L);
      for (i = 0; i < c ; i++)
      {
        X509_ATTRIBUTE *attr = X509_REQ_get_attr(csr, i);
        attr = X509_ATTRIBUTE_dup(attr);
        PUSH_OBJECT(attr, "openssl.x509_attribute");
        lua_rawseti(L, -2, i + 1);
      }
      lua_setfield(L, -2, "attributes");
    }


    if (pubkey)
    {

      lua_newtable(L);
      if (X509_PUBKEY_get0_param(&oalg, NULL, NULL, NULL, xpub))
      {
        openssl_push_asn1object(L, oalg);
        lua_setfield(L, -2, "algorithm");
      }

      AUXILIAR_SETOBJECT(L, pubkey, "openssl.evp_pkey", -1, "pubkey");
      lua_setfield(L, -2, "pubkey");
    }

    lua_setfield(L, -2, "req_info");
  }

  return 1;
}

static LUA_FUNCTION(openssl_csr_free)
{
  X509_REQ *csr = CHECK_OBJECT(1, X509_REQ, "openssl.x509_req");
  X509_REQ_free(csr);
  return 0;
}

/***
get public key
@function public
@treturn evp_pkey public key
*/

/***
set public key
@function public
@tparam evp_pkey pubkey public key set to x509_req
@treturn boolean result
*/
static LUA_FUNCTION(openssl_csr_public)
{
  X509_REQ *csr = CHECK_OBJECT(1, X509_REQ, "openssl.x509_req");
  if (lua_isnone(L, 2))
  {
    EVP_PKEY *pkey = X509_REQ_get_pubkey(csr);
    PUSH_OBJECT(pkey, "openssl.evp_pkey");
    return 1;
  }
  else
  {
    EVP_PKEY *pkey = CHECK_OBJECT(2, EVP_PKEY, "openssl.evp_pkey");
    int ret = X509_REQ_set_pubkey(csr, pkey);
    return openssl_pushresult(L, ret);
  }
}

/***
get version key
@function version
@treturn integer
*/
/***
set version key
@function version
@tparam integer version
@treturn boolean result
*/
static LUA_FUNCTION(openssl_csr_version)
{
  X509_REQ *csr = CHECK_OBJECT(1, X509_REQ, "openssl.x509_req");
  if (lua_isnone(L, 2))
  {
    lua_pushinteger(L, X509_REQ_get_version(csr));
    return 1;
  }
  else
  {
    long version = luaL_checkint(L, 2);
    int ret = X509_REQ_set_version(csr, version);
    return openssl_pushresult(L, ret);
  }
}

/***
get subject x509_name object
@function subject
@treturn x509_name
*/
/***
set subject x509_name object
@function subject
@tparam x509_name subject
@treturn boolean result
*/
static LUA_FUNCTION(openssl_csr_subject)
{
  X509_REQ *csr = CHECK_OBJECT(1, X509_REQ, "openssl.x509_req");
  int ret = 0;

  if (lua_isnone(L, 2))
  {
    X509_NAME *xn = X509_REQ_get_subject_name(csr);
    if (xn)
    {
      openssl_push_xname_asobject(L, xn);
      ret = 1;
    }
  }
  else
  {
    X509_NAME* xn = CHECK_OBJECT(2, X509_NAME, "openssl.x509_name");
    ret = X509_REQ_set_subject_name(csr, xn);
    ret = openssl_pushresult(L, ret);
  }
  return ret;
}

/***
get extensions of x509_req object
@function extensions
@tparam[opt=false] boolean asobject, true for return as stack_of_x509_extension or as table
@treturn stack_of_x509_extension object when param set true
@treturn table contain all x509_extension when param set false or nothing
*/
/***
set extension of x509_req object
@function extensions
@tparam stack_of_x509_extension extensions
@treturn boolean result true for success
*/
static LUA_FUNCTION(openssl_csr_extensions)
{
  X509_REQ *csr = CHECK_OBJECT(1, X509_REQ, "openssl.x509_req");
  int ret = 0;

  if (lua_isnone(L, 2))
  {
    STACK_OF(X509_EXTENSION) *sk = X509_REQ_get_extensions(csr);
    if (sk)
    {
      openssl_sk_x509_extension_totable(L, sk);
      sk_X509_EXTENSION_pop_free(sk, X509_EXTENSION_free);
      ret = 1;
    }
  }
  else
  {
    STACK_OF(X509_EXTENSION) *sk = openssl_sk_x509_extension_fromtable(L, 2);
    ret = X509_REQ_add_extensions(csr, sk);
    sk_X509_EXTENSION_pop_free(sk, X509_EXTENSION_free);
    ret = openssl_pushresult(L, ret);
  }
  return ret;
}

/***
remove attribute object from location
@function attribute
@tparam integer location
@tparam nil nil, nil not none
@treturn x509_attribute attribute removed
*/
/***
get attribute object from location
@function attribute
@tparam integer location
@treturn x509_attribute attribute
*/
/***
add attribute to x509_req object
@function attribute
@tparam x509_attribute attribute attribute to add
@treturn boolean result
*/
static LUA_FUNCTION(openssl_csr_attribute)
{
  X509_REQ *csr = CHECK_OBJECT(1, X509_REQ, "openssl.x509_req");
  int ret = 0;

  if (auxiliar_getclassudata(L, "openssl.x509_attribute", 2))
  {
    X509_ATTRIBUTE *attr = CHECK_OBJECT(2, X509_ATTRIBUTE, "openssl.x509_attribute");
    ret = X509_REQ_add1_attr(csr, attr);
    ret = openssl_pushresult(L, ret);
  }
  else if (lua_isnumber(L, 2))
  {
    int loc = luaL_checkint(L, 2);
    X509_ATTRIBUTE *attr = NULL;
    if (lua_isnone(L, 3))
    {
      attr = X509_REQ_get_attr(csr, loc);
      attr = X509_ATTRIBUTE_dup(attr);
    }
    else if (lua_isnil(L, 3))
    {
      attr = X509_REQ_delete_attr(csr, loc);
    }
    if (attr)
    {
      PUSH_OBJECT(attr, "openssl.x509_attribute");
      ret = 1;
    }
  }
  else if (lua_istable(L, 2))
  {
    int i, n;

    for (i = 1, ret = 1, n = lua_rawlen(L, 2); ret == 1 && i <= n; i++)
    {
      X509_ATTRIBUTE *attr;
      lua_rawgeti(L, 2, i);
      attr = NULL;
      if (lua_istable(L, -1))
      {
        attr = openssl_new_xattribute(L, &attr, -1);
        ret = X509_REQ_add1_attr(csr, attr);
        X509_ATTRIBUTE_free(attr);
      }
      else
      {
        attr = CHECK_OBJECT(-1, X509_ATTRIBUTE, "openssl.x509_attribute");
        ret = X509_REQ_add1_attr(csr, attr);
      }
      lua_pop(L, 1);
    }
    ret = openssl_pushresult(L, ret);
  }

  return ret;
}

/***
get total attribute count in x509_req object
@function attr_count
@treturn integer
*/
static LUA_FUNCTION(openssl_csr_attr_count)
{
  X509_REQ *csr = CHECK_OBJECT(1, X509_REQ, "openssl.x509_req");
  lua_pushinteger(L, X509_REQ_get_attr_count(csr));
  return 1;
}

static luaL_Reg csr_cfuns[] =
{
  {"to_x509",           openssl_csr_to_x509},
  {"export",            openssl_csr_export},
  {"parse",             openssl_csr_parse},
  {"digest",            openssl_csr_digest},
  {"verify",            openssl_csr_verify},
  {"check",             openssl_csr_check},
  {"dup",               openssl_csr_dup},
  {"sign",              openssl_csr_sign},

  /* get or set */
  {"public",            openssl_csr_public},
  {"version",           openssl_csr_version},
  {"subject",           openssl_csr_subject},

  /* get or add */
  {"extensions",        openssl_csr_extensions},

  /* get,add or delete */
  {"attribute",         openssl_csr_attribute},
  {"attr_count",        openssl_csr_attr_count},

  {"__tostring",    auxiliar_tostring },
  {"__gc",          openssl_csr_free  },

  {NULL,        NULL  }
};

int luaopen_x509_req(lua_State *L)
{
  auxiliar_newclass(L, "openssl.x509_req", csr_cfuns);

  lua_newtable(L);
  luaL_setfuncs(L, R, 0);
  return 1;
}
