/***
x509.crl module to mapping `X509_CRL` to lua object, creates and  processes CRL file in DER or PEM format.

@module x509.crl
@usage
  crl = require'openssl'.x509.crl
*/
#include "openssl.h"
#include "private.h"
#define CRYPTO_LOCK_REF
#include "sk.h"
#include <openssl/x509v3.h>

#if OPENSSL_VERSION_NUMBER < 0x1010000fL || \
	(defined(LIBRESSL_VERSION_NUMBER) && (LIBRESSL_VERSION_NUMBER < 0x20700000L))
#define X509_CRL_set1_nextUpdate X509_CRL_set_nextUpdate
#define X509_CRL_set1_lastUpdate X509_CRL_set_lastUpdate
#endif

int   X509_CRL_cmp(const X509_CRL *a, const X509_CRL *b);
int   X509_CRL_match(const X509_CRL *a, const X509_CRL *b);

#ifndef CRL_REASON_NONE
#define CRL_REASON_NONE                         -1;
#define CRL_REASON_UNSPECIFIED                  0
#define CRL_REASON_KEY_COMPROMISE               1
#define CRL_REASON_CA_COMPROMISE                2
#define CRL_REASON_AFFILIATION_CHANGED          3
#define CRL_REASON_SUPERSEDED                   4
#define CRL_REASON_CESSATION_OF_OPERATION       5
#define CRL_REASON_CERTIFICATE_HOLD             6
#define CRL_REASON_REMOVE_FROM_CRL              8
#define CRL_REASON_PRIVILEGE_WITHDRAWN          9
#define CRL_REASON_AA_COMPROMISE                10
#endif

static const BIT_STRING_BITNAME reason_flags[] =
{
  { CRL_REASON_UNSPECIFIED, "Unspecified", "unspecified"},
  { CRL_REASON_KEY_COMPROMISE,      "Key Compromise", "keyCompromise" },
  { CRL_REASON_CA_COMPROMISE,       "CA Compromise", "CACompromise" },
  { CRL_REASON_AFFILIATION_CHANGED, "Affiliation Changed", "affiliationChanged" },
  { CRL_REASON_SUPERSEDED,          "Superseded", "superseded" },
  { CRL_REASON_CESSATION_OF_OPERATION, "Cessation Of Operation", "cessationOfOperation" },
  { CRL_REASON_CERTIFICATE_HOLD,    "Certificate Hold", "certificateHold" },
  { CRL_REASON_REMOVE_FROM_CRL,     "Remove From CRL", "removeFromCRL" },
  { CRL_REASON_PRIVILEGE_WITHDRAWN, "Privilege Withdrawn", "privilegeWithdrawn" },
  { CRL_REASON_AA_COMPROMISE,       "AA Compromise", "AACompromise" },
  { -1, NULL, NULL }
};

static const int reason_num = sizeof(reason_flags) / sizeof(BIT_STRING_BITNAME) - 1;

const char* openssl_i2s_revoke_reason(int reason)
{
  int i;
  for (i = 0; i < reason_num && i != reason; i++);
  if (i == reason_num)
    return "unset";
  else
    return reason_flags[i].sname;
}
int openssl_s2i_revoke_reason(const char*s)
{
  int reason = -1;
  int i;
  for (i = 0; i < reason_num; i++)
  {
    if (strcasecmp(s, reason_flags[i].lname) == 0 || strcasecmp(s, reason_flags[i].sname) == 0)
    {
      reason = reason_flags[i].bitnum;
      break;
    }
  }
  return reason;
}

static int reason_get(lua_State*L, int reasonidx)
{
  int reason = 0;

  if (lua_isnumber(L, reasonidx))
  {
    reason = lua_tointeger(L, reasonidx);
  }
  else if (lua_isstring(L, reasonidx))
  {
    const char* s = lua_tostring(L, reasonidx);
    reason = openssl_s2i_revoke_reason(s);
  }
  else if (lua_isnoneornil(L, reasonidx))
    reason = 0;
  else
    luaL_argerror(L, reasonidx, "invalid revoke reason");

  luaL_argcheck(L, reason >= 0 && reason < reason_num, reasonidx, "fail convert to revoke reason");

  return reason;
}

static int openssl_x509_revoked_get_reason(X509_REVOKED *revoked)
{
  int crit = 0;
  int reason = 0;
  ASN1_ENUMERATED *areason = X509_REVOKED_get_ext_d2i(revoked, NID_crl_reason, &crit, NULL);
  //reason = (crit == -1) ? CRL_REASON_NONE : ASN1_ENUMERATED_get(areason);
  ASN1_ENUMERATED_free(areason);
  return reason;
}

static X509_REVOKED *create_revoked(const BIGNUM* bn, time_t t, int reason)
{
  X509_REVOKED *revoked = X509_REVOKED_new();
  ASN1_TIME *tm = ASN1_TIME_new();
  ASN1_INTEGER *it =  BN_to_ASN1_INTEGER(bn, NULL);

  ASN1_TIME_set(tm, t);

  X509_REVOKED_set_revocationDate(revoked, tm);
  X509_REVOKED_set_serialNumber(revoked, it);

  {
    ASN1_ENUMERATED * e = ASN1_ENUMERATED_new();
    X509_EXTENSION * ext = X509_EXTENSION_new();

    ASN1_ENUMERATED_set(e, reason);

    X509_EXTENSION_set_data(ext, e);
    X509_EXTENSION_set_object(ext, OBJ_nid2obj(NID_crl_reason));
    X509_REVOKED_add_ext(revoked, ext, 0);

    X509_EXTENSION_free(ext);
    ASN1_ENUMERATED_free(e);
  }

  ASN1_TIME_free(tm);
  ASN1_INTEGER_free(it);

  return revoked;
}

static int openssl_revoked2table(lua_State*L, X509_REVOKED *revoked)
{
  int reason = openssl_x509_revoked_get_reason(revoked);
  lua_newtable(L);
  AUXILIAR_SET(L, -1, "code", reason, number);
  AUXILIAR_SET(L, -1, "reason", openssl_i2s_revoke_reason(reason), string);

  PUSH_ASN1_INTEGER(L, X509_REVOKED_get0_serialNumber(revoked));
  lua_setfield(L, -2, "serialNumber");

  PUSH_ASN1_TIME(L, X509_REVOKED_get0_revocationDate(revoked));
  lua_setfield(L, -2, "revocationDate");

  lua_pushstring(L, "extensions");
  openssl_sk_x509_extension_totable(L, X509_REVOKED_get0_extensions(revoked));
  lua_rawset(L, -3);
  return 1;
}

/***
create or generate a new x509_crl object.
Note if not give evp_pkey, will create a new x509_crl object,if give will generate a signed x509_crl object.
@function new
@tparam[opt] table revoked_list
@tparam[opt] x509 cacert ca cert to sign x509_crl
@tparam[opt] evp_pkey capkey private key to sign x509_crl
@tparam[opt] string|evp_md md_alg
@tparam[opt=7*24*3600] number period to generate new crl
@treturn x509_crl object
@see x509_crl
*/
static LUA_FUNCTION(openssl_crl_new)
{
  int i;
  int n = lua_gettop(L);
  X509_CRL * crl = X509_CRL_new();
  int ret = X509_CRL_set_version(crl, 0);
  X509* cacert = NULL;
  EVP_PKEY* capkey = NULL;
  const EVP_MD* md = NULL;
  int step;

  for (i = 1; ret == 1 && i <= n; i++)
  {
    if (i == 1)
    {
      luaL_argcheck(L, lua_istable(L, 1), 1, "must be table contains rovked entry table{reason,time,sn}");
      if (lua_rawlen(L, i) > 0)
      {
        int j, m;
        m = lua_rawlen(L, i);

        for (j = 1; ret == 1 && j <= m; j++)
        {
          X509_REVOKED *revoked;
          BIGNUM* sn;
          lua_rawgeti(L, i, j);
          luaL_checktable(L, -1);

          lua_getfield(L, -1, "reason");
          lua_getfield(L, -2, "time");
          lua_getfield(L, -3, "sn");
          sn = BN_get(L, -1);
          revoked = create_revoked(sn, lua_tointeger(L, -2), reason_get(L, -3));
          if (revoked)
          {
            ret = X509_CRL_add0_revoked(crl, revoked);
          }
          BN_free(sn);
          lua_pop(L, 3);
          lua_pop(L, 1);
        };
      }
    };
    if (i == 2)
    {
      cacert = CHECK_OBJECT(2, X509, "openssl.x509");
      ret = X509_CRL_set_issuer_name(crl, X509_get_issuer_name(cacert));
    }
    if (i == 3)
    {
      capkey = CHECK_OBJECT(3, EVP_PKEY, "openssl.evp_pkey");
      luaL_argcheck(L, openssl_pkey_is_private(capkey), 3, "must be private key");
      luaL_argcheck(L, X509_check_private_key(cacert, capkey) == 1, 3, "evp_pkey not match with x509 in #2");
    }
  }
  md = get_digest(L, 4, "sha256");
  step = lua_isnone(L, 5) ? 7 * 24 * 3600 : luaL_checkint(L, 5);

  if (ret == 1)
  {
    time_t lastUpdate;
    time_t nextUpdate;
    ASN1_TIME *ltm, *ntm;

    time(&lastUpdate);
    nextUpdate = lastUpdate + step;

    ltm = ASN1_TIME_new();
    ntm = ASN1_TIME_new();
    ASN1_TIME_set(ltm, lastUpdate);
    ASN1_TIME_set(ntm, nextUpdate);
    ret = X509_CRL_set1_lastUpdate(crl, ltm);
    if (ret == 1)
      ret = X509_CRL_set1_nextUpdate(crl, ntm);
    ASN1_TIME_free(ltm);
    ASN1_TIME_free(ntm);
  }
  if (cacert && capkey && md)
  {
    ret = (X509_CRL_sign(crl, capkey, md) == EVP_PKEY_size(capkey));
  }
  if (ret == 1)
  {
    PUSH_OBJECT(crl, "openssl.x509_crl");
  }
  else
  {
    X509_CRL_free(crl);
    return openssl_pushresult(L, ret);
  };

  return 1;
}

/***
read x509_crl from string or bio input
@function read
@tparam bio|string input input data
@tparam[opt='auto'] string format support 'auto','pem','der'
@treturn x509_crl certificate sign request object
@see x509_crl
*/
static LUA_FUNCTION(openssl_crl_read)
{
  int ret = 0;
  BIO * in = load_bio_object(L, 1);
  int fmt = luaL_checkoption(L, 2, "auto", format);
  X509_CRL *crl = NULL;

  if (fmt == FORMAT_AUTO)
  {
    fmt = bio_is_der(in) ? FORMAT_DER : FORMAT_PEM;
  }

  if (fmt == FORMAT_PEM)
  {
    crl = PEM_read_bio_X509_CRL(in, NULL, NULL, NULL);
    (void)BIO_reset(in);
  }
  else if (fmt == FORMAT_DER)
  {
    crl = d2i_X509_CRL_bio(in, NULL);
    (void)BIO_reset(in);
  }
  BIO_free(in);
  if (crl)
  {
    PUSH_OBJECT(crl, "openssl.x509_crl");
    ret = 1;
  }
  return ret;
}

/***
list all support reason info
@function reason
@treturn table contain support reason node like {lname=...,sname=...,bitnum=...}
*/
static int openssl_crl_reason(lua_State *L)
{
  int i;
  const BIT_STRING_BITNAME* bitname;
  lua_newtable(L);
  for (i = 0, bitname = &reason_flags[i]; bitname->bitnum != -1; i++, bitname = &reason_flags[i])
  {
    openssl_push_bit_string_bitname(L, bitname);
    lua_rawseti(L, -2, i + 1);
  }
  return 1;
}

static luaL_Reg R[] =
{
  {"new",       openssl_crl_new },
  {"read",      openssl_crl_read},
  {"reason",    openssl_crl_reason},

  {NULL,    NULL}
};

/***
openssl.x509_crl object
@type x509_crl
*/

/***
set version key
@function version
@tparam integer version
@treturn boolean result
*/
static LUA_FUNCTION(openssl_crl_version)
{
  X509_CRL *crl = CHECK_OBJECT(1, X509_CRL, "openssl.x509_crl");
  if (lua_isnone(L, 2))
  {
    lua_pushinteger(L, X509_CRL_get_version(crl));
    return 1;
  }
  else
  {
    long version = luaL_optinteger(L, 2, 0);
    int ret = X509_CRL_set_version(crl, version);
    return openssl_pushresult(L, ret);
  }
}

/***
add revoked entry to x509_crl object
@function add
@tparam string|number|bn serial
@tparam number revokedtime
@tparam[opt=0] number|string reason
@treturn boolean result true for add success
*/
static LUA_FUNCTION(openssl_crl_add_revocked)
{
  X509_CRL *crl = CHECK_OBJECT(1, X509_CRL, "openssl.x509_crl");
  BIGNUM* sn = BN_get(L, 2);
  time_t t = lua_tointeger(L, 3);
  int reason = reason_get(L, 4);

  int ret = 0;
  X509_REVOKED* revoked = create_revoked(sn, t, reason);
  ret = X509_CRL_add0_revoked(crl, revoked);
  lua_pushboolean(L, ret);
  BN_free(sn);
  return 1;
}

/***
get extensions of x509_crl
@function extensions
@treturn stack_of_x509_extension extensions
*/
/***
set extensions to x509_crl object
@function extensions
@tparam stack_of_x509_extension extensions add to x509_crl
@treturn boolean result
*/
static int openssl_crl_extensions(lua_State* L)
{
  X509_CRL *crl = CHECK_OBJECT(1, X509_CRL, "openssl.x509_crl");
  if (lua_isnone(L, 2))
  {
    const STACK_OF(X509_EXTENSION) *exts = X509_CRL_get0_extensions(crl);
    if (exts)
    {
      openssl_sk_x509_extension_totable(L, exts);
    }
    else
      lua_pushnil(L);
    return 1;
  }
  else
  {
    STACK_OF(X509_EXTENSION) *exts = (STACK_OF(X509_EXTENSION) *)openssl_sk_x509_extension_fromtable(L, 2);
    int i, n;
    n = sk_X509_EXTENSION_num(exts);
    for (i = 0; i < n; i++)
    {
      X509_EXTENSION *ext = sk_X509_EXTENSION_value(exts, i);
      X509_CRL_add_ext(crl, ext, i);
    };
    sk_X509_EXTENSION_pop_free(exts, X509_EXTENSION_free);
    return openssl_pushresult(L, 1);
  }
}

/***
get issuer x509_name object
@function issuer
@treturn x509_name
*/
/***
set issuer x509_name object
@function issuer
@tparam x509_name|x509 issuer
@treturn boolean result
*/
static LUA_FUNCTION(openssl_crl_issuer)
{
  int ret = 0;
  X509_CRL *crl = CHECK_OBJECT(1, X509_CRL, "openssl.x509_crl");
  X509_NAME* xn = NULL;
  X509* x = NULL;

  if (lua_isnone(L, 2))
  {
    ret = openssl_push_xname_asobject(L, X509_CRL_get_issuer(crl));
  }
  else
  {
    xn = GET_OBJECT(2, X509_NAME, "openssl.x509_name");
    x = GET_OBJECT(2, X509, "openssl.x509");

    luaL_argcheck(L, xn || x , 2,
                  "only accept openssl.x509 or openssl.x509_name object");
    if (xn)
    {
      ret = X509_CRL_set_issuer_name(crl, xn);
    }
    else if (x)
    {
      ret = X509_CRL_set_issuer_name(crl, X509_get_issuer_name(x));
    }
    ret = openssl_pushresult(L, ret);
  }
  return ret;
}

/***
get lastUpdate time
@function lastUpdate
@treturn string lastUpdate
*/
/***
set lastUpdate time
@function lastUpdate
@tparam number lastUpdate
@treturn boolean result
*/
static LUA_FUNCTION(openssl_crl_lastUpdate)
{
  X509_CRL *crl = CHECK_OBJECT(1, X509_CRL, "openssl.x509_crl");
  if (lua_isnone(L, 2))
  {
    ASN1_TIME const *tm = X509_CRL_get0_lastUpdate(crl);
    PUSH_ASN1_TIME(L, tm);
    return 1;
  }
  else
  {
    int ret;
    time_t time = luaL_checkint(L, 2);
    ASN1_TIME *tm = ASN1_TIME_new();
    ASN1_TIME_set(tm, time);

    ret = X509_CRL_set1_lastUpdate(crl, tm);
    ASN1_TIME_free(tm);
    return openssl_pushresult(L, ret);
  }
}

/***
get nextUpdate time
@function nextUpdate
@treturn string nextUpdate
*/
/***
set nextUpdate time
@function nextUpdate
@tparam number nextUpdate
@treturn boolean result
*/
static LUA_FUNCTION(openssl_crl_nextUpdate)
{
  X509_CRL *crl = CHECK_OBJECT(1, X509_CRL, "openssl.x509_crl");
  if (lua_isnone(L, 2))
  {
    ASN1_TIME const *tm = X509_CRL_get0_nextUpdate(crl);
    PUSH_ASN1_TIME(L, tm);
    return 1;
  }
  else
  {
    int ret;
    time_t time = luaL_checkint(L, 2);
    ASN1_TIME *tm = ASN1_TIME_new();
    ASN1_TIME_set(tm, time);

    ret = X509_CRL_set1_nextUpdate(crl, tm);
    ASN1_TIME_free(tm);
    return openssl_pushresult(L, ret);
  }
}

/***
get updateTime time
@function updateTime
@treturn asn1_time lastUpdate
@treturn asn1_time nextUpdate
*/
/***
set updateTime time
@function updateTime
@tparam[opt=os.time()] lastUpdate, default use current time
@tparam number period period how long time(seconds)
@treturn boolean result
*/
static LUA_FUNCTION(openssl_crl_updateTime)
{
  X509_CRL *crl = CHECK_OBJECT(1, X509_CRL, "openssl.x509_crl");
  if (lua_isnone(L, 2))
  {
    ASN1_TIME const *ltm, *ntm;
    ltm = X509_CRL_get0_lastUpdate(crl);
    ntm = X509_CRL_get0_nextUpdate(crl);
    PUSH_ASN1_TIME(L, ltm);
    PUSH_ASN1_TIME(L, ntm);
    return 2;
  }
  else
  {
    ASN1_TIME *ltm, *ntm;
    int ret = 0;

    time_t last, next;

    if (lua_gettop(L) == 2)
    {
      time(&last);
      next = last + luaL_checkint(L, 2);
    }
    else
    {
      last = luaL_checkint(L, 2);
      next = luaL_checkint(L, 3);
      next = last + next;
    }

    ltm = ASN1_TIME_new();
    ASN1_TIME_set(ltm, last);
    ntm = ASN1_TIME_new();
    ASN1_TIME_set(ntm, next);
    ret = X509_CRL_set1_lastUpdate(crl, ltm);
    if (ret == 1)
      ret = X509_CRL_set1_nextUpdate(crl, ntm);
    ASN1_TIME_free(ltm);
    ASN1_TIME_free(ntm);
    openssl_pushresult(L, ret);
    return 1;
  }
}

/***
sore crl entry in x509_crl object
@function sort
@treturn boolean result true for success and others for fail
*/
static LUA_FUNCTION(openssl_crl_sort)
{
  X509_CRL *crl = CHECK_OBJECT(1, X509_CRL, "openssl.x509_crl");
  int ret = X509_CRL_sort(crl);
  return openssl_pushresult(L, ret);
}

/***
verify x509_crl object signature
@function verify
@tparam x509|evp_pkey key ca cert or public to verify signature
@treturn boolean result true for success and others for fail
*/
static LUA_FUNCTION(openssl_crl_verify)
{
  X509_CRL *crl = CHECK_OBJECT(1, X509_CRL, "openssl.x509_crl");
  EVP_PKEY *pub = NULL;
  int ret;
  luaL_argcheck(L,
                auxiliar_getclassudata(L, "openssl.x509", 2) ||
                auxiliar_getclassudata(L, "openssl.evp_pkey", 2),
                2,
                "must be x509 or evp_pkey object");
  if (auxiliar_getclassudata(L, "openssl.evp_pkey", 2))
  {
    pub = CHECK_OBJECT(2, EVP_PKEY, "openssl.evp_pkey");
    ret = X509_CRL_verify(crl, pub);
  }
  else
  {
    X509* cacert = CHECK_OBJECT(2, X509, "openssl.x509");
    pub = X509_get_pubkey(cacert);
    ret = X509_CRL_verify(crl, pub);
    EVP_PKEY_free(pub);
  }

  return openssl_pushresult(L, ret);
}

/***
sign x509_crl
@function sign
@tparam evp_pkey pkey private key to sign x509
@tparam x509|x509_name cacert or cacert x509_name
@tparam[opt='sha256WithRSAEncryption'] string|md_digest md_alg
@treturn boolean result true for check pass
*/
LUA_FUNCTION(openssl_crl_sign)
{
  X509_CRL *crl = CHECK_OBJECT(1, X509_CRL, "openssl.x509_crl");
  EVP_PKEY *key = CHECK_OBJECT(2, EVP_PKEY, "openssl.evp_pkey");
  const EVP_MD *md = get_digest(L, 4, "sha256");
  int ret = 1;

  luaL_argcheck(L,
                auxiliar_getclassudata(L, "openssl.x509", 3)
                || auxiliar_getclassudata(L, "openssl.x509_name", 3),
                3,
                "must be openssl.x509 or openssl.x509_name object");

  if (auxiliar_getclassudata(L, "openssl.x509_name", 3))
  {
    X509_NAME* xn = CHECK_OBJECT(3, X509_NAME, "openssl.x509_name");
    ret = X509_CRL_set_issuer_name(crl, xn);
  }
  else if (auxiliar_getclassudata(L, "openssl.x509", 3))
  {
    X509* ca = CHECK_OBJECT(3, X509, "openssl.x509");
    ret = X509_CRL_set_issuer_name(crl, X509_get_issuer_name(ca));
    if (ret == 1)
    {
      ret = X509_check_private_key(ca, key);
      if (ret != 1)
      {
        lua_pushnil(L);
        lua_pushstring(L, "private key not match with cacert");
        return 2;
      }
    }
  }
  if (ret == 1)
  {
    ret = X509_CRL_sort(crl);
    if (ret == 1)
      ret = X509_CRL_sign(crl, key, md);
  }
  return openssl_pushresult(L, ret);
}

/***
get digest of x509_crl
@function digest
@tparam[opt='sha256'] evp_md|string md_alg default use sha256
@treturn string digest result
*/
static LUA_FUNCTION(openssl_crl_digest)
{
  X509_CRL *crl = CHECK_OBJECT(1, X509_CRL, "openssl.x509_crl");
  byte buf[EVP_MAX_MD_SIZE];
  unsigned int lbuf = sizeof(buf);
  const EVP_MD *md = get_digest(L, 2, "sha256");

  int ret =  X509_CRL_digest(crl, md, buf, &lbuf);
  if (ret == 1)
  {
    lua_pushlstring(L, (const char*)buf, (size_t)lbuf);
  }
  return ret==1 ? 1 : openssl_pushresult(L, ret);
}

/***
compare with other x509_crl object
@function cmp
@tparam x509_crl other
@treturn boolean result true for equals or false
@usage
  x:cmp(y) == (x==y)
*/
static LUA_FUNCTION(openssl_crl_cmp)
{
  X509_CRL *crl = CHECK_OBJECT(1, X509_CRL, "openssl.x509_crl");
  X509_CRL *oth = CHECK_OBJECT(2, X509_CRL, "openssl.x509_crl");
  int ret = X509_CRL_cmp(crl, oth);
  lua_pushboolean(L, ret == 0);
  return 1;
}

#if OPENSSL_VERSION_NUMBER >= 0x10100000L && !defined (LIBRESSL_VERSION_NUMBER)
/***
make a delta x509_crl object
@function diff
@tparam x509_crl newer
@tparam evp_pkey pkey
@tparam[opt='sha256'] evp_md|string md_alg
@tparam[opt=0] integer flags
@treturn x509_crl delta result x509_crl object
*/
static LUA_FUNCTION(openssl_crl_diff)
{
  X509_CRL *crl = CHECK_OBJECT(1, X509_CRL, "openssl.x509_crl");
  X509_CRL *newer = CHECK_OBJECT(2, X509_CRL, "openssl.x509_crl");
  EVP_PKEY* pkey = CHECK_OBJECT(3, EVP_PKEY, "openssl.evp_pkey");
  const EVP_MD *md = get_digest(L, 4, "sha256");
  unsigned int flags = luaL_optinteger(L, 5, 0);
  X509_CRL *diff;

  diff  =  X509_CRL_diff(crl, newer, pkey, md, flags);
  if (diff)
  {
    PUSH_OBJECT(diff, "openssl.x509_crl");
  }
  else
    lua_pushnil(L);
  return 1;
}
#endif

/***
parse x509_crl object as table
@function parse
@tparam[opt=true] shortname default will use short object name
@treturn table result
*/
static LUA_FUNCTION(openssl_crl_parse)
{
  X509_CRL *crl = CHECK_OBJECT(1, X509_CRL, "openssl.x509_crl");
  int num, i;
  const X509_ALGOR *alg;

  lua_newtable(L);
  AUXILIAR_SET(L, -1, "version", X509_CRL_get_version(crl), integer);

  /* hash as used in CA directories to lookup cert by subject name */
  {
    char buf[32];
#if OPENSSL_VERSION_NUMBER > 0x30000000
    snprintf(buf, sizeof(buf), "%08lx",
             X509_NAME_hash_ex(X509_CRL_get_issuer(crl), NULL, NULL, NULL));
#else
    snprintf(buf, sizeof(buf), "%08lx",
             X509_NAME_hash(X509_CRL_get_issuer(crl)));
#endif
    AUXILIAR_SET(L, -1, "hash", buf, string);
  }

  {
    const EVP_MD *digest = EVP_get_digestbyname("sha256");
    unsigned char md[EVP_MAX_MD_SIZE];
    unsigned int l = sizeof(md);

    if (X509_CRL_digest(crl, digest, md, &l) == 1)
    {
      lua_newtable(L);
      AUXILIAR_SET(L, -1, "alg", OBJ_nid2sn(EVP_MD_type(digest)), string);
      AUXILIAR_SETLSTR(L, -1, "hash", (const char*)md, l);

      lua_setfield(L, -2, "fingerprint");
    }
  }

  openssl_push_xname_asobject(L, X509_CRL_get_issuer(crl));
  lua_setfield(L, -2, "issuer");

  PUSH_ASN1_TIME(L, X509_CRL_get0_lastUpdate(crl));
  lua_setfield(L, -2, "lastUpdate");
  PUSH_ASN1_TIME(L, X509_CRL_get0_nextUpdate(crl));
  lua_setfield(L, -2, "nextUpdate");

  {
    const ASN1_BIT_STRING *sig = NULL;
    const X509_ALGOR *sig_alg = NULL;

    X509_CRL_get0_signature(crl, &sig, &alg);
    if (alg != NULL && OBJ_obj2nid(alg->algorithm)!=NID_undef)
    {
      PUSH_OBJECT(sig_alg, "openssl.x509_algor");
      lua_setfield(L, -2, "sig_alg");
    }

    if (sig != NULL && sig->length > 0)
    {
      PUSH_ASN1_STRING(L, sig);
      lua_setfield(L, -2, "signature");
    }
  }
  {
    ASN1_INTEGER *crl_number = X509_CRL_get_ext_d2i(crl, NID_crl_number, NULL, NULL);
    if (crl_number)
    {
      PUSH_ASN1_INTEGER(L, crl_number);
      lua_setfield(L, -2, "crl_number");
    }
  }
  {
    const STACK_OF(X509_EXTENSION) *extensions = X509_CRL_get0_extensions(crl);
    if (extensions)
    {
      openssl_sk_x509_extension_totable(L, extensions);
      lua_setfield(L, -2, "extensions");
    }
  }

  {
    STACK_OF(X509_REVOKED) *revokeds = X509_CRL_get_REVOKED(crl);
    if (revokeds)
    {
      num = sk_X509_REVOKED_num(revokeds);
      lua_newtable(L);
      for (i = 0; i < num; i++)
      {
        X509_REVOKED *revoked = sk_X509_REVOKED_value(revokeds, i);
        openssl_revoked2table(L, revoked);
        lua_rawseti(L, -2, i + 1);
      }

      lua_setfield(L, -2, "revoked");
    }
  }

  return 1;
}

static LUA_FUNCTION(openssl_crl_free)
{
  X509_CRL *crl = CHECK_OBJECT(1, X509_CRL, "openssl.x509_crl");
  X509_CRL_free(crl);
  return 0;
}

/***
export x509_crl to string
@function export
@tparam[opt='pem'] string format
@treturn string
*/
static LUA_FUNCTION(openssl_crl_export)
{
  X509_CRL * crl = CHECK_OBJECT(1, X509_CRL, "openssl.x509_crl");
  int fmt = luaL_checkoption(L, 2, "pem", format);
  BIO *out  = NULL;
  int ret = 0;

  luaL_argcheck(L, fmt == FORMAT_DER || fmt == FORMAT_PEM, 2,
                "only accept der or pem");

  out  = BIO_new(BIO_s_mem());
  if (fmt == FORMAT_PEM)
  {
    if (PEM_write_bio_X509_CRL(out, crl))
    {
      BUF_MEM *bio_buf;
      BIO_get_mem_ptr(out, &bio_buf);
      lua_pushlstring(L, bio_buf->data, bio_buf->length);
      ret = 1;
    }
  }
  else
  {
    if (i2d_X509_CRL_bio(out, crl))
    {
      BUF_MEM *bio_buf;
      BIO_get_mem_ptr(out, &bio_buf);
      lua_pushlstring(L, bio_buf->data, bio_buf->length);
      ret = 1;
    }
  }

  BIO_free(out);
  return ret;
}

/***
get count of revoked entry
@function count
@treturn number count
@usage
  assert(#crl==crl:count())
*/
static LUA_FUNCTION(openssl_crl_count)
{
  X509_CRL * crl = CHECK_OBJECT(1, X509_CRL, "openssl.x509_crl");
  STACK_OF(X509_REVOKED) *revokeds = X509_CRL_get_REVOKED(crl);
  int n = revokeds ? sk_X509_REVOKED_num(revokeds) : 0;
  lua_pushinteger(L, n);
  return 1;
}

/***
get revoekd entry
@function get
@tparam number index
@treturn table revoekd
*/
static LUA_FUNCTION(openssl_crl_get)
{
  X509_CRL * crl = CHECK_OBJECT(1, X509_CRL, "openssl.x509_crl");
  STACK_OF(X509_REVOKED) *revokeds = X509_CRL_get_REVOKED(crl);
  X509_REVOKED *revoked = NULL;
  int i, ret=0;

  if (lua_isinteger(L, 2))
  {
    i = lua_tointeger(L, 2);
    luaL_argcheck(L, (i >= 0 && i < sk_X509_REVOKED_num(revokeds)), 2, "Out of range");
    revoked = sk_X509_REVOKED_value(revokeds, i);
  }
  else
  {
    ASN1_STRING *sn = CHECK_OBJECT(2, ASN1_STRING, "openssl.asn1_integer");
    int cnt = sk_X509_REVOKED_num(revokeds);
    for (i = 0; i < cnt; i++)
    {
      X509_REVOKED *rev = sk_X509_REVOKED_value(revokeds, i);
      if (ASN1_STRING_cmp(X509_REVOKED_get0_serialNumber(rev), sn) == 0)
      {
        revoked = rev;
        break;
      }
    }
  }

  if (revoked)
  {
    int parse = lua_isnone(L, 3) ?  0 : lua_toboolean(L, 3);
    if (parse) {
      openssl_revoked2table(L, revoked);
    }
    else
    {
      revoked = X509_REVOKED_dup(revoked);
      PUSH_OBJECT(revoked, "openssl.x509_revoked");
    }
    ret = 1;
  }

  return ret;
}

static luaL_Reg crl_funcs[] =
{
  {"sort",            openssl_crl_sort},
  {"verify",          openssl_crl_verify},
  {"sign",            openssl_crl_sign},
  {"digest",          openssl_crl_digest},

#if OPENSSL_VERSION_NUMBER >= 0x10100000L && !defined (LIBRESSL_VERSION_NUMBER)
  {"diff",            openssl_crl_diff},
#endif

  /* set and get */
  {"version",         openssl_crl_version},
  {"issuer",          openssl_crl_issuer},
  {"lastUpdate",      openssl_crl_lastUpdate},
  {"nextUpdate",      openssl_crl_nextUpdate},
  {"updateTime",      openssl_crl_updateTime},
  {"extensions",      openssl_crl_extensions},

  {"add",             openssl_crl_add_revocked},

  {"parse",           openssl_crl_parse},
  {"export",          openssl_crl_export},

  {"cmp",             openssl_crl_cmp},
  {"count",           openssl_crl_count},
  {"get",             openssl_crl_get},
  {"__len",           openssl_crl_count},
  {"__eq",            openssl_crl_cmp},

  {"__tostring",      auxiliar_tostring},
  {"__gc",            openssl_crl_free  },

  {NULL,  NULL}
};

static int openssl_revoked_info(lua_State* L)
{
  X509_REVOKED* revoked = CHECK_OBJECT(1, X509_REVOKED, "openssl.x509_revoked");
  return openssl_revoked2table(L, revoked);
};

static int openssl_revoked_reason(lua_State* L)
{
  X509_REVOKED* revoked = CHECK_OBJECT(1, X509_REVOKED, "openssl.x509_revoked");
  if (lua_isnone(L, 2))
  {
    int reason = openssl_x509_revoked_get_reason(revoked);
    lua_pushinteger(L, reason);
    lua_pushstring(L, openssl_i2s_revoke_reason(reason));
    return 2;
  }
  else
  {
    int reason = reason_get(L, 2);
    ASN1_ENUMERATED * e = ASN1_ENUMERATED_new();
    X509_EXTENSION * ext = X509_EXTENSION_new();

    ASN1_ENUMERATED_set(e, reason);

    X509_EXTENSION_set_data(ext, e);
    X509_EXTENSION_set_object(ext, OBJ_nid2obj(NID_crl_reason));
    X509_REVOKED_add_ext(revoked, ext, 0);

    X509_EXTENSION_free(ext);
    ASN1_ENUMERATED_free(e);
  }
  return 0;
}

static time_t ASN1_GetTimeT(const ASN1_TIME* time)
{
  struct tm t;
  const char* str = (const char*) time->data;
  size_t i = 0;

  memset(&t, 0, sizeof(t));

  if (time->type == V_ASN1_UTCTIME)  /* two digit year */
  {
    t.tm_year = (str[i++] - '0') * 10;
    t.tm_year += (str[i++] - '0');
    if (t.tm_year < 70)
      t.tm_year += 100;
  }
  else if (time->type == V_ASN1_GENERALIZEDTIME)    /* four digit year */
  {
    t.tm_year = (str[i++] - '0') * 1000;
    t.tm_year += (str[i++] - '0') * 100;
    t.tm_year += (str[i++] - '0') * 10;
    t.tm_year += (str[i++] - '0');
    t.tm_year -= 1900;
  }
  t.tm_mon = (str[i++] - '0') * 10;
  t.tm_mon += (str[i++] - '0') - 1; // -1 since January is 0 not 1.
  t.tm_mday = (str[i++] - '0') * 10;
  t.tm_mday += (str[i++] - '0');
  t.tm_hour = (str[i++] - '0') * 10;
  t.tm_hour += (str[i++] - '0');
  t.tm_min = (str[i++] - '0') * 10;
  t.tm_min += (str[i++] - '0');
  t.tm_sec  = (str[i++] - '0') * 10;
  t.tm_sec += (str[i++] - '0');

  /* Note: we did not adjust the time based on time zone information */
  return mktime(&t);
}

static int openssl_revoked_revocationDate(lua_State* L)
{
  X509_REVOKED* revoked = CHECK_OBJECT(1, X509_REVOKED, "openssl.x509_revoked");
  const ASN1_TIME* time = X509_REVOKED_get0_revocationDate(revoked);
  lua_pushinteger(L, (LUA_INTEGER)ASN1_GetTimeT(time));
  PUSH_ASN1_TIME(L, time);
  return 2;
}

static int openssl_revoked_serialNumber(lua_State* L)
{
  X509_REVOKED* revoked = CHECK_OBJECT(1, X509_REVOKED, "openssl.x509_revoked");
  const ASN1_INTEGER *serialNumber = X509_REVOKED_get0_serialNumber(revoked);
  BIGNUM *bn = ASN1_INTEGER_to_BN(serialNumber, NULL);
  PUSH_OBJECT(bn, "openssl.bn");
  PUSH_ASN1_INTEGER(L, serialNumber);
  return 2;
}

static int openssl_revoked_extensions(lua_State* L)
{
  X509_REVOKED* revoked = CHECK_OBJECT(1, X509_REVOKED, "openssl.x509_revoked");
  const STACK_OF(X509_EXTENSION) *exts = X509_REVOKED_get0_extensions(revoked);
  int ret = 0;
  if (exts)
  {
    openssl_sk_x509_extension_totable(L, exts);
    ret = 1;
  }
  return ret;
};

static int openssl_revoked_free(lua_State* L)
{
  X509_REVOKED* revoked = CHECK_OBJECT(1, X509_REVOKED, "openssl.x509_revoked");
  X509_REVOKED_free(revoked);
  return 1;
}

static luaL_Reg revoked_funcs[] =
{
  {"info",            openssl_revoked_info},
  {"reason",          openssl_revoked_reason},
  {"revocationDate",  openssl_revoked_revocationDate},
  {"serialNumber",    openssl_revoked_serialNumber},
  {"extensions",      openssl_revoked_extensions},

  {"__tostring",      auxiliar_tostring},
  {"__gc",            openssl_revoked_free  },

  {NULL,    NULL}
};

IMP_LUA_SK(X509_CRL, x509_crl)

int luaopen_x509_crl(lua_State *L)
{
  auxiliar_newclass(L, "openssl.x509_crl", crl_funcs);
  auxiliar_newclass(L, "openssl.x509_revoked", revoked_funcs);

  lua_newtable(L);
  luaL_setfuncs(L, R, 0);

  return 1;
}
