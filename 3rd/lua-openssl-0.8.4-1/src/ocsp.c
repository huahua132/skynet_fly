/*=========================================================================*\
* ocsp.c
* X509 certificate sign request routines for lua-openssl binding
*
* Author:  george zhao <zhaozg(at)gmail.com>
\*=========================================================================*/
/***
OCSP module for lua-openssl binding
Generate, sign, process OCSP request and response.

@module ocsp
@usage
  ocsp = require'openssl'.ocsp
*/

#include "openssl.h"
#include "private.h"
#include "openssl/ocsp.h"

static int openssl_ocsp_certid_new(lua_State *L)
{
  X509 *cert = GET_OBJECT(1, X509, "openssl.x509");
  BIGNUM *sn = cert==NULL ? (lua_isnil(L, 1) ? NULL : BN_get(L, 1)) : NULL;
  X509 *issuer = CHECK_OBJECT(2, X509, "openssl.x509");
  const EVP_MD *dgst = get_digest(L, 3, "sha256");

  int ret = 0;
  OCSP_CERTID *certid;

  luaL_argcheck(L, cert!=NULL || sn!=NULL, 1, "need openssl.x509 or openssl.bn object");

  if (sn)
  {
    X509_NAME *iname = X509_get_subject_name(issuer);
    ASN1_BIT_STRING *ikey = X509_get0_pubkey_bitstr(issuer);
    ASN1_INTEGER *ai = BN_to_ASN1_INTEGER(sn, NULL);

    certid = OCSP_cert_id_new(dgst, iname, ikey, ai);
    ASN1_INTEGER_free(ai);
    BN_free(sn);
  }
  else
  {
    certid = OCSP_cert_to_id(dgst, cert, issuer);
  }

  if (certid)
  {
    PUSH_OBJECT(certid, "openssl.ocsp_certid");
    ret = 1;
  }

  return ret;
}

static int openssl_ocsp_certid_free(lua_State *L)
{
  OCSP_CERTID* certid = CHECK_OBJECT(1, OCSP_CERTID, "openssl.ocsp_certid");
  OCSP_CERTID_free(certid);
  return 1;
}

static int openssl_ocsp_certid_info(lua_State *L)
{
  ASN1_OCTET_STRING *iNameHash = NULL, *ikeyHash = NULL;
  ASN1_OBJECT *md = NULL;
  ASN1_INTEGER *serial = NULL;

  OCSP_CERTID* certid = CHECK_OBJECT(1, OCSP_CERTID, "openssl.ocsp_certid");

  int ret = OCSP_id_get0_info(&iNameHash, &md, &ikeyHash, &serial, certid);
  if (ret==1)
  {
    lua_newtable(L);
    lua_pushliteral(L, "hashAlgorithm");
    openssl_push_asn1object(L, md);
    lua_rawset(L, -3);

    lua_pushliteral(L, "issuerNameHash");
    PUSH_ASN1_OCTET_STRING(L, iNameHash);
    lua_rawset(L, -3);

    lua_pushliteral(L, "issuerKeyHash");
    PUSH_ASN1_OCTET_STRING(L, ikeyHash);
    lua_rawset(L, -3);

    lua_pushliteral(L, "serialNumber");
    PUSH_ASN1_INTEGER(L, serial);
    lua_rawset(L, -3);
  }

  return ret==1 ? 1 : 0;
}


/***
create a new ocsp request object.
@function request_new
@tparam[opt] string nonce
@treturn ocsp_request
*/
static int openssl_ocsp_request_new(lua_State *L)
{
  int ret = 0;
  size_t sz = 0;
  const char* nonce = luaL_optlstring(L, 1, NULL, &sz);

  OCSP_REQUEST *req = OCSP_REQUEST_new();
  if (req)
  {
    OCSP_request_add1_nonce(req, (unsigned char*)nonce, sz ? sz : -1);
    PUSH_OBJECT(req, "openssl.ocsp_request");
    ret = 1;
  }
  return ret;
}

/***
add a OCSP_ONEREQ item with a x509 object
@function add
@tparam x509 certificate
@tparam x509 cacert
@param[opt='sha256'] digest
@treturn ocsp_request
*/

/***
add a OCSP_ONEREQ item with a x509 object
@function add
@param serialNumber
@tparam x509 cacert
@param[opt='sha256'] digest
@treturn ocsp_request
*/

static int openssl_ocsp_request_add(lua_State *L)
{
  OCSP_REQUEST *req = CHECK_OBJECT(1, OCSP_REQUEST, "openssl.ocsp_request");
  OCSP_CERTID *certid = CHECK_OBJECT(2, OCSP_CERTID, "openssl.ocsp_certid");

  int ret = 0;
  OCSP_ONEREQ *one = NULL;

  certid = OCSP_CERTID_dup(certid);
  one = OCSP_request_add0_id(req, certid);

  if (one)
  {
    PUSH_OBJECT(one, "openssl.ocsp_onereq");
    ret = 1;
  }
  else
    OCSP_CERTID_free(certid);

  return ret;
}

/***
add a x509_extension to ocsp_request object
@param serialNumber
@tparam x509_extension ext
@param[opt] loc
@treturn boolean
*/
static int openssl_ocsp_request_add_ext(lua_State *L)
{
  OCSP_REQUEST *req = CHECK_OBJECT(1, OCSP_REQUEST, "openssl.ocsp_request");
  X509_EXTENSION *x = CHECK_OBJECT(2, X509_EXTENSION, "openssl.x509_extension");
  int loc = luaL_optint(L, 3, OCSP_REQUEST_get_ext_count(req));
  int ret = OCSP_REQUEST_add_ext(req, x, loc);
  return openssl_pushresult(L, ret);
}

/***
read ocsp_request object from string or bio data
@function request_read
@tparam string|bio input
@treturn ocsp_request
*/
static int openssl_ocsp_request_read(lua_State *L)
{
  int ret = 0;
  BIO *bio = load_bio_object(L, 1);
  int pem = lua_gettop(L) > 1 ? auxiliar_checkboolean(L, 2) : 0;

  OCSP_REQUEST *req = pem ? PEM_read_bio_OCSP_REQUEST(bio, NULL, NULL)
                          : d2i_OCSP_REQUEST_bio(bio, NULL);
  BIO_free(bio);

  if (req)
  {
    PUSH_OBJECT(req, "openssl.ocsp_request");
    ret = 1;
  }

  return ret;
}

/***
export a ocsp_request object as PEM or DER encoded data
@function export
@tparam[opt=false] pem default export der
@treturn string
*/
static int openssl_ocsp_request_export(lua_State *L)
{
  OCSP_REQUEST *req = CHECK_OBJECT(1, OCSP_REQUEST, "openssl.ocsp_request");
  int pem = lua_gettop(L) > 1 ? auxiliar_checkboolean(L, 2) : 0;
  int ret = 0;
  BIO* bio;

  bio = BIO_new(BIO_s_mem());
  if (pem)
  {
    ret = PEM_write_bio_OCSP_REQUEST(bio, req);
  }
  else
  {
    ret = i2d_OCSP_REQUEST_bio(bio, req);
  }
  if (ret == 1)
  {
    BUF_MEM *buf;
    BIO_get_mem_ptr(bio, &buf);
    lua_pushlstring(L, buf->data, buf->length);
  }
  BIO_free(bio);
  return ret == 1 ? ret : openssl_pushresult(L, ret);
}

static int openssl_ocsp_request_free(lua_State *L)
{
  OCSP_REQUEST *req = CHECK_OBJECT(1, OCSP_REQUEST, "openssl.ocsp_request");
  OCSP_REQUEST_free(req);
  return 0;
}

/***
ocsp_request is_signed or not
@function is_signed
@treturn boolean
*/
static int openssl_ocsp_request_is_signed(lua_State *L)
{
  OCSP_REQUEST *req = CHECK_OBJECT(1, OCSP_REQUEST, "openssl.ocsp_request");
  int is_signed = OCSP_request_is_signed(req);
  lua_pushboolean(L, is_signed);
  return 1;
}

/***
sign ocsp_request object
@function sign
@tparam x509 signer
@tparam evp_pkey pkey
@param[opt] others certificates in ocsp_request
@tparam[opt=0] number flags
@param[opt='sha256'] digest
@treturn boolean
*/
static int openssl_ocsp_request_sign(lua_State *L)
{
  OCSP_REQUEST *req = CHECK_OBJECT(1, OCSP_REQUEST, "openssl.ocsp_request");
  X509 *signer = CHECK_OBJECT(2, X509, "openssl.x509");
  EVP_PKEY *pkey = CHECK_OBJECT(3, EVP_PKEY, "openssl.evp_pkey");
  STACK_OF(X509) *others = NULL;
  const EVP_MD *md = NULL;
  int ret;
  int sflags = 0;

  if (lua_isnoneornil(L, 4))
  {
    sflags = OCSP_NOCERTS;
  }
  else
  {
    others = openssl_sk_x509_fromtable(L, 4);
  }
  sflags = luaL_optint(L, 5, sflags);
  md = lua_isnoneornil(L, 6) ? NULL : get_digest(L, 6, "sha256");

  ret = OCSP_request_sign(req, signer, pkey, md, others, sflags);
  lua_pushboolean(L, ret);
  if (others!=NULL)
    sk_X509_pop_free(others, X509_free);
  return 1;
}

static int openssl_ocsp_request_parse(lua_State *L)
{
  OCSP_REQUEST *req = CHECK_OBJECT(1, OCSP_REQUEST, "openssl.ocsp_request");
#if OPENSSL_VERSION_NUMBER < 0x10100000L
  OCSP_REQINFO *inf = req->tbsRequest;
  OCSP_SIGNATURE *sig = req->optionalSignature;
#endif
  int i, num;
  lua_newtable(L);

#if OPENSSL_VERSION_NUMBER < 0x10100000L
  AUXILIAR_SET(L, -1, "version", ASN1_INTEGER_get(inf->version), integer);
  if (inf->requestorName)
  {
    openssl_push_general_name(L, inf->requestorName);
    lua_setfield(L, -2, "requestorName");
  }
#endif

  num = OCSP_request_onereq_count(req);
  lua_newtable(L);
  for (i = 0; i < num; i++)
  {
    OCSP_ONEREQ *one = OCSP_request_onereq_get0(req, i);
    OCSP_CERTID *cid = OCSP_onereq_get0_id(one);
    cid = OCSP_CERTID_dup(cid);
    PUSH_OBJECT(cid, "openssl.ocsp_certid");
    lua_rawseti(L, -2, i + 1);
  }
  lua_setfield(L, -2, "requestList");

  num = OCSP_REQUEST_get_ext_count(req);
  lua_newtable(L);
  for (i = 0; i < num; i++)
  {
    X509_EXTENSION* e = OCSP_REQUEST_get_ext(req, i);
    e = X509_EXTENSION_dup(e);
    PUSH_OBJECT(e, "openssl.x509_extension");
    lua_rawseti(L, -2, i + 1);
  }
  lua_setfield(L, -2, "extensions");

#if OPENSSL_VERSION_NUMBER < 0x10100000L
  if (sig)
  {
    BIO* bio = BIO_new(BIO_s_mem());
    (void)BIO_reset(bio);
    X509_signature_print(bio, sig->signatureAlgorithm, sig->signature);
    for (i = 0; i < sk_X509_num(sig->certs); i++)
    {
      X509_print(bio, sk_X509_value(sig->certs, i));
      PEM_write_bio_X509(bio, sk_X509_value(sig->certs, i));
    }
    BIO_free(bio);
  }
#endif

  return 1;
}

static int openssl_ocsp_response_read(lua_State *L)
{
  BIO *bio = load_bio_object(L, 1);
  int pem = lua_gettop(L) > 1 ? auxiliar_checkboolean(L, 2) : 0;
  int ret = 0;

  OCSP_RESPONSE *res = pem ? PEM_read_bio_OCSP_RESPONSE(bio, NULL, NULL)
                           : d2i_OCSP_RESPONSE_bio(bio, NULL);
  if (res)
  {
    PUSH_OBJECT(res, "openssl.ocsp_response");
    ret = 1;
  }
  BIO_free(bio);

  return ret;
}

static int openssl_ocsp_singleresp_add_ext(lua_State *L)
{
  OCSP_SINGLERESP *sr = CHECK_OBJECT(1, OCSP_SINGLERESP, "openssl.ocsp_singleresp");
  X509_EXTENSION *ext = CHECK_OBJECT(2, X509_EXTENSION, "openssl.x509_extension");
  int loc = luaL_optint(L, 3, OCSP_SINGLERESP_get_ext_count(sr));

  int ret = OCSP_SINGLERESP_add_ext(sr, ext, loc);
  return openssl_pushresult(L, ret);
}

static int openssl_ocsp_singleresp_info(lua_State *L)
{
  OCSP_SINGLERESP *single = CHECK_OBJECT(1, OCSP_SINGLERESP, "openssl.ocsp_singleresp");

  int i, n, status = V_OCSP_CERTSTATUS_UNKNOWN, reason = OCSP_REVOKED_STATUS_NOSTATUS;

  const OCSP_CERTID *id;
  ASN1_GENERALIZEDTIME *revtime = NULL, *thisupd = NULL;

  lua_newtable(L);

  id = OCSP_SINGLERESP_get0_id(single);
  lua_pushliteral(L, "id");
  id = OCSP_CERTID_dup((OCSP_CERTID *)id);
  PUSH_OBJECT(id, "openssl.ocsp_certid");
  lua_rawset(L, -3);

  status = OCSP_single_get0_status((OCSP_SINGLERESP*)single, &reason, &revtime, &thisupd, NULL);

  AUXILIAR_SET(L, -1, "status", status, integer);
  AUXILIAR_SET(L, -1, "status_str", OCSP_response_status_str(status), string);

  AUXILIAR_SET(L, -1, "reason", reason, integer);
  AUXILIAR_SET(L, -1, "reason_str", OCSP_crl_reason_str(reason), string);

  if (revtime)
  {
    lua_pushliteral(L, "revokeTime");
    PUSH_ASN1_TIME(L, revtime);
    lua_rawset(L, -3);
  }

  if (thisupd)
  {
    lua_pushliteral(L, "thisUpdate");
    PUSH_ASN1_TIME(L, thisupd);
    lua_rawset(L, -3);
  }

  n = OCSP_SINGLERESP_get_ext_count((OCSP_SINGLERESP*)single);
  if (n > 0)
  {
    lua_pushstring(L, "extensions");
    lua_newtable(L);

    for (i=0; i<n; i++)
    {
      X509_EXTENSION *ext = OCSP_SINGLERESP_get_ext((OCSP_SINGLERESP*)single, i);

      ext = X509_EXTENSION_dup(ext);
      PUSH_OBJECT(ext, "openssl.x509_extension");
      lua_rawseti(L, -2, i+1);
    }

    lua_rawset(L, -3);
  }

  return 1;
}

static int openssl_ocsp_singleresp_free(lua_State *L)
{
  OCSP_SINGLERESP *single = CHECK_OBJECT(1, OCSP_SINGLERESP, "openssl.ocsp_singleresp");
  lua_pushnil(L);
  lua_rawsetp(L, LUA_REGISTRYINDEX, single);
  return 0;
}

static int openssl_ocsp_basic_new(lua_State *L)
{
  int ret = 0;
  OCSP_BASICRESP *bs = OCSP_BASICRESP_new();

  if (bs)
  {
    PUSH_OBJECT(bs, "openssl.ocsp_basicresp");
    ret = 1;
  }
  return ret;
}

static int openssl_ocsp_basic_add(lua_State *L)
{
  int ret = 0;
  OCSP_BASICRESP *bs = CHECK_OBJECT(1, OCSP_BASICRESP, "openssl.ocsp_basicresp");
  OCSP_CERTID* cid = CHECK_OBJECT(2, OCSP_CERTID, "openssl.ocsp_certid");

  int status = luaL_checkint(L, 3);
  int reason = luaL_checkint(L, 4);
  time_t iThisupd = time(NULL);
  time_t iNextupd;

  ASN1_TIME *revtime = NULL, *thisupdate = NULL, *nextupdate = NULL;
  OCSP_SINGLERESP *single = NULL;

  if (!lua_isnil(L, 5))
  {
    revtime = ASN1_TIME_new();
    ASN1_TIME_set(revtime, luaL_checkint(L, 5));
  }

  iThisupd = luaL_optint(L, 6, iThisupd);
  thisupdate = ASN1_TIME_new();
  ASN1_TIME_set(thisupdate, iThisupd);

  iNextupd = luaL_optint(L, 7, iThisupd + 24*3600);
  nextupdate = ASN1_TIME_new();
  ASN1_TIME_set(nextupdate, iNextupd);

  single = OCSP_basic_add1_status(bs, cid, status, reason, revtime, thisupdate, nextupdate);
  if (single)
  {
    PUSH_OBJECT(single, "openssl.ocsp_singleresp");
    ret = 1;

    lua_pushvalue(L, 1);
    lua_rawsetp(L, LUA_REGISTRYINDEX, single);
  }
  ASN1_TIME_free(revtime);
  ASN1_TIME_free(thisupdate);
  ASN1_TIME_free(nextupdate);

  return ret;
}

static int openssl_ocsp_basic_add_ext(lua_State *L)
{
  OCSP_BASICRESP *bs = CHECK_OBJECT(1, OCSP_BASICRESP, "openssl.ocsp_basicresp");
  X509_EXTENSION *ext = CHECK_OBJECT(2, X509_EXTENSION, "openssl.x509_extension");
  int loc = luaL_optint(L, 3, OCSP_BASICRESP_get_ext_count(bs));

  int ret = OCSP_BASICRESP_add_ext(bs, ext, loc);
  return openssl_pushresult(L, ret);
}

static int openssl_ocsp_basic_sign(lua_State *L)
{
  OCSP_BASICRESP *bs = CHECK_OBJECT(1, OCSP_BASICRESP, "openssl.ocsp_basicresp");
  X509* ocert = CHECK_OBJECT(2, X509, "openssl.x509");
  EVP_PKEY *okey = CHECK_OBJECT(3, EVP_PKEY, "openssl.evp_pkey");
  const EVP_MD* dgst = get_digest(L, 4, "sha256");
  STACK_OF(X509) *others = lua_isnoneornil(L, 5) ? NULL : openssl_sk_x509_fromtable(L, 5);
  unsigned long flag = luaL_optint(L, 6, 0);

  int ret = OCSP_basic_sign(bs, ocert, okey, dgst, others, flag);
  return openssl_pushresult(L, ret);
}

static int openssl_ocsp_basic_info(lua_State *L)
{
  OCSP_BASICRESP *br = CHECK_OBJECT(1, OCSP_BASICRESP, "openssl.ocsp_basicresp");

  int i, n;

  const ASN1_OCTET_STRING *id = NULL;
  const X509_NAME *name = NULL;
  const ASN1_GENERALIZEDTIME *producedAt;
  const STACK_OF(X509) *certs;

  lua_newtable(L);

  producedAt = OCSP_resp_get0_produced_at(br);
  if (producedAt)
  {
    lua_pushliteral(L, "producedAt");
    PUSH_ASN1_TIME(L, producedAt);
    lua_rawset(L, -3);
  }

  certs = OCSP_resp_get0_certs(br);
  if (certs)
  {
    if ((n = sk_X509_num(certs)) > 0)
    {
      lua_pushliteral(L, "certs");
      lua_newtable(L);

      for (i = 0; i < n; i++) {
        X509 *x = sk_X509_value(certs, i);
        X509_up_ref(x);
        PUSH_OBJECT(x, "openssl.x509");
        lua_rawseti(L, -2, i+1);
      }

      lua_rawset(L, -3);
    }
  }

  if (OCSP_resp_get0_id(br, &id, &name)==1)
  {
    if (id)
    {
      lua_pushliteral(L, "id");
      PUSH_ASN1_OCTET_STRING(L, id);
      lua_rawset(L, -3);
    }

    if (name)
    {
      lua_pushliteral(L, "name");
      openssl_push_xname_asobject(L, (X509_NAME*)name);
      lua_rawset(L, -3);
    }
  }

  n = OCSP_BASICRESP_get_ext_count(br);
  if (n>0)
  {
    lua_pushliteral(L, "extensions");
    lua_newtable(L);
    for (i=0; i<n; i++)
    {
      X509_EXTENSION *ext = OCSP_BASICRESP_get_ext(br, i);
      ext = X509_EXTENSION_dup(ext);
      PUSH_OBJECT(ext, "openssl.x509_extension");
      lua_rawseti(L, -2, i+1);
    }
    lua_rawset(L, -3);
  }

#if OPENSSL_VERSION_NUMBER >= 0x1010100FL && !defined(LIBRESSL_VERSION_NUMBER)
  {
    X509 *signer = NULL;

    if (OCSP_resp_get0_signer(br, &signer, NULL) == 1)
    {
      X509_up_ref(signer);

      lua_pushliteral(L, "signer");
      PUSH_OBJECT(signer, "openssl.x509");
      lua_rawset(L, -3);
    }
  }
#endif

  n = OCSP_resp_count(br);
  for (i=0; i<n; i++)
  {
    const OCSP_SINGLERESP *single = OCSP_resp_get0(br, i);
    PUSH_OBJECT(single, "openssl.ocsp_singleresp");
    lua_rawseti(L, -2, i+1);

    lua_pushvalue(L, 1);
    lua_rawsetp(L, LUA_REGISTRYINDEX, single);
  }

  openssl_push_x509_signature(L, OCSP_resp_get0_tbs_sigalg(br), OCSP_resp_get0_signature(br), -1);

  return 1;
}

static int openssl_ocsp_basic_copy_nonce(lua_State *L)
{
  OCSP_BASICRESP *bs = CHECK_OBJECT(1, OCSP_BASICRESP, "openssl.ocsp_basicresp");
  OCSP_REQUEST *req = CHECK_OBJECT(2, OCSP_REQUEST, "openssl.ocsp_request");

  int ret = OCSP_copy_nonce(bs, req);
  return openssl_pushresult(L, ret);
}

static int openssl_ocsp_basic_resposne(lua_State *L)
{
  OCSP_BASICRESP *bs = CHECK_OBJECT(1, OCSP_BASICRESP, "openssl.ocsp_basicresp");
  int status = luaL_optint(L, 2, OCSP_RESPONSE_STATUS_SUCCESSFUL);
  int ret = 0;

  OCSP_RESPONSE *res = OCSP_response_create(status, bs);
  if (res)
  {
    PUSH_OBJECT(res, "openssl.ocsp_response");
    ret = 1;
  }
  return ret;
}

static int openssl_ocsp_basic_free(lua_State *L)
{
  OCSP_BASICRESP *bs = CHECK_OBJECT(1, OCSP_BASICRESP, "openssl.ocsp_basicresp");
  OCSP_BASICRESP_free(bs);
  return 0;
}

static int openssl_ocsp_response_export(lua_State *L)
{
  OCSP_RESPONSE *res = CHECK_OBJECT(1, OCSP_RESPONSE, "openssl.ocsp_response");
  int pem = lua_gettop(L) > 1 ? auxiliar_checkboolean(L, 2) : 0;
  int ret = 0;
  BIO* bio = BIO_new(BIO_s_mem());
  if (pem)
  {
    ret = PEM_write_bio_OCSP_RESPONSE(bio, res);
  }
  else
  {
    ret = i2d_OCSP_RESPONSE_bio(bio, res);
  }
  if (ret>0)
  {
    BUF_MEM *buf;
    BIO_get_mem_ptr(bio, &buf);
    lua_pushlstring(L, buf->data, buf->length);
  }
  BIO_free(bio);
  return ret;
}

static int openssl_ocsp_response_parse(lua_State *L)
{
  int status;

  OCSP_RESPONSE *resp = CHECK_OBJECT(1, OCSP_RESPONSE, "openssl.ocsp_response");
  OCSP_BASICRESP *br = OCSP_response_get1_basic(resp);

  lua_newtable(L);

  status =  OCSP_response_status(resp);
  AUXILIAR_SET(L, -1, "status", status, integer);
  AUXILIAR_SET(L, -1, "status_str", OCSP_response_status_str(status), string);

  if (br)
  {
    lua_pushliteral(L, "basic");
    PUSH_OBJECT(br, "openssl.ocsp_basicresp");
    lua_rawset(L, -3);
  }

  return 1;
}

static int openssl_ocsp_response_free(lua_State *L)
{
  OCSP_RESPONSE *res = CHECK_OBJECT(1, OCSP_RESPONSE, "openssl.ocsp_response");
  OCSP_RESPONSE_free(res);
  return 0;
}

static luaL_Reg ocsp_certid_cfuns[] =
{
  {"info",        openssl_ocsp_certid_info},

  {"__tostring",  auxiliar_tostring},
  {"__gc",        openssl_ocsp_certid_free},

  {NULL,          NULL}
};

static luaL_Reg ocsp_req_cfuns[] =
{
  {"export",      openssl_ocsp_request_export},
  {"parse",       openssl_ocsp_request_parse},
  {"sign",        openssl_ocsp_request_sign},
  {"add_ext",     openssl_ocsp_request_add_ext},
  {"is_signed",   openssl_ocsp_request_is_signed},

  {"add",         openssl_ocsp_request_add},

  {"__tostring",  auxiliar_tostring},
  {"__gc",        openssl_ocsp_request_free},

  {NULL,          NULL}
};

static luaL_Reg ocsp_onereq_cfuns[] =
{
  {"__tostring",  auxiliar_tostring},

  {NULL,          NULL}
};

static luaL_Reg ocsp_singleresp_cfuns[] =
{
  {"info",        openssl_ocsp_singleresp_info},
  {"add_ext",     openssl_ocsp_singleresp_add_ext},

  {"__tostring",  auxiliar_tostring},
  {"__gc",        openssl_ocsp_singleresp_free},

  {NULL,          NULL}
};

static luaL_Reg ocsp_basicresp_cfuns[] =
{
  {"info",        openssl_ocsp_basic_info},
  {"add",         openssl_ocsp_basic_add},
  {"add_ext",     openssl_ocsp_basic_add_ext},

  {"sign",        openssl_ocsp_basic_sign},
  {"response",    openssl_ocsp_basic_resposne},
  {"copy_nonce",  openssl_ocsp_basic_copy_nonce},

  {"__tostring",  auxiliar_tostring},
  {"__gc",        openssl_ocsp_basic_free},

  {NULL,          NULL}
};

static luaL_Reg ocsp_res_cfuns[] =
{
  {"export",      openssl_ocsp_response_export},
  {"parse",       openssl_ocsp_response_parse},

  {"__tostring",  auxiliar_tostring},
  {"__gc",        openssl_ocsp_response_free},

  {NULL,          NULL}
};

static luaL_Reg R[] =
{
  {"certid_new",    openssl_ocsp_certid_new},
  {"request_read",  openssl_ocsp_request_read},
  {"request_new",   openssl_ocsp_request_new},
  {"response_read", openssl_ocsp_response_read},

  {"basic_new",     openssl_ocsp_basic_new},

  {NULL,            NULL}
};

static LuaL_Enumeration ocsp_reasons[] =
{
#define DEFINE_ENUM(x)  {#x,  OCSP_REVOKED_STATUS_##x}
  DEFINE_ENUM(NOSTATUS),
  DEFINE_ENUM(UNSPECIFIED),
  DEFINE_ENUM(KEYCOMPROMISE),
  DEFINE_ENUM(CACOMPROMISE),
  DEFINE_ENUM(AFFILIATIONCHANGED),
  DEFINE_ENUM(SUPERSEDED),
  DEFINE_ENUM(CESSATIONOFOPERATION),
  DEFINE_ENUM(CERTIFICATEHOLD),
  DEFINE_ENUM(REMOVEFROMCRL),
#undef DEFINE_ENUM

#define DEFINE_ENUM(x)  {#x,  V_OCSP_CERTSTATUS_##x}
  DEFINE_ENUM(GOOD),
  DEFINE_ENUM(REVOKED),
  DEFINE_ENUM(UNKNOWN),
#undef DEFINE_ENUM

#define DEFINE_ENUM(x)  {#x,  OCSP_##x}
  DEFINE_ENUM(RESPONSE_STATUS_SUCCESSFUL),
  DEFINE_ENUM(RESPONSE_STATUS_MALFORMEDREQUEST),
  DEFINE_ENUM(RESPONSE_STATUS_INTERNALERROR),
  DEFINE_ENUM(RESPONSE_STATUS_TRYLATER),
  DEFINE_ENUM(RESPONSE_STATUS_SIGREQUIRED),
  DEFINE_ENUM(RESPONSE_STATUS_UNAUTHORIZED),
#undef DEFINE_ENUM

  {"invalidity_date",        NID_invalidity_date},
  {"hold_instruction_code",  NID_hold_instruction_code},

  {NULL,                     -1}
};

int luaopen_ocsp(lua_State *L)
{
  auxiliar_newclass(L, "openssl.ocsp_certid",     ocsp_certid_cfuns);
  auxiliar_newclass(L, "openssl.ocsp_request",    ocsp_req_cfuns);
  auxiliar_newclass(L, "openssl.ocsp_response",   ocsp_res_cfuns);
  auxiliar_newclass(L, "openssl.ocsp_onereq",     ocsp_onereq_cfuns);
  auxiliar_newclass(L, "openssl.ocsp_singleresp", ocsp_singleresp_cfuns);
  auxiliar_newclass(L, "openssl.ocsp_basicresp",  ocsp_basicresp_cfuns);

  lua_newtable(L);
  luaL_setfuncs(L, R, 0);
  auxiliar_enumerate(L, -1, ocsp_reasons);

  return 1;
}
