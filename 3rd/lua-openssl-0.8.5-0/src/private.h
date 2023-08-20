#ifndef OPENSSL_PRIVATE_H
#define OPENSSL_PRIVATE_H

#if defined(__cplusplus)
extern "C" {
#endif
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

#if LUA_VERSION_NUM < 503
#include "compat-5.3.h"
#endif

#if (OPENSSL_VERSION_NUMBER >= 0x30000000L)
#include "openssl/provider.h"
#endif

#define luaL_checktable(L, n) luaL_checktype(L, n, LUA_TTABLE)

#if LUA_VERSION_NUM >= 502
#ifndef lua_equal
#define lua_equal( L, a, b) lua_compare( L, a, b, LUA_OPEQ)
#endif
#ifndef lua_lessthan
#define lua_lessthan( L, a, b) lua_compare( L, a, b, LUA_OPLT)
#endif
#define luaG_registerlibfuncs( L, _funcs) luaL_setfuncs( L, _funcs, 0)
#endif

#if LUA_VERSION_NUM >= 503
#ifndef luaL_checkint
#define luaL_checkint(L,n) ((int)luaL_checkinteger(L, (n)))
#endif
#ifndef luaL_optint
#define luaL_optint(L,n,d) ((int)luaL_optinteger(L, (n), (d)))
#endif
#ifndef luaL_checklong
#define luaL_checklong(L,n) ((long)luaL_checkinteger(L, (n)))
#endif
#ifndef luaL_optlong
#define luaL_optlong(L,n,d) ((long)luaL_optinteger(L, (n), (d)))
#endif
#endif

#ifdef _WIN32
#define strcasecmp stricmp
#endif

#include "openssl.h"

#if OPENSSL_VERSION_NUMBER > 0x10100000L
#define CONSTIFY_OPENSSL const
#else
#define CONSTIFY_OPENSSL
#endif
#define CONSTIFY_X509_get0 CONSTIFY_OPENSSL

#define OPENSSLV_LESS(v) (OPENSSL_VERSION_NUMBER < v)

#define LIBRESSLV_LESS(v) \
  (defined(LIBRESSL_VERSION_NUMBER) && LIBRESSL_VERSION_NUMBER < v)

#define IS_LIBRESSL() (defined(LIBRESSL_VERSION_NUMBER))

#if OPENSSL_VERSION_NUMBER >= 0x1010100FL && !defined(OPENSSL_NO_EC) \
  && !defined(LIBRESSL_VERSION_NUMBER)
#define OPENSSL_SUPPORT_SM2
#endif

#define PUSH_BN(x)                                      \
  *(void **)(lua_newuserdata(L, sizeof(void *))) = (x); \
  luaL_getmetatable(L,"openssl.bn");                    \
  lua_setmetatable(L,-2)

#if OPENSSL_VERSION_NUMBER < 0x10101000L || defined(LIBRESSL_VERSION_NUMBER)
#define EC_POINT_set_affine_coordinates EC_POINT_set_affine_coordinates_GFp
#define EC_POINT_get_affine_coordinates EC_POINT_get_affine_coordinates_GFp
#define EC_GROUP_get_curve EC_GROUP_get_curve_GFp
#endif

#if OPENSSL_VERSION_NUMBER < 0x10100000L || defined(LIBRESSL_VERSION_NUMBER)
int BIO_up_ref(BIO *b);
int X509_up_ref(X509 *x);
int X509_STORE_up_ref(X509_STORE *s);
int EVP_PKEY_up_ref(EVP_PKEY *pkey);

#include <openssl/ssl.h>
int SSL_up_ref(SSL *s);
int SSL_CTX_up_ref(SSL_CTX *ctx);
int SSL_SESSION_up_ref(SSL_SESSION *s);

DH *EVP_PKEY_get0_DH(EVP_PKEY *pkey);
int DH_bits(const DH *dh);
void DH_get0_key(const DH *dh,
                 const BIGNUM **pub_key, const BIGNUM **priv_key);
int DH_set0_key(DH *dh, BIGNUM *pub_key, BIGNUM *priv_key);
void DH_get0_pqg(const DH *dh,
                 const BIGNUM **p, const BIGNUM **q, const BIGNUM **g);
int DH_set0_pqg(DH *dh, BIGNUM *p, BIGNUM *q, BIGNUM *g);
void DSA_get0_pqg(const DSA *dsa,
                  const BIGNUM **p, const BIGNUM **q, const BIGNUM **g);

EC_KEY *EVP_PKEY_get0_EC_KEY(EVP_PKEY *pkey);
void ECDSA_SIG_get0(const ECDSA_SIG *sig,
                    const BIGNUM **pr, const BIGNUM **ps);
int ECDSA_SIG_set0(ECDSA_SIG *sig, BIGNUM *r, BIGNUM *s);
int RSA_bits(const RSA *r);
void RSA_get0_key(const RSA *r,
                  const BIGNUM **n, const BIGNUM **e, const BIGNUM **d);
int RSA_set0_key(RSA *r, BIGNUM *n, BIGNUM *e, BIGNUM *d);
int RSA_set0_factors(RSA *r, BIGNUM *p, BIGNUM *q);
int RSA_set0_crt_params(RSA *r, BIGNUM *dmp1, BIGNUM *dmq1, BIGNUM *iqmp);
void RSA_get0_factors(const RSA *r, const BIGNUM **p, const BIGNUM **q);
void RSA_get0_crt_params(const RSA *r, const BIGNUM **dmp1, const BIGNUM **dmq1, const BIGNUM **iqmp);
RSA *EVP_PKEY_get0_RSA(EVP_PKEY *pkey);

DSA *EVP_PKEY_get0_DSA(EVP_PKEY *pkey);
int DSA_bits(const DSA *dsa);
void DSA_get0_key(const DSA *d,
                  const BIGNUM **pub_key, const BIGNUM **priv_key);
int DSA_set0_key(DSA *d, BIGNUM *pub_key, BIGNUM *priv_key);
void DSA_get0_pqg(const DSA *d,
                  const BIGNUM **p, const BIGNUM **q, const BIGNUM **g);
int DSA_set0_pqg(DSA *d, BIGNUM *p, BIGNUM *q, BIGNUM *g);

HMAC_CTX *HMAC_CTX_new(void);
void HMAC_CTX_free(HMAC_CTX *ctx);

int EVP_CIPHER_CTX_reset(EVP_CIPHER_CTX *ctx);

EVP_MD_CTX *EVP_MD_CTX_new(void);
int EVP_MD_CTX_reset(EVP_MD_CTX *ctx);
void EVP_MD_CTX_free(EVP_MD_CTX *ctx);
void X509_REQ_get0_signature(const X509_REQ *req, const ASN1_BIT_STRING **psig,
                             const X509_ALGOR **palg);
X509_PUBKEY *X509_REQ_get_X509_PUBKEY(X509_REQ *req);
int X509_PUBKEY_get0_param(ASN1_OBJECT **ppkalg,
                           const unsigned char **pk, int *ppklen,
                           X509_ALGOR **pa, X509_PUBKEY *pub);
const ASN1_INTEGER *X509_get0_serialNumber(const X509 *a);
const STACK_OF(X509_EXTENSION) *X509_get0_extensions(const X509 *x);
int i2d_re_X509_REQ_tbs(X509_REQ *req, unsigned char **pp);
const ASN1_INTEGER *X509_REVOKED_get0_serialNumber(const X509_REVOKED *x);
int X509_REVOKED_set_revocationDate(X509_REVOKED *x, ASN1_TIME *tm);
const ASN1_TIME *X509_REVOKED_get0_revocationDate(const X509_REVOKED *x);
const STACK_OF(X509_EXTENSION) *X509_REVOKED_get0_extensions(const X509_REVOKED *r);
const STACK_OF(X509_EXTENSION) *X509_CRL_get0_extensions(const X509_CRL *crl);

void X509_CRL_get0_signature(const X509_CRL *crl, const ASN1_BIT_STRING **psig,
                             const X509_ALGOR **palg);

const ASN1_INTEGER *TS_STATUS_INFO_get0_status(const TS_STATUS_INFO *a);
const STACK_OF(ASN1_UTF8STRING) *TS_STATUS_INFO_get0_text(const TS_STATUS_INFO *a);
const ASN1_BIT_STRING *TS_STATUS_INFO_get0_failure_info(const TS_STATUS_INFO *a);


int TS_VERIFY_CTX_add_flags(TS_VERIFY_CTX *ctx, int f);
int TS_VERIFY_CTX_set_flags(TS_VERIFY_CTX *ctx, int f);
BIO *TS_VERIFY_CTX_set_data(TS_VERIFY_CTX *ctx, BIO *b);
X509_STORE *TS_VERIFY_CTX_set_store(TS_VERIFY_CTX *ctx, X509_STORE *s);
STACK_OF(X509) *TS_VERIFY_CTS_set_certs(TS_VERIFY_CTX *ctx,
                                        STACK_OF(X509) *certs);
unsigned char *TS_VERIFY_CTX_set_imprint(TS_VERIFY_CTX *ctx,
    unsigned char *hexstr,
    long len);

#if defined(LIBRESSL_VERSION_NUMBER)
int i2d_re_X509_tbs(X509 *x, unsigned char **pp);
#endif

const unsigned char *ASN1_STRING_get0_data(const ASN1_STRING *x);
const ASN1_TIME *X509_CRL_get0_lastUpdate(const X509_CRL *crl);
const ASN1_TIME *X509_CRL_get0_nextUpdate(const X509_CRL *crl);

const OCSP_CERTID *OCSP_SINGLERESP_get0_id(const OCSP_SINGLERESP *x);

const ASN1_GENERALIZEDTIME *OCSP_resp_get0_produced_at(const OCSP_BASICRESP* bs);
const STACK_OF(X509) *OCSP_resp_get0_certs(const OCSP_BASICRESP *bs);
int OCSP_resp_get0_id(const OCSP_BASICRESP *bs,
                      const ASN1_OCTET_STRING **pid,
                      const X509_NAME **pname);

const ASN1_OCTET_STRING *OCSP_resp_get0_signature(const OCSP_BASICRESP *bs);
const X509_ALGOR *OCSP_resp_get0_tbs_sigalg(const OCSP_BASICRESP *bs);

#endif /* < 1.1.0 */

#define AUXILIAR_SETOBJECT(L, cval, ltype, idx, lvar) \
  do {                                                \
  int n = (idx < 0)?idx-1:idx;                        \
  PUSH_OBJECT(cval,ltype);                            \
  lua_setfield(L, n, lvar);                           \
  } while(0)


#define OPENSSL_PKEY_GET_BN(bn, _name)    \
  if (bn != NULL) {                       \
  BIGNUM* b = BN_dup(bn);                 \
  PUSH_OBJECT(b,"openssl.bn");            \
  lua_setfield(L,-2,#_name);              \
  }

#define OPENSSL_PKEY_SET_BN(n, _type, _name)  {             \
  lua_getfield(L,n,#_name);                                 \
  if(lua_isstring(L,-1)) {                                  \
  size_t l = 0;                                             \
  const char* bn = luaL_checklstring(L,-1,&l);              \
  if(_type->_name==NULL)  _type->_name = BN_new();          \
  BN_bin2bn((const unsigned char *)bn,l,_type->_name);      \
  }else if(auxiliar_getclassudata(L,"openssl.bn",-1)) {           \
  const BIGNUM* bn = CHECK_OBJECT(-1,BIGNUM,"openssl.bn");  \
  if(_type->_name==NULL)  _type->_name = BN_new();          \
  BN_copy(_type->_name, bn);                                \
  }else if(!lua_isnil(L,-1))                                \
  luaL_error(L,"arg #%d must have \"%s\" field string or openssl.bn",n,#_name);   \
  lua_pop(L,1);                                             \
}

size_t posrelat(ptrdiff_t pos, size_t len);
int hex2bin(const char * src, unsigned char *dst, int len);
int bin2hex(const unsigned char * src, char *dst, int len);

enum
{
  FORMAT_AUTO = 0,
  FORMAT_DER,
  FORMAT_PEM,
  FORMAT_SMIME,
  FORMAT_NUM
};

extern const char* format[];

BIO* load_bio_object(lua_State* L, int idx);
int  bio_is_der(BIO* bio);
const EVP_MD* opt_digest(lua_State* L, int idx, const char* def_alg);
const EVP_MD* get_digest(lua_State* L, int idx, const char* def_alg);
const EVP_CIPHER* opt_cipher(lua_State* L, int idx, const char* def_alg);
const EVP_CIPHER* get_cipher(lua_State* L, int idx, const char* def_alg);
BIGNUM *BN_get(lua_State *L, int i);
int openssl_engine(lua_State *L);
int openssl_pkey_is_private(EVP_PKEY* pkey);

void to_hex(const char* in, int length, char* out);

int openssl_push_asn1type(lua_State* L, const ASN1_TYPE* type);
int openssl_push_asn1object(lua_State* L, const ASN1_OBJECT* obj);
int openssl_push_asn1(lua_State* L, const ASN1_STRING* string, int type);
int openssl_push_general_name(lua_State*L, const GENERAL_NAME* name);
int openssl_push_asn1integer_as_bn(lua_State *L, const ASN1_INTEGER* ai);

int openssl_push_x509_signature(lua_State *L, const X509_ALGOR *alg, const ASN1_STRING *sig, int i);

#define PUSH_ASN1_TIME(L, tm)             openssl_push_asn1(L, (ASN1_STRING*)(tm), V_ASN1_UTCTIME)
#define PUSH_ASN1_INTEGER(L, i)           openssl_push_asn1(L, (ASN1_STRING*)(i),  V_ASN1_INTEGER)
#define PUSH_ASN1_OCTET_STRING(L, s)      openssl_push_asn1(L, (ASN1_STRING*)(s),  V_ASN1_OCTET_STRING)
#define PUSH_ASN1_STRING(L, s)            openssl_push_asn1(L, (ASN1_STRING*)(s),  V_ASN1_UNDEF)

int openssl_push_xname_asobject(lua_State*L, X509_NAME* xname);
int openssl_push_bit_string_bitname(lua_State* L, const BIT_STRING_BITNAME* name);

ASN1_OBJECT* openssl_get_asn1object(lua_State*L, int idx, int retnil);
EC_GROUP* openssl_get_ec_group(lua_State* L, int ec_name_idx, int param_enc_idx,
                               int conv_form_idx);
int openssl_get_padding(lua_State *L, int idx, const char *defval);

int openssl_register_xname(lua_State*L);
int openssl_register_xattribute(lua_State*L);
int openssl_register_xextension(lua_State*L);
int openssl_register_xstore(lua_State*L);
int openssl_register_xalgor(lua_State*L);

int openssl_pushresult(lua_State*L, int result);

int openssl_newvalue(lua_State*L, const void*p);
int openssl_freevalue(lua_State*L, const void*p);
int openssl_valueset(lua_State*L, const void*p, const char*field);
int openssl_valueget(lua_State*L, const void*p, const char*field);
int openssl_valueseti(lua_State*L, const void*p, int i);
int openssl_valuegeti(lua_State*L, const void*p, int i);
int openssl_valuesetp(lua_State*L, const void*p, const void*d);
int openssl_valuegetp(lua_State*L, const void*p, const void*d);

int openssl_verify_cb(int preverify_ok, X509_STORE_CTX *xctx);
int openssl_cert_verify_cb(X509_STORE_CTX *xctx, void* u);
void openssl_xstore_free(X509_STORE* ctx);

STACK_OF(X509)* openssl_sk_x509_fromtable(lua_State *L, int idx);
int openssl_sk_x509_totable(lua_State *L, const STACK_OF(X509)* sk);
STACK_OF(X509_CRL)* openssl_sk_x509_crl_fromtable(lua_State *L, int idx);
int openssl_sk_x509_crl_totable(lua_State *L, const STACK_OF(X509_CRL)* sk);
STACK_OF(X509_EXTENSION)* openssl_sk_x509_extension_fromtable(lua_State *L, int idx);
int openssl_sk_x509_extension_totable(lua_State *L, const STACK_OF(X509_EXTENSION)* sk);
int openssl_sk_x509_algor_totable(lua_State *L, const STACK_OF(X509_ALGOR)* sk);
int openssl_sk_x509_name_totable(lua_State *L, const STACK_OF(X509_NAME)* sk);
int openssl_sk_x509_attribute_totable(lua_State *L, const STACK_OF(X509_ATTRIBUTE)* sk);

X509_ATTRIBUTE* openssl_new_xattribute(lua_State*L, X509_ATTRIBUTE** a, int idx);

int openssl_pusherror (lua_State *L, const char *fmt, ...);
int openssl_pushargerror (lua_State *L, int arg, const char *extramsg);

#ifdef HAVE_USER_CUSTOME
#include HAVE_USER_CUSTOME
#endif

#if defined(OPENSSL_SUPPORT_SM2)
#ifndef SM2_DEFAULT_USERID
#  define SM2_DEFAULT_USERID "1234567812345678"
#endif
#endif

#if defined(__cplusplus)
}
#endif

#endif /* OPENSSL_PRIVATE_H */
