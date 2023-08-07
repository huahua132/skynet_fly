/***
timestamp module provide basic Time Stamping Authority (TSA) client and server operations as specified in RFC 3161 (Time-Stamp Protocol, TSP).
A TSA can be part of a PKI deployment and its role is to provide long term proof of the existence of a certain datum before a particular time.

@module ts
@usage
  ts = require'openssl'.ts
*/
#include "openssl.h"
#include "private.h"
#include <stdint.h>
#if OPENSSL_VERSION_NUMBER >= 0x10000000L
#include <openssl/ts.h>
#include <openssl/asn1.h>


/***
create a new ts_msg_imprint object.
@function ts_msg_imprint_new
@tparam string data
@tparam string|integer|asn1_object alg name, nid or object identity
@treturn ts_msg_imprint
*/
static int openssl_ts_msg_imprint_new(lua_State *L)
{
  size_t sz = 0;
  const char* data = luaL_checklstring(L, 1, &sz);
  const EVP_MD *md = get_digest(L, 2, NULL);

  TS_MSG_IMPRINT *msg = TS_MSG_IMPRINT_new();

  int ret = TS_MSG_IMPRINT_set_msg(msg, (unsigned char*)data, sz);
  if (sz!=EVP_MD_size(md))
    luaL_error(L, "data size not match with digest size");

  if (ret == 1)
  {
    X509_ALGOR* alg = X509_ALGOR_new();
    X509_ALGOR_set_md(alg, md);
    if (ret == 1)
      ret = TS_MSG_IMPRINT_set_algo(msg, alg);

    X509_ALGOR_free(alg);
    PUSH_OBJECT(msg, "openssl.ts_msg_imprint");
  }
  else
    ret = openssl_pushresult(L, ret);
  return ret;
}

static int openssl_ts_msg_imprint_read(lua_State *L)
{
  size_t sz = 0;
  const unsigned char* data = (const unsigned char*)luaL_checklstring(L, 1, &sz);
  TS_MSG_IMPRINT *msg = d2i_TS_MSG_IMPRINT(NULL, &data, sz);
  if (msg)
    PUSH_OBJECT(msg, "openssl.ts_msg_imprint");
  else
    lua_pushnil(L);
  return 1;
}

/***
export a ts_msg_imprint object as DER encoded data
@function export
@treturn string
*/
static int openssl_ts_msg_imprint_export(lua_State *L)
{
  TS_MSG_IMPRINT * msg = CHECK_OBJECT(1, TS_MSG_IMPRINT, "openssl.ts_msg_imprint");
  unsigned char* buf = NULL;
  int len = i2d_TS_MSG_IMPRINT(msg, &buf);
  if (len>=0)
  {
    lua_pushlstring(L, (const char*)buf, len);
    OPENSSL_free(buf);
    len = 1;
  }
  else
    len = openssl_pushresult(L, len);
  return len;
}

/***
get a ts_msg_imprint msg
@function msg
@treturn asn1_string
*/
static int openssl_ts_msg_imprint_msg(lua_State *L)
{
  TS_MSG_IMPRINT* msg = CHECK_OBJECT(1, TS_MSG_IMPRINT, "openssl.ts_msg_imprint");
  ASN1_OCTET_STRING *s = TS_MSG_IMPRINT_get_msg(msg);

  PUSH_ASN1_OCTET_STRING(L, s);
  return 1;
}

/***
get a ts_msg_imprint algo
@function algo
@treturn openssl.x509_algor
*/
static int openssl_ts_msg_imprint_algo(lua_State *L)
{
  TS_MSG_IMPRINT* msg = CHECK_OBJECT(1, TS_MSG_IMPRINT, "openssl.ts_msg_imprint");
  X509_ALGOR *a = TS_MSG_IMPRINT_get_algo(msg);

  a = X509_ALGOR_dup(a);
  PUSH_OBJECT(a, "openssl.x509_algor");
  return 1;
}

/***
get a ts_msg_imprint table contains msg and algo fields
@function totable
@treturn table
*/
static int openssl_ts_msg_imprint_totable(lua_State *L)
{
  TS_MSG_IMPRINT* msg = CHECK_OBJECT(1, TS_MSG_IMPRINT, "openssl.ts_msg_imprint");

  ASN1_OCTET_STRING *s = TS_MSG_IMPRINT_get_msg(msg);
  X509_ALGOR *a = TS_MSG_IMPRINT_get_algo(msg);

  lua_newtable(L);
  PUSH_ASN1_OCTET_STRING(L, s);
  lua_setfield(L, -2, "msg");

  a = X509_ALGOR_dup(a);
  PUSH_OBJECT(a, "openssl.x509_algor");
  lua_setfield(L, -2, "algo");

  return 1;
}

/***
duplicate ts_msg_imprint object
@function dup
@treturn ts_msg_imprint
*/
static int openssl_ts_msg_imprint_dup(lua_State *L)
{
  TS_MSG_IMPRINT* msg = CHECK_OBJECT(1, TS_MSG_IMPRINT, "openssl.ts_msg_imprint");
  msg = TS_MSG_IMPRINT_dup(msg);
  PUSH_OBJECT(msg, "openssl.ts_msg_imprint");
  return 1;
}

static int openssl_ts_msg_imprint_gc(lua_State *L)
{
  TS_MSG_IMPRINT* msg = CHECK_OBJECT(1, TS_MSG_IMPRINT, "openssl.ts_msg_imprint");
  TS_MSG_IMPRINT_free(msg);
  return 0;
}

static luaL_Reg ts_msg_imprint_funcs[] =
{
  {"dup",           openssl_ts_msg_imprint_dup},
  {"msg",           openssl_ts_msg_imprint_msg},
  {"algo",          openssl_ts_msg_imprint_algo},
  {"export",        openssl_ts_msg_imprint_export},
  {"totable",       openssl_ts_msg_imprint_totable},

  {"__gc",          openssl_ts_msg_imprint_gc},
  {"__tostring",    auxiliar_tostring},

  {NULL,    NULL}
};

static int openssl_ts_accuracy_new(lua_State *L)
{
  int ret;
  time_t seconds = 0;
  int millis = 0, micros = 0;

  TS_ACCURACY *accuracy = NULL;
  ASN1_INTEGER *sec= NULL;
  ASN1_INTEGER *mil= NULL;
  ASN1_INTEGER *mic= NULL;

  seconds = luaL_checkinteger(L, 1);
  millis = luaL_optinteger(L, 2, millis);
  micros = luaL_optinteger(L, 3, micros);

  accuracy = TS_ACCURACY_new();
  sec = ASN1_INTEGER_new();
  mil = ASN1_INTEGER_new();
  mic = ASN1_INTEGER_new();

  ret = ASN1_INTEGER_set(sec, (long)seconds);
  if (ret==1)
    ret = TS_ACCURACY_set_seconds(accuracy, sec);

  if (ret==1)
  {
    ret = ASN1_INTEGER_set(mil, millis);
    if (ret==1)
      ret = TS_ACCURACY_set_millis(accuracy, mil);
  }

  if (ret==1)
  {
    ret = ASN1_INTEGER_set(mic, micros);
    if (ret==1)
      ret = TS_ACCURACY_set_micros(accuracy, mic);
  }

  if (ret==1)
  {
    PUSH_OBJECT(accuracy, "openssl.ts_accuracy");
  }else
  {
    TS_ACCURACY_free(accuracy);
    ret = 0;
  }

  ASN1_INTEGER_free(sec);
  ASN1_INTEGER_free(mil);
  ASN1_INTEGER_free(mic);
  return ret;
}

static int openssl_ts_accuracy_seconds(lua_State *L)
{
  int ret = 0;
  TS_ACCURACY *accuracy = CHECK_OBJECT(1, TS_ACCURACY, "openssl.ts_accuracy");
  if (lua_isnone(L, 2))
  {
    const ASN1_INTEGER *ai = TS_ACCURACY_get_seconds(accuracy);
    lua_pushinteger(L, ASN1_INTEGER_get(ai));
    ret = 1;
  }
  else
  {
    time_t seconds = luaL_checkinteger(L, 2);
    ASN1_INTEGER *ai = ASN1_INTEGER_new();
    ret = ASN1_INTEGER_set(ai, (long)seconds);
    if (ret==1)
      ret = TS_ACCURACY_set_seconds(accuracy, ai);
    ret = openssl_pushresult(L, ret);
    ASN1_INTEGER_free(ai);
  }
  return ret;
}

static int openssl_ts_accuracy_millis(lua_State *L)
{
  int ret = 0;
  TS_ACCURACY *accuracy = CHECK_OBJECT(1, TS_ACCURACY, "openssl.ts_accuracy");
  if (lua_isnone(L, 2))
  {
    const ASN1_INTEGER *ai = TS_ACCURACY_get_millis(accuracy);
    lua_pushinteger(L, ASN1_INTEGER_get(ai));
    ret = 1;
  }
  else
  {
    int millies = luaL_checkinteger(L, 2);
    ASN1_INTEGER *ai = ASN1_INTEGER_new();
    ret = ASN1_INTEGER_set(ai, (long)millies);
    if (ret==1)
      ret = TS_ACCURACY_set_millis(accuracy, ai);
    ret = openssl_pushresult(L, ret);
    ASN1_INTEGER_free(ai);
  }
  return ret;
}

static int openssl_ts_accuracy_micros(lua_State *L)
{
  int ret = 0;
  TS_ACCURACY *accuracy = CHECK_OBJECT(1, TS_ACCURACY, "openssl.ts_accuracy");
  if (lua_isnone(L, 2))
  {
    const ASN1_INTEGER *ai = TS_ACCURACY_get_micros(accuracy);
    lua_pushinteger(L, ASN1_INTEGER_get(ai));
    ret = 1;
  }
  else
  {
    int micros= luaL_checkinteger(L, 2);
    ASN1_INTEGER *ai = ASN1_INTEGER_new();
    ret = ASN1_INTEGER_set(ai, (long)micros);
    if (ret==1)
      ret = TS_ACCURACY_set_micros(accuracy, ai);
    ret = openssl_pushresult(L, ret);
    ASN1_INTEGER_free(ai);
  }
  return ret;
}

static int openssl_ts_accuracy_dup(lua_State *L)
{
  TS_ACCURACY *accuracy = CHECK_OBJECT(1, TS_ACCURACY, "openssl.ts_accuracy");
  accuracy = TS_ACCURACY_dup(accuracy);
  PUSH_OBJECT(accuracy, "openssl.ts_accuracy");
  return 1;
}

static int openssl_ts_accuracy_gc(lua_State *L)
{
  TS_ACCURACY *accuracy = CHECK_OBJECT(1, TS_ACCURACY, "openssl.ts_accuracy");
  TS_ACCURACY_free(accuracy);
  return 0;
}

static int openssl_ts_accuracy_export(lua_State *L)
{
  TS_ACCURACY *accuracy = CHECK_OBJECT(1, TS_ACCURACY, "openssl.ts_accuracy");
  unsigned char* buf = NULL;
  int len = i2d_TS_ACCURACY(accuracy, &buf);
  if (len>=0)
  {
    lua_pushlstring(L, (const char*)buf, len);
    OPENSSL_free(buf);
    len = 1;
  }
  else
    len = openssl_pushresult(L, len);
  return len;
}

static int openssl_ts_accuracy_read(lua_State *L)
{
  size_t sz = 0;
  const unsigned char* data = (const unsigned char*)luaL_checklstring(L, 1, &sz);
  TS_ACCURACY *accuracy = d2i_TS_ACCURACY(NULL, &data, sz);
  if (accuracy)
    PUSH_OBJECT(accuracy, "openssl.ts_accuracy");
  else
    lua_pushnil(L);
  return 1;
}

static int openssl_ts_accuracy_totable(lua_State*L)
{
  TS_ACCURACY *accuracy = CHECK_OBJECT(1, TS_ACCURACY, "openssl.ts_accuracy");
  lua_newtable(L);

  lua_pushinteger(L, ASN1_INTEGER_get(TS_ACCURACY_get_micros(accuracy)));
  lua_setfield(L, -2, "micros");

  lua_pushinteger(L, ASN1_INTEGER_get(TS_ACCURACY_get_millis(accuracy)));
  lua_setfield(L, -2, "millis");

  lua_pushinteger(L, ASN1_INTEGER_get(TS_ACCURACY_get_seconds(accuracy)));
  lua_setfield(L, -2, "seconds");

  return 1;
}

static luaL_Reg ts_accuracy_funcs[] =
{
  {"dup",           openssl_ts_accuracy_dup},
  {"micros",        openssl_ts_accuracy_micros},
  {"millis",        openssl_ts_accuracy_millis},
  {"seconds",       openssl_ts_accuracy_seconds},
  {"export",        openssl_ts_accuracy_export},
  {"totable",       openssl_ts_accuracy_totable},

  {"__gc",          openssl_ts_accuracy_gc},
  {"__tostring",    auxiliar_tostring},

  {NULL,    NULL}
};

/***
get version of ts_tst_info object object
@function version
@treturn integer
*/
static int openssl_ts_info_version(lua_State *L)
{
  TS_TST_INFO *info = CHECK_OBJECT(1, TS_TST_INFO, "openssl.ts_tst_info");
  lua_pushinteger(L, TS_TST_INFO_get_version(info));
  return 1;
}

/***
get policy_id of ts_tst_info object object
@function policy_id
@treturn asn1_object
*/
static int openssl_ts_info_policy_id(lua_State *L)
{
  TS_TST_INFO *info = CHECK_OBJECT(1, TS_TST_INFO, "openssl.ts_tst_info");
  openssl_push_asn1object(L, TS_TST_INFO_get_policy_id(info));
  return 1;
}

/***
get msg_imprint of ts_tst_info object object
@function msg_imprint
@treturn ts_msg_imprint
*/
static int openssl_ts_info_msg_imprint(lua_State *L)
{
  TS_TST_INFO *info = CHECK_OBJECT(1, TS_TST_INFO, "openssl.ts_tst_info");
  TS_MSG_IMPRINT *msg = TS_TST_INFO_get_msg_imprint(info);
  if (msg)
  {
    msg = TS_MSG_IMPRINT_dup(msg);
    PUSH_OBJECT(msg, "openssl.ts_msg_imprint");
  }else
    lua_pushnil(L);
  return 1;
}

/***
get serialNumber of ts_tst_info object object
@function serial
@treturn openssl.bn
*/
static int openssl_ts_info_serial(lua_State *L)
{
  TS_TST_INFO *info = CHECK_OBJECT(1, TS_TST_INFO, "openssl.ts_tst_info");
  openssl_push_asn1integer_as_bn(L, TS_TST_INFO_get_serial(info));
  return 1;
}

/***
get time of ts_tst_info object object
@function time
@treturn asn1_time
*/
static int openssl_ts_info_time(lua_State *L)
{
  TS_TST_INFO *info = CHECK_OBJECT(1, TS_TST_INFO, "openssl.ts_tst_info");
  openssl_push_asn1(L, TS_TST_INFO_get_time(info), V_ASN1_GENERALIZEDTIME);
  return 1;
}

/***
get accuracy of ts_tst_info object object
@function accuracy
@treturn table
*/
static int openssl_ts_info_accuracy(lua_State *L)
{
  int ret = 0;
  TS_TST_INFO *info = CHECK_OBJECT(1, TS_TST_INFO, "openssl.ts_tst_info");
  if (lua_isnone(L, 2))
  {
    TS_ACCURACY *accuracy = TS_TST_INFO_get_accuracy(info);
    accuracy = TS_ACCURACY_dup(accuracy);
    PUSH_OBJECT(accuracy, "openssl.ts_accuracy");
    ret = 1;
  } else {
    TS_ACCURACY *accuracy = CHECK_OBJECT(2, TS_ACCURACY, "openssl.ts_accuracy");
    int ret = TS_TST_INFO_set_accuracy(info, accuracy);
    ret = openssl_pushresult(L, ret);
  }
  return ret;
}

/***
get ordering of ts_tst_info object object
@function ording
@treturn table
*/
static int openssl_ts_info_ordering(lua_State *L)
{
  TS_TST_INFO *info = CHECK_OBJECT(1, TS_TST_INFO, "openssl.ts_tst_info");
  lua_pushboolean(L, TS_TST_INFO_get_ordering(info));
  return 1;
}

/***
get nonce of ts_tst_info object object
@function nonce
@treturn openssl.bn
*/
static int openssl_ts_info_nonce(lua_State *L)
{
  TS_TST_INFO *info = CHECK_OBJECT(1, TS_TST_INFO, "openssl.ts_tst_info");
  openssl_push_asn1integer_as_bn(L, TS_TST_INFO_get_nonce(info));
  return 1;
}

/***
get tsa nonce of ts_tst_info object object
@function tsa
@treturn x509.name
*/
static int openssl_ts_info_tsa(lua_State *L)
{
  TS_TST_INFO *info = CHECK_OBJECT(1, TS_TST_INFO, "openssl.ts_tst_info");
  openssl_push_general_name(L, TS_TST_INFO_get_tsa(info));
  return 1;
}

/***
get extensions nonce of ts_tst_info object object
@function extensions
@treturn table
*/
static int openssl_ts_info_extensions(lua_State *L)
{
  TS_TST_INFO *info = CHECK_OBJECT(1, TS_TST_INFO, "openssl.ts_tst_info");
  STACK_OF(X509_EXTENSION) *exts =  TS_TST_INFO_get_exts(info);
  if (exts)
  {
    openssl_sk_x509_extension_totable(L, exts);
  }
  else
    lua_pushnil(L);
  return 1;
}

static int openssl_ts_info_gc(lua_State *L)
{
  TS_TST_INFO *info = CHECK_OBJECT(1, TS_TST_INFO, "openssl.ts_tst_info");
  TS_TST_INFO_free(info);
  return 0;
}

static luaL_Reg ts_tst_info_funcs[] =
{
  {"version",       openssl_ts_info_version},
  {"policy_id",     openssl_ts_info_policy_id},
  {"msg_imprint",   openssl_ts_info_msg_imprint},
  {"serial",        openssl_ts_info_serial},
  {"time",          openssl_ts_info_time},
  {"accuracy",      openssl_ts_info_accuracy},
  {"ordering",      openssl_ts_info_ordering},
  {"nonce",         openssl_ts_info_nonce},
  {"tsa",           openssl_ts_info_tsa},
  {"extensions",    openssl_ts_info_extensions},

  {"__gc",          openssl_ts_info_gc},
  {"__tostring",    auxiliar_tostring},

  {NULL,    NULL}
};

/***
create a new ts_req object.
@function req_new
@tparam[opt=1] integer version
@treturn ts_req timestamp sign request object
@see ts_req
*/
static LUA_FUNCTION(openssl_ts_req_new)
{
  TS_REQ *ts_req = TS_REQ_new();
  long version = luaL_optinteger(L, 1, 1);

  int ret = TS_REQ_set_version(ts_req, version);
  if (ret == 1)
  {
    PUSH_OBJECT(ts_req, "openssl.ts_req");
    return 1;
  }
  TS_REQ_free(ts_req);
  return 0;
}

/***
read ts_req object from string or bio data
@function req_read
@tparam string|bio input
@treturn ts_req timestamp sign request object
@see ts_req
*/
static LUA_FUNCTION(openssl_ts_req_read)
{
  BIO *in = load_bio_object(L, 1);
  TS_REQ *ts_req = d2i_TS_REQ_bio(in, NULL);
  BIO_free(in);
  if (ts_req)
  {
    PUSH_OBJECT(ts_req, "openssl.ts_req");
    return 1;
  }
  return 0;
}

/***
read ts_resp object from string or bio input
@function resp_read
@tparam string|bio input
@treturn ts_resp object
*/
static LUA_FUNCTION(openssl_ts_resp_read)
{
  BIO* in = load_bio_object(L, 1);
  TS_RESP *res = d2i_TS_RESP_bio(in, NULL);
  BIO_free(in);
  if (res)
  {
    PUSH_OBJECT(res, "openssl.ts_resp");
  }
  else
    lua_pushnil(L);
  return 1;
}

/***
create ts_resp_ctx object
@function resp_ctx_new
@tparam x509 signer timestamp certificate
@tparam evp_pkey pkey private key to sign ts_req
@tparam asn1_object|string|nid identity for default policy object
@treturn ts_resp_ctx object
*/
static LUA_FUNCTION(openssl_ts_resp_ctx_new)
{
  TS_RESP_CTX* ctx = NULL;
  X509 *signer = NULL;
  EVP_PKEY *pkey = NULL;
  ASN1_OBJECT *obj = NULL;
  int ret = 1;

  luaL_argcheck(L, auxiliar_getclassudata(L, "openssl.x509", 1), 1,
                "need openssl.x509 object");
  luaL_argcheck(L, auxiliar_getclassudata(L, "openssl.evp_pkey", 2), 2,
                "need openssl.pkey object");
  luaL_argcheck(L,
                auxiliar_getclassudata(L, "openssl.asn1_object", 3) ||
                lua_isnumber(L, 3) || lua_isstring(L, 3), 3,
                "need openssl.asn1_object, nid string or number");

  signer = CHECK_OBJECT(1, X509, "openssl.x509");
  pkey = CHECK_OBJECT(2, EVP_PKEY, "openssl.evp_pkey");
  obj = openssl_get_asn1object(L, 3, 0);

  if (signer && pkey)
  {
    ret = X509_check_private_key(signer, pkey);
    if (ret != 1)
      luaL_error(L, "signer cert and private key not match");
  }

  ctx = TS_RESP_CTX_new();
  if (ret == 1 && obj)
    ret = TS_RESP_CTX_set_def_policy(ctx, obj);
  if (ret == 1 && signer)
    ret = TS_RESP_CTX_set_signer_cert(ctx, signer);
  if (ret == 1 && pkey)
    ret = TS_RESP_CTX_set_signer_key(ctx, pkey);

  if (ret == 1)
  {
    PUSH_OBJECT(ctx, "openssl.ts_resp_ctx");
    openssl_newvalue(L, ctx);
  }
  else
  {
    TS_RESP_CTX_free(ctx);
    ctx = NULL;
    lua_pushnil(L);
  }
  if(obj)
    ASN1_OBJECT_free(obj);
  return 1;
}

/***
create ts_verify_ctx object
@function verify_ctx_new
@tparam[opt=nil] string|ts_req reqdata
@treturn ts_verify_ctx object
*/
static LUA_FUNCTION(openssl_ts_verify_ctx_new)
{
  TS_VERIFY_CTX *ctx = NULL;
  if (lua_isnone(L, 1))
  {
    ctx = TS_VERIFY_CTX_new();
  }
  else if (lua_isstring(L, 1))
  {
    BIO* bio = load_bio_object(L, 1);
    TS_REQ* req = d2i_TS_REQ_bio(bio, NULL);
    BIO_free(bio);
    if (req)
    {
      ctx = TS_REQ_to_TS_VERIFY_CTX(req, NULL);
      TS_REQ_free(req);
    }
    else
    {
      luaL_argerror(L, 1, "must be ts_req data or object or nil");
    }
  }
  else
  {
    TS_REQ* req = CHECK_OBJECT(1, TS_REQ, "openssl.ts_req");
    ctx = TS_REQ_to_TS_VERIFY_CTX(req, NULL);
  }
  if (ctx)
  {
    PUSH_OBJECT(ctx, "openssl.ts_verify_ctx");
  }
  else
    lua_pushnil(L);
  return 1;
}

static luaL_Reg R[] =
{
  {"req_new",         openssl_ts_req_new},
  {"req_read",        openssl_ts_req_read},
  {"resp_read",       openssl_ts_resp_read},
  {"ts_accuracy_read",openssl_ts_accuracy_read},
  {"ts_msg_imprint_read",
                      openssl_ts_msg_imprint_read},

  {"resp_ctx_new",    openssl_ts_resp_ctx_new},
  {"verify_ctx_new",  openssl_ts_verify_ctx_new},
  {"ts_accuracy_new", openssl_ts_accuracy_new},
  {"ts_msg_imprint_new",
                      openssl_ts_msg_imprint_new},

  {NULL,    NULL}
};

/***
openssl.ts_req object
@type ts_req
*/
/***
make a clone of ts_req object
@function dup
@treturn ts_req
*/
static int openssl_ts_req_dup(lua_State*L)
{
  TS_REQ* req = CHECK_OBJECT(1, TS_REQ, "openssl.ts_req");
  req = TS_REQ_dup(req);
  PUSH_OBJECT(req, "openssl.ts_req");
  return 1;
}

/***
get cert_req
@function cert_req
@treturn boolean true for set or not
*/
/***
set cert_req
@function cert_req
@tparam boolean cert_req
@treturn boolean result
*/
static int openssl_ts_req_cert_req(lua_State *L)
{
  TS_REQ* req = CHECK_OBJECT(1, TS_REQ, "openssl.ts_req");
  if (lua_isnone(L, 2))
  {
    lua_pushboolean(L, TS_REQ_get_cert_req(req));
    return 1;
  }
  else
  {
    int cert_req = auxiliar_checkboolean(L, 2);
    int ret = TS_REQ_set_cert_req(req, cert_req);
    return openssl_pushresult(L, ret);
  }
}

/***
get nonce
@function nonce
@treturn bn openssl.bn object
*/
/***
set nonce
@tparam string|bn nonce
@treturn boolean result
@function nonce
*/
static int openssl_ts_req_nonce(lua_State*L)
{
  TS_REQ* req = CHECK_OBJECT(1, TS_REQ, "openssl.ts_req");
  if (lua_isnone(L, 2))
  {
    return openssl_push_asn1integer_as_bn(L, TS_REQ_get_nonce(req));
  }
  else
  {
    BIGNUM *bn = BN_get(L, 2);
    if(bn)
    {
      ASN1_INTEGER *ai = BN_to_ASN1_INTEGER(bn, NULL);
      int ret = TS_REQ_set_nonce(req, ai);
      ASN1_INTEGER_free(ai);
      BN_free(bn);
      return openssl_pushresult(L, ret);
    }
    return luaL_argerror(L, 2, "invalid openssl.bn or can't convert to openssl.bn");
  }
}

/***
get policy_id
@function policy_id
@treturn asn1_object
*/
/***
set policy_id
@function policy_id
@tparam asn1_object|number id  identity for asn1_object
@treturn boolean result
*/
static int openssl_ts_req_policy_id(lua_State*L)
{
  TS_REQ* req = CHECK_OBJECT(1, TS_REQ, "openssl.ts_req");
  if (lua_isnone(L, 2))
  {
    ASN1_OBJECT* obj = TS_REQ_get_policy_id(req);
    openssl_push_asn1object(L, obj);
    return 1;
  }
  else
  {
    ASN1_OBJECT* obj = openssl_get_asn1object(L, 2, 0);
    int ret= TS_REQ_set_policy_id(req, obj);
    ASN1_OBJECT_free(obj);
    return openssl_pushresult(L, ret);
  }
}

/***
get version
@treturn integer
@function version
*/
/***
set version
@tparam integer version
@treturn boolean result
@function version
*/
static int openssl_ts_req_version(lua_State*L)
{
  TS_REQ* req = CHECK_OBJECT(1, TS_REQ, "openssl.ts_req");
  if (lua_isnone(L, 2))
  {
    lua_pushinteger(L, TS_REQ_get_version(req));
    return 1;
  }
  else
  {
    long v = luaL_checkinteger(L, 2);
    int ret = TS_REQ_set_version(req, v);
    return openssl_pushresult(L, ret);
  }
}

/***
get msg_imprint
@function msg_imprint
@treturn string octet octet string
@treturn table with algorithm and paramater
*/
/***
set msg_imprint
@function msg_imprint
@tparam string data digest value of message
@tparam[opt='sha'] string|evp_md md_alg
@treturn boolean result
*/
static int openssl_ts_req_msg_imprint(lua_State*L)
{
  TS_REQ* req = CHECK_OBJECT(1, TS_REQ, "openssl.ts_req");
  if (lua_isnone(L, 2))
  {
    TS_MSG_IMPRINT * msg = TS_REQ_get_msg_imprint(req);
    if (msg)
    {
      msg = TS_MSG_IMPRINT_dup(msg);
      PUSH_OBJECT(msg, "openssl.ts_msg_imprint");
    }
    else
      lua_pushnil(L);
    return 1;
  }
  else
  {
    TS_MSG_IMPRINT * msg = CHECK_OBJECT(2, TS_MSG_IMPRINT, "openssl.ts_msg_imprint");
    int ret = TS_REQ_set_msg_imprint(req, msg);

    return openssl_pushresult(L, ret);
  }
};

/***
create ts_verify_ctx from ts_req object
@function to_verify_ctx
@treturn ts_verify_ctx object
*/
static LUA_FUNCTION(openssl_ts_req_to_verify_ctx)
{
  TS_REQ *req = CHECK_OBJECT(1, TS_REQ, "openssl.ts_req");
  TS_VERIFY_CTX *ctx = TS_REQ_to_TS_VERIFY_CTX(req, NULL);
  PUSH_OBJECT(ctx, "openssl.ts_verify_ctx");
  return 1;
}

/***
export ts_req to string
@function export
@treturn string
*/
static LUA_FUNCTION(openssl_ts_req_export)
{
  TS_REQ *ts_req = CHECK_OBJECT(1, TS_REQ, "openssl.ts_req");
  unsigned char *data = NULL;
  int len = i2d_TS_REQ(ts_req, &data);
  if (len > 0)
  {
    lua_pushlstring(L, (const char*)data, (size_t)len);
    OPENSSL_free(data);
    return 1;
  }
  return 0;
}

static LUA_FUNCTION(openssl_ts_req_add_ext)
{
  TS_REQ *ts_req = CHECK_OBJECT(1, TS_REQ, "openssl.ts_req");
  X509_EXTENSION *x = CHECK_OBJECT(2, X509_EXTENSION, "openssl.x509_extension");
  int loc = luaL_optint(L, 3, TS_REQ_get_ext_count(ts_req));
  int ret;

  ret = TS_REQ_add_ext(ts_req, x, loc);
  return openssl_pushresult(L, ret);
}

/***
get info as table
@function info
@treturn table
*/
static LUA_FUNCTION(openssl_ts_req_info)
{
  TS_REQ *req = CHECK_OBJECT(1, TS_REQ, "openssl.ts_req");

  lua_newtable(L);

  lua_pushinteger(L, TS_REQ_get_version(req));
  lua_setfield(L, -2, "version");

  AUXILIAR_SET(L, -1, "cert_req", TS_REQ_get_cert_req(req), boolean);

  if (TS_REQ_get_policy_id(req))
  {
    openssl_push_asn1object(L, TS_REQ_get_policy_id(req));
    lua_setfield(L, -2, "policy_id");
  }

  openssl_push_asn1integer_as_bn(L, TS_REQ_get_nonce(req));
  lua_setfield(L, -2, "nonce");

  lua_newtable(L);
  {
    TS_MSG_IMPRINT *msg_inprint = TS_REQ_get_msg_imprint(req);
    ASN1_OCTET_STRING *os = TS_MSG_IMPRINT_get_msg(msg_inprint);
    X509_ALGOR *alg = TS_MSG_IMPRINT_get_algo(msg_inprint);

    AUXILIAR_SETLSTR(L, -1, "hashed_msg", (const char*)os->data, os->length);
    alg = X509_ALGOR_dup(alg);
    PUSH_OBJECT(alg, "openssl.x509_algor");
    lua_setfield(L, -2, "hash_algo");
  }
  lua_setfield(L, -2, "msg_imprint");

  if (TS_REQ_get_exts(req))
  {
    lua_pushstring(L, "extensions");
    openssl_sk_x509_extension_totable(L, TS_REQ_get_exts(req));
    lua_rawset(L, -3);
  }

  return 1;
}

static LUA_FUNCTION(openssl_ts_req_gc)
{
  TS_REQ *req = CHECK_OBJECT(1, TS_REQ, "openssl.ts_req");
  TS_REQ_free(req);
  return 0;
}

static luaL_Reg ts_req_funs[] =
{
  {"dup",           openssl_ts_req_dup},
  {"cert_req",      openssl_ts_req_cert_req},
  {"msg_imprint",   openssl_ts_req_msg_imprint},
  {"nonce",         openssl_ts_req_nonce},
  {"policy_id",     openssl_ts_req_policy_id},
  {"version",       openssl_ts_req_version},
  {"info",          openssl_ts_req_info},
  {"export",        openssl_ts_req_export},
  {"add_ext",       openssl_ts_req_add_ext},

  {"to_verify_ctx", openssl_ts_req_to_verify_ctx},

  {"__tostring",    auxiliar_tostring},
  {"__gc",          openssl_ts_req_gc},

  { NULL, NULL }
};

/***
openssl.ts_resp object
@type ts_resp
*/
static LUA_FUNCTION(openssl_ts_resp_gc)
{
  TS_RESP *res = CHECK_OBJECT(1, TS_RESP, "openssl.ts_resp");
  TS_RESP_free(res);
  return 0;
}

/***
duplicate ts_resp object
@function dup
@treturn ts_resp object
*/
static LUA_FUNCTION(openssl_ts_resp_dup)
{
  TS_RESP *res = CHECK_OBJECT(1, TS_RESP, "openssl.ts_resp");
  res = TS_RESP_dup(res);
  PUSH_OBJECT(res, "openssl.ts_resp");
  return 1;
}

/***
export ts_resp to string
@function export
@treturn string
*/
static LUA_FUNCTION(openssl_ts_resp_export)
{
  int ret = 0;
  TS_RESP *res = CHECK_OBJECT(1, TS_RESP, "openssl.ts_resp");
  BIO *bio = BIO_new(BIO_s_mem());
  if (i2d_TS_RESP_bio(bio, res))
  {
    BUF_MEM *bptr = NULL;
    BIO_get_mem_ptr(bio, &bptr);
    lua_pushlstring(L, bptr->data, bptr->length);
    ret = 1;
  }
  BIO_free(bio);
  return ret;
}

/***
get tst_info as table or tst_info filed value
@function tst_info
@tparam[opt] string field
@return tst_info table or feild value
*/
static LUA_FUNCTION(openssl_ts_resp_tst_info)
{
  TS_RESP *resp = CHECK_OBJECT(1, TS_RESP, "openssl.ts_resp");
  TS_TST_INFO *info = TS_RESP_get_tst_info(resp);

  if(info)
  {
    info = TS_TST_INFO_dup(info);
    PUSH_OBJECT(info, "openssl.ts_tst_info");
  }
  else
    lua_pushnil(L);

  return 1;
}

/***
get status_info as table
@function status_info
@treturn table
*/
static LUA_FUNCTION(openssl_ts_resp_status_info)
{
  TS_RESP *res = CHECK_OBJECT(1, TS_RESP, "openssl.ts_resp");
  TS_STATUS_INFO *si = TS_RESP_get_status_info(res);
  const STACK_OF(ASN1_UTF8STRING) * sk = TS_STATUS_INFO_get0_text(si);
  const ASN1_BIT_STRING *failure_info = TS_STATUS_INFO_get0_failure_info(si);

  lua_newtable(L);

  openssl_push_asn1integer_as_bn(L, TS_STATUS_INFO_get0_status(si));
  lua_setfield(L, -2, "status");

  if (failure_info)
  {
    openssl_push_asn1(L, failure_info, V_ASN1_BIT_STRING);
    lua_setfield(L, -2, "failure_info");
  }

  if (sk)
  {
    int i = 0, n = 0;
    n = sk_ASN1_UTF8STRING_num(sk);
    for (i = 0; i < n; i++)
    {
      ASN1_UTF8STRING *x = sk_ASN1_UTF8STRING_value(sk, i);
      lua_pushlstring(L, (const char*)x->data, x->length);
      lua_rawseti(L, -2, i + 1);
    }
  }

  return 1;
}

/***
get pkcs7 token of ts_tst_info
@function token
@treturn token
*/
static int openssl_ts_resp_token(lua_State *L)
{
  TS_RESP *res = CHECK_OBJECT(1, TS_RESP, "openssl.ts_resp");
  PKCS7* token = TS_RESP_get_token(res);
  if (token)
  {
    token = PKCS7_dup(token);
    PUSH_OBJECT(token, "openssl.pkcs7");
  }else
    lua_pushnil(L);
  return 1;
}

static luaL_Reg ts_resp_funs[] =
{
  {"dup",           openssl_ts_resp_dup},
  {"export",        openssl_ts_resp_export},
  {"status_info",   openssl_ts_resp_status_info},
  {"token",         openssl_ts_resp_token},
  {"tst_info",      openssl_ts_resp_tst_info},

  {"__tostring",    auxiliar_tostring},
  {"__gc",          openssl_ts_resp_gc},

  { NULL, NULL }
};

/********************************************************/
/***
openssl.ts_resp_ctx object
@type ts_resp_ctx
*/
/***
create response for ts_req
@function create_response
@tparam string|bio|ts_req data support string,bio ts_req content or ts_req object
@treturn ts_resp result
*/
/***
sign ts_req and get ts_resp, alias of create_response
@function sign
@tparam string|bio|ts_req data support string,bio ts_req content or ts_req object
@treturn ts_resp result
*/
static LUA_FUNCTION(openssl_ts_create_response)
{
  TS_RESP_CTX *ctx = CHECK_OBJECT(1, TS_RESP_CTX, "openssl.ts_resp_ctx");
  BIO *bio = load_bio_object(L, 2);
  TS_RESP *resp  = TS_RESP_create_response(ctx, bio);
  if (resp)
  {
    PUSH_OBJECT(resp, "openssl.ts_resp");
  }
  else
    lua_pushnil(L);
  BIO_free(bio);

  return 1;
}

/***
get signer cert and pkey
@function signer
@treturn x509 cert object or nil
@treturn evp_pkey pkey object or nil
*/
/***
set signer cert and pkey
@function signer
@tparam x509 cert signer cert
@tparam evp_pkey pkey signer pkey
@treturn boolean result
*/
static LUA_FUNCTION(openssl_ts_resp_ctx_signer)
{
  TS_RESP_CTX *ctx = CHECK_OBJECT(1, TS_RESP_CTX, "openssl.ts_resp_ctx");
  X509 *signer = CHECK_OBJECT(2, X509, "openssl.x509");
  EVP_PKEY *pkey = CHECK_OBJECT(3, EVP_PKEY, "openssl.evp_pkey");
  int ret = X509_check_private_key(signer, pkey);
  if (ret != 1)
  {
    luaL_error(L, "signer cert and private key not match");
  }
  if (ret == 1)
    ret = TS_RESP_CTX_set_signer_cert(ctx, signer);
  if (ret == 1)
    ret = TS_RESP_CTX_set_signer_key(ctx, pkey);
  return openssl_pushresult(L, ret);
}

/***
set additional certs
@function certs
@tparam table certs array of certificates
@treturn boolean success
*/
static LUA_FUNCTION(openssl_ts_resp_ctx_certs)
{
  int ret;
  TS_RESP_CTX *ctx = CHECK_OBJECT(1, TS_RESP_CTX, "openssl.ts_resp_ctx");
  STACK_OF(X509) *certs = openssl_sk_x509_fromtable(L, 2);
  ret = TS_RESP_CTX_set_certs(ctx, certs);
  sk_X509_pop_free(certs, X509_free);
  return openssl_pushresult(L, ret);
}

/***
set default policy
@function default_policy
@tparam asn1_object|integer|string policy
@treturn boolean success
*/
static LUA_FUNCTION(openssl_ts_resp_ctx_default_policy)
{
  TS_RESP_CTX *ctx = CHECK_OBJECT(1, TS_RESP_CTX, "openssl.ts_resp_ctx");
  ASN1_OBJECT *obj = openssl_get_asn1object(L, 2, 0);
  int ret = TS_RESP_CTX_set_def_policy(ctx, obj);
  ASN1_OBJECT_free(obj);
  return openssl_pushresult(L, ret);
}

/***
set policies
@function policies
@tparam asn1_object|integer|string|stack_of_asn1_object|table policies
@treturn boolean success
*/
static LUA_FUNCTION(openssl_ts_resp_ctx_policies)
{
  TS_RESP_CTX *ctx = CHECK_OBJECT(1, TS_RESP_CTX, "openssl.ts_resp_ctx");
  ASN1_OBJECT *obj = NULL;
  int ret = 1;
  int i;
  int n = lua_gettop(L);
  luaL_argcheck(L, n > 1, 2, "need one or more asn1_object");
  for (i = 2; i <= n && ret == 1; i++)
  {
    if (lua_istable(L, i))
    {
      int j, k;
      k = lua_rawlen(L, i);
      for (j = 1; j <= k && ret == 1; j++)
      {
        lua_rawgeti(L, i, j);
        obj = openssl_get_asn1object(L, -1, 0);
        lua_pop(L, 1);

        ret = TS_RESP_CTX_add_policy(ctx, obj);
        ASN1_OBJECT_free(obj);
      }
    }
    else
    {
      obj = openssl_get_asn1object(L, i, 0);
      ret = TS_RESP_CTX_add_policy(ctx, obj);
      ASN1_OBJECT_free(obj);
    }
  }
  return openssl_pushresult(L, ret);
}

/***
get accuracy
@function accuracy
@treturn integer seconds
@treturn integer millis
@treturn integer micros
*/
/***
set accuracy
@function accuracy
@tparam integer seconds
@tparam integer millis
@tparam integer micros
@treturn boolean result
*/
static LUA_FUNCTION(openssl_ts_resp_ctx_accuracy)
{
  TS_RESP_CTX *ctx = CHECK_OBJECT(1, TS_RESP_CTX, "openssl.ts_resp_ctx");
  int seconds = luaL_checkint(L, 2);
  int millis = luaL_checkint(L, 3);
  int micros = luaL_checkint(L, 4);
  int ret = TS_RESP_CTX_set_accuracy(ctx, seconds, millis, micros);
  return openssl_pushresult(L, ret);
}

/***
get clock_precision_digits
@function clock_precision_digits
@treturn integer clock_precision_digits
*/
/***
set clock_precision_digits
@function clock_precision_digits
@tparam integer clock_precision_digits
@treturn boolean result
*/
static LUA_FUNCTION(openssl_ts_resp_ctx_clock_precision_digits)
{
  TS_RESP_CTX *ctx = CHECK_OBJECT(1, TS_RESP_CTX, "openssl.ts_resp_ctx");
  int ret;
  int clock_precision_digits = luaL_checkint(L, 2);
  if (clock_precision_digits > TS_MAX_CLOCK_PRECISION_DIGITS)
    clock_precision_digits = TS_MAX_CLOCK_PRECISION_DIGITS;
  if (clock_precision_digits < 0)
    clock_precision_digits = 0;
  ret = TS_RESP_CTX_set_clock_precision_digits(ctx, clock_precision_digits);
  return openssl_pushresult(L, ret);
}

/***
get flags
@function flags
*/
static LUA_FUNCTION(openssl_ts_resp_ctx_add_flags)
{
  TS_RESP_CTX *ctx = CHECK_OBJECT(1, TS_RESP_CTX, "openssl.ts_resp_ctx");
  int flags = luaL_checkint(L, 2);
  TS_RESP_CTX_add_flags(ctx, flags);
  return 0;
}

/***
set support digest method
@function md
@tparam table mds support digest method
@treturn boolean result
*/
/***
add digest
@function md
@tparam string|evp_digest md_alg
@treturn boolean result
*/
static LUA_FUNCTION(openssl_ts_resp_ctx_md)
{
  TS_RESP_CTX *ctx = CHECK_OBJECT(1, TS_RESP_CTX, "openssl.ts_resp_ctx");
  if (lua_istable(L, 2))
  {
    int i;
    int n = lua_rawlen(L, 2);
    int ret = 1;
    for (i = 1; ret == 1 && i <= n; i++)
    {
      const EVP_MD* md;
      lua_rawgeti(L, 2, i);
      md = get_digest(L, -1, NULL);
      lua_pop(L, 1);
      if (md)
      {
        ret = TS_RESP_CTX_add_md(ctx, md);
      }
      else
      {
        lua_pushfstring(L, "#%d not valid evp_digest object or id", i);
        luaL_argcheck(L, md, 2, lua_tostring(L, -1));
        lua_pop(L, 1);
      }
    }
    return openssl_pushresult(L, ret);
  }
  else
  {
    const EVP_MD* md = get_digest(L, 2, NULL);
    int ret = TS_RESP_CTX_add_md(ctx, md);
    return openssl_pushresult(L, ret);
  }
}

/***
get tst_info as table
@function tst_info
@tparam[opt] string field
@return tst_info table or feild value
*/
static LUA_FUNCTION(openssl_ts_resp_ctx_tst_info)
{
  TS_RESP_CTX *ctx = CHECK_OBJECT(1, TS_RESP_CTX, "openssl.ts_resp_ctx");
  TS_TST_INFO *info = TS_RESP_CTX_get_tst_info(ctx);

  if(info)
  {
    info = TS_TST_INFO_dup(info);
    PUSH_OBJECT(info, "openssl.ts_tst_info");
  }
  else
    lua_pushnil(L);

  return 1;
}

/***
get ts_req object
@function request
@treturn rs_req
*/
static LUA_FUNCTION(openssl_ts_resp_ctx_request)
{
  TS_RESP_CTX *ctx = CHECK_OBJECT(1, TS_RESP_CTX, "openssl.ts_resp_ctx");
  TS_REQ *req = TS_RESP_CTX_get_request(ctx);
  if (req)
  {
    PUSH_OBJECT(req, "openssl.ts_req");
  }
  else
    lua_pushnil(L);
  return 1;
}

typedef struct
{
  int callback;
  int cb_arg;
} TS_CB_ARG;

static const char* time_cb_key  = "time_cb_key";
static const char* serial_cb_key = "serial_cb_key";

static ASN1_INTEGER* openssl_serial_cb(TS_RESP_CTX*ctx, void*data)
{
  int err;
  TS_CB_ARG *arg;
  lua_State* L = data;

  openssl_valueget(L, ctx, serial_cb_key);
  if (!lua_isuserdata(L, -1))
  {
    TS_RESP_CTX_set_status_info(ctx, TS_STATUS_REJECTION,
                                "Error during serial number generation.");
    TS_RESP_CTX_add_failure_info(ctx, TS_INFO_ADD_INFO_NOT_AVAILABLE);

    lua_pop(L, 1);
    return NULL;
  }
  arg = lua_touserdata(L, -1);
  lua_pop(L, 1); /* remove openssl_valueget returned value */

  lua_rawgeti(L, LUA_REGISTRYINDEX, arg->callback);
  lua_rawgeti(L, LUA_REGISTRYINDEX, arg->cb_arg);
  err = lua_pcall(L, 1, 1, 0);
  if (err == 0)
  {
    ASN1_INTEGER *ai = NULL;
    BIGNUM *bn = BN_get(L, -1);
    lua_pop(L, 1);  /* remove callback returned value */
    if (bn)
    {
      ai = BN_to_ASN1_INTEGER(bn, NULL);
      BN_free(bn);
    }
    if (ai == NULL)
    {
      TS_RESP_CTX_set_status_info(ctx, TS_STATUS_REJECTION,
                                  "Error during serial number generation.");
      TS_RESP_CTX_add_failure_info(ctx, TS_INFO_ADD_INFO_NOT_AVAILABLE);
      luaL_error(L, "Error during serial number generation.");
    }
    return ai;
  }
  else
  {
    lua_error(L);
  }
  return NULL;
};

/***
set serial generate callback function
@function set_serial_cb
@tparam function serial_cb serial_cb with proto funciont(ts_resp_ctx, arg) return openssl.bn end
@usage
  function serial_cb(tsa,arg)
    local bn = ...
    return bn
  end
  local arg = {}
  ts_resp_ctx:set_serial_cb(serial_cb, arg)
*/
static LUA_FUNCTION(openssl_ts_resp_ctx_set_serial_cb)
{
  TS_RESP_CTX *ctx = CHECK_OBJECT(1, TS_RESP_CTX, "openssl.ts_resp_ctx");
  TS_CB_ARG* arg = NULL;
  int top = lua_gettop(L);

  luaL_checktype(L, 2, LUA_TFUNCTION);
  arg = (TS_CB_ARG*)lua_newuserdata(L, sizeof(TS_CB_ARG));

  lua_pushvalue(L, 2);
  arg->callback = luaL_ref(L, LUA_REGISTRYINDEX);
  if (top > 2)
    lua_pushvalue(L, 3);
  else
    lua_pushnil(L);
  arg->cb_arg = luaL_ref(L, LUA_REGISTRYINDEX);

  openssl_valueset(L, ctx, serial_cb_key);
  TS_RESP_CTX_set_serial_cb(ctx, openssl_serial_cb, L);
  return 0;
};

static int openssl_time_cb(TS_RESP_CTX *ctx, void *data, long *sec, long *usec)
{
  int err;
  TS_CB_ARG *arg;
  lua_State* L = data;

  openssl_valueget(L, ctx, time_cb_key);
  if (!lua_isuserdata(L, -1))
  {
    TS_RESP_CTX_set_status_info(ctx, TS_STATUS_REJECTION,
                                "could not get current time");
    lua_pop(L, 1);  /* remove openssl_valueget returned value */
    return 0;
  }
  arg = lua_touserdata(L, -1);
  lua_pop(L, 1);  /* remove openssl_valueget returned value */

  lua_rawgeti(L, LUA_REGISTRYINDEX, arg->callback);
  lua_rawgeti(L, LUA_REGISTRYINDEX, arg->cb_arg);
  err = lua_pcall(L, 1, 2, 0);
  if (err == 0)
  {
    if (lua_isnumber(L, -2))
    {
      *sec = (long)luaL_checkinteger(L, -2);
      *usec = (long)luaL_optinteger(L, -1, 0);
      lua_pop(L, 2);  /* remove callback returned value */
      return 1;
    }
    lua_pop(L, 2);    /* remove callback returned value */

    TS_RESP_CTX_set_status_info(ctx, TS_STATUS_REJECTION,
                                "could not get current time");
    return 0;
  }
  else
  {
    lua_error(L);
  }
  return 0;
}

/***
set time callback function
@function set_time_cb
@tparam function time_cb serial_cb with proto funciont(ts_resp_ctx, arg) return sec, usec end
@usage
  function time_cb(tsa,arg)
    local time = os.time()
    local utime = nil
    return time,utime
  end
  local arg = {}
  ts_resp_ctx:set_time_cb(time_cb, arg)
*/
static LUA_FUNCTION(openssl_ts_resp_ctx_set_time_cb)
{
  TS_RESP_CTX *ctx = CHECK_OBJECT(1, TS_RESP_CTX, "openssl.ts_resp_ctx");
  TS_CB_ARG* arg = NULL;
  int top = lua_gettop(L);
  luaL_checktype(L, 2, LUA_TFUNCTION);
  arg = (TS_CB_ARG*)lua_newuserdata(L, sizeof(TS_CB_ARG));

  lua_pushvalue(L, 2);
  arg->callback = luaL_ref(L, LUA_REGISTRYINDEX);
  if (top > 2)
    lua_pushvalue(L, 3);
  else
    lua_pushnil(L);
  arg->cb_arg = luaL_ref(L, LUA_REGISTRYINDEX);

  openssl_valueset(L, ctx, time_cb_key);
#if defined(LIBRESSL_VERSION_NUMBER) && LIBRESSL_VERSION_NUMBER < 0x3060000fL
  ctx->time_cb = openssl_time_cb;
  ctx->time_cb_data = L;
#else
  TS_RESP_CTX_set_time_cb(ctx, openssl_time_cb, L);
#endif
  return 0;
}

static LUA_FUNCTION(openssl_ts_resp_ctx_gc)
{
  TS_RESP_CTX *ctx = CHECK_OBJECT(1, TS_RESP_CTX, "openssl.ts_resp_ctx");
  openssl_valueget(L, ctx, time_cb_key);
  if (lua_isuserdata(L, -1))
  {
    TS_CB_ARG *arg = lua_touserdata(L, -1);
    luaL_unref(L, LUA_REGISTRYINDEX, arg->callback);
    luaL_unref(L, LUA_REGISTRYINDEX, arg->cb_arg);
  }
  lua_pop(L, 1);
  openssl_valueget(L, ctx, serial_cb_key);
  if (lua_isuserdata(L, -1))
  {
    TS_CB_ARG *arg = lua_touserdata(L, -1);
    luaL_unref(L, LUA_REGISTRYINDEX, arg->callback);
    luaL_unref(L, LUA_REGISTRYINDEX, arg->cb_arg);
  }
  lua_pop(L, 1);
  openssl_freevalue(L, ctx);
  TS_RESP_CTX_free(ctx);
  return 0;
}


static luaL_Reg ts_resp_ctx_funs[] =
{
  /* get and set */
  {"signer",              openssl_ts_resp_ctx_signer},
  {"certs",               openssl_ts_resp_ctx_certs},
  {"default_policy",      openssl_ts_resp_ctx_default_policy},
  {"policies",            openssl_ts_resp_ctx_policies},
  {"accuracy",            openssl_ts_resp_ctx_accuracy},
  {"clock_precision_digits",  openssl_ts_resp_ctx_clock_precision_digits},
  {"md",                  openssl_ts_resp_ctx_md},
  {"add_flags",           openssl_ts_resp_ctx_add_flags},

  /* set */
  {"set_serial_cb",      openssl_ts_resp_ctx_set_serial_cb},
  {"set_time_cb",        openssl_ts_resp_ctx_set_time_cb},

  /* get */
  {"request",            openssl_ts_resp_ctx_request},
  {"tst_info",           openssl_ts_resp_ctx_tst_info},

  {"sign",               openssl_ts_create_response},
  {"create_response",    openssl_ts_create_response},

  {"__tostring",  auxiliar_tostring},
  {"__gc",        openssl_ts_resp_ctx_gc},

  { NULL, NULL }
};

/********************************************************************/

/***
openssl.ts_verify_ctx object
@type ts_verify_ctx
*/
/***
get x509_store cacerts
@function store
@treturn stack_of_x509
*/
/***
set x509_store cacerts
@tparam x509_store cacerts
@treturn boolean result
@function store
*/
static int openssl_ts_verify_ctx_store(lua_State*L)
{
  TS_VERIFY_CTX *ctx = CHECK_OBJECT(1, TS_VERIFY_CTX, "openssl.ts_verify_ctx");
  X509_STORE* store = CHECK_OBJECT(2, X509_STORE, "openssl.x509_store");
  X509_STORE_up_ref(store);
  TS_VERIFY_CTX_set_store(ctx, store);
  return 0;
}

/***
set or add flags
@function flags
@tparam integer flags
@tparam[opt=nil] boolean add or set flags, default to do set
@treturn integer return current value
*/
static int openssl_ts_verify_ctx_flags(lua_State*L)
{
  TS_VERIFY_CTX *ctx = CHECK_OBJECT(1, TS_VERIFY_CTX, "openssl.ts_verify_ctx");
  int flags = luaL_checkint(L, 2);
  int add = lua_isnone(L, 3) ? 0 : lua_toboolean(L, 3);
  if (add)
    flags = TS_VERIFY_CTX_add_flags(ctx, flags);
  else
    flags = TS_VERIFY_CTX_set_flags(ctx, flags);
  lua_pushinteger(L, flags);
  return 1;
}

/***
set data
@function data
@tparam bio data object
@treturn boolean result
*/
static int openssl_ts_verify_ctx_data(lua_State*L)
{
  TS_VERIFY_CTX *ctx = CHECK_OBJECT(1, TS_VERIFY_CTX, "openssl.ts_verify_ctx");
  BIO* bio = load_bio_object(L, 2);
  TS_VERIFY_CTX_set_data(ctx, bio);
  return 0;
}

/***
get imprint
@function imprint
@treturn string imprint
*/
/***
set imprint
@function imprint
@tparam string imprint
@treturn boolean result
*/
static int openssl_ts_verify_ctx_imprint(lua_State*L)
{
  TS_VERIFY_CTX *ctx = CHECK_OBJECT(1, TS_VERIFY_CTX, "openssl.ts_verify_ctx");
  size_t imprint_len;
  const char* imprint = luaL_checklstring(L, 2, &imprint_len);
  unsigned char* to = OPENSSL_malloc(imprint_len);
  memcpy(to, imprint, imprint_len);
  TS_VERIFY_CTX_set_imprint(ctx, to, imprint_len);
  return 0;
}

static LUA_FUNCTION(openssl_ts_verify_ctx_gc)
{
  TS_VERIFY_CTX *ctx = CHECK_OBJECT(1, TS_VERIFY_CTX, "openssl.ts_verify_ctx");
#if OPENSSL_VERSION_NUMBER < 0x10100000L || \
  (defined(LIBRESSL_VERSION_NUMBER) && LIBRESSL_VERSION_NUMBER < 0x3050000fL)
  if (ctx->store != NULL && ctx->store->references > 1)
    CRYPTO_add(&ctx->store->references, -1, CRYPTO_LOCK_X509_STORE);
  ctx->store = NULL;
#endif
  TS_VERIFY_CTX_cleanup(ctx);
  TS_VERIFY_CTX_free(ctx);
  return 0;
}

/***
verify ts_resp object, pkcs7 token or ts_resp data
@function verify
@tparam ts_resp|pkcs7|string data
@treturn boolean result
*/
static LUA_FUNCTION(openssl_ts_verify_ctx_verify)
{
  TS_VERIFY_CTX *ctx = CHECK_OBJECT(1, TS_VERIFY_CTX, "openssl.ts_verify_ctx");
  int ret = 0;
  if (auxiliar_getclassudata(L, "openssl.ts_resp", 2))
  {
    TS_RESP *response = CHECK_OBJECT(2, TS_RESP, "openssl.ts_resp");
    ret = TS_RESP_verify_response(ctx, response);
  }
  else if (auxiliar_getclassudata(L, "openssl.pkcs7", 2))
  {
    PKCS7 *token = CHECK_OBJECT(2, PKCS7, "openssl.pkcs7");
    ret = TS_RESP_verify_token(ctx, token);
  }
  else if (lua_isstring(L, 2))
  {
    size_t size;
    const unsigned char* data = (const unsigned char*)lua_tolstring(L, 2, &size);
    TS_RESP *resp = d2i_TS_RESP(NULL, &data, size);
    if (resp)
    {
      ret = TS_RESP_verify_response(ctx, resp);
      TS_RESP_free(resp);
    }
    else
      luaL_argerror(L, 2, "data is not ts_resp object");
  }
  else
  {
    luaL_argerror(L, 2, "must be ts_resp or pkcs7 object");
  }
  return openssl_pushresult(L, ret);
}

static luaL_Reg ts_verify_ctx_funs[] =
{
  {"store",             openssl_ts_verify_ctx_store},
  {"flags",             openssl_ts_verify_ctx_flags},
  {"verify",            openssl_ts_verify_ctx_verify},
  {"data",              openssl_ts_verify_ctx_data},
  {"imprint",           openssl_ts_verify_ctx_imprint},

  {"__tostring",        auxiliar_tostring},
  {"__gc",              openssl_ts_verify_ctx_gc},

  { NULL, NULL }
};
#endif

static LuaL_Enumeration ots_const[] =
{
  {"STATUS_GRANTED",                 TS_STATUS_GRANTED},
  {"STATUS_GRANTED_WITH_MODS",       TS_STATUS_GRANTED_WITH_MODS},
  {"STATUS_REJECTION",               TS_STATUS_REJECTION},
  {"STATUS_WAITING",                 TS_STATUS_WAITING},
  {"STATUS_REVOCATION_WARNIN",       TS_STATUS_REVOCATION_WARNING},
  {"STATUS_REVOCATION_NOTIFICATION", TS_STATUS_REVOCATION_NOTIFICATION},

  {"INFO_BAD_ALG",               TS_INFO_BAD_ALG},
  {"INFO_BAD_REQUEST",           TS_INFO_BAD_REQUEST},
  {"INFO_BAD_DATA_FORMA",        TS_INFO_BAD_DATA_FORMAT},
  {"INFO_TIME_NOT_AVAILABL",     TS_INFO_TIME_NOT_AVAILABLE},
  {"INFO_UNACCEPTED_POLICY",     TS_INFO_UNACCEPTED_POLICY},
  {"INFO_UNACCEPTED_EXTENSION",  TS_INFO_UNACCEPTED_EXTENSION},
  {"INFO_ADD_INFO_NOT_AVAILABL", TS_INFO_ADD_INFO_NOT_AVAILABLE},
  {"INFO_SYSTEM_FAILUR",         TS_INFO_SYSTEM_FAILURE},

  {"VFY_SIGNATURE",   TS_VFY_SIGNATURE},
  {"VFY_VERSION",     TS_VFY_VERSION},
  {"VFY_POLICY",      TS_VFY_POLICY},
  {"VFY_IMPRINT",     TS_VFY_IMPRINT},
  {"VFY_DATA",        TS_VFY_DATA},
  {"VFY_NONCE",       TS_VFY_NONCE},
  {"VFY_SIGNER",      TS_VFY_SIGNER},
  {"VFY_TSA_NAME",    TS_VFY_TSA_NAME},
  {"VFY_ALL_IMPRINT", TS_VFY_ALL_IMPRINT},
  {"VFY_ALL_DATA",    TS_VFY_ALL_DATA},


  {NULL,           0}
};

int luaopen_ts(lua_State *L)
{
#if OPENSSL_VERSION_NUMBER >= 0x10000000L
  auxiliar_newclass(L, "openssl.ts_req",        ts_req_funs);
  auxiliar_newclass(L, "openssl.ts_resp",       ts_resp_funs);
  auxiliar_newclass(L, "openssl.ts_resp_ctx",   ts_resp_ctx_funs);
  auxiliar_newclass(L, "openssl.ts_verify_ctx", ts_verify_ctx_funs);
  auxiliar_newclass(L, "openssl.ts_tst_info",   ts_tst_info_funcs);
  auxiliar_newclass(L, "openssl.ts_accuracy",   ts_accuracy_funcs);
  auxiliar_newclass(L, "openssl.ts_msg_imprint",ts_msg_imprint_funcs);

  lua_newtable(L);
  luaL_setfuncs(L, R, 0);

  auxiliar_enumerate(L, -1, ots_const);
#else
  lua_pushnil(L);
#endif
  return 1;
}
