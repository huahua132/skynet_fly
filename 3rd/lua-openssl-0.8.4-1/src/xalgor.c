/***
x509.algor module to mapping X509_ALGOR to lua object.

@module x509.algor
@usage
  algor = require('openssl').x509.algor
*/
#include "openssl.h"
#include "private.h"
#include "sk.h"
IMP_LUA_SK(X509_ALGOR, x509_algor)

/***
Create x509_algor object

@function new
@treturn x509_algor mapping to X509_ALGOR in openssl
*/

static int openssl_xalgor_new(lua_State*L)
{
  X509_ALGOR* alg = X509_ALGOR_new();
  PUSH_OBJECT(alg, "openssl.x509_algor");
  return 1;
};

static luaL_Reg R[] =
{
  {"new",           openssl_xalgor_new},

  {NULL,          NULL},
};

/***
openssl.x509_algor object
@type x509_algor
*/
static int openssl_xalgor_gc(lua_State* L)
{
  X509_ALGOR* alg = CHECK_OBJECT(1, X509_ALGOR, "openssl.x509_algor");
  X509_ALGOR_free(alg);
  return 0;
}

/***
clone the x509_algor

@function dup
@treturn x509_algor clone of x509_algor
*/
static int openssl_xalgor_dup(lua_State* L)
{
  X509_ALGOR* alg = CHECK_OBJECT(1, X509_ALGOR, "openssl.x509_algor");
  X509_ALGOR* ano = X509_ALGOR_dup(alg);
  PUSH_OBJECT(ano, "openssl.x509_algor");
  return 1;
}

#if OPENSSL_VERSION_NUMBER >= 0x10002000L
/***
compare with other x509_algor object
@function equals
@treturn boolean return true if two x509_algor equals
*/
static int openssl_xalgor_cmp(lua_State* L)
{
  X509_ALGOR* alg = CHECK_OBJECT(1, X509_ALGOR, "openssl.x509_algor");
  X509_ALGOR* ano = CHECK_OBJECT(2, X509_ALGOR, "openssl.x509_algor");
  if ( alg->algorithm != NULL && ano->algorithm != NULL)
    lua_pushboolean(L, X509_ALGOR_cmp(alg, ano) == 0);
  else
    lua_pushboolean(L, 1);
  return 1;
}
#endif

#if OPENSSL_VERSION_NUMBER >= 0x10001000L
/***
set message digest object to x509_algor
@function md
@tparam number|string|evp_md md
*/
static int openssl_xalgor_md(lua_State* L)
{
  X509_ALGOR* alg = CHECK_OBJECT(1, X509_ALGOR, "openssl.x509_algor");
  const EVP_MD* md = get_digest(L, 2, NULL);
  X509_ALGOR_set_md(alg, md);
  return 0;
}
#endif

/***
get x509_algor properties
@function get
@tparam asn1_object ident algorithm, nil for fail
@tparam asn1_string attached paramater value
*/
static int openssl_xalgor_get(lua_State* L)
{
  int type;
  CONSTIFY_X509_get0 void* val;
  CONSTIFY_X509_get0 ASN1_OBJECT *obj;

  CONSTIFY_X509_get0 X509_ALGOR* alg = CHECK_OBJECT(1, X509_ALGOR, "openssl.x509_algor");

  X509_ALGOR_get0(&obj, &type, &val, alg);
  if (obj != NULL)
  {
    openssl_push_asn1object(L, obj);
  }
  else
    lua_pushnil(L);
  if (type == V_ASN1_UNDEF)
    lua_pushnil(L);
  else
  {
    PUSH_ASN1_STRING(L, val);
  }

  return 2;
}

/***
set x509_algor properties
@function set
@tparam asn1_object obj ident algorithm in openssl
@tparam[opt] asn1_string val attached paramater value
@treturn boolean result true for success, others for fail
*/
/***
set digest algorithm, alias of set()
only when OPENSSL_VERSION_NUMBER >= 0x10001000
@function set
@tparam string|evp_digest digest algorithm
*/
static int openssl_xalgor_set(lua_State* L)
{
  int ret = 0;
  X509_ALGOR* alg = CHECK_OBJECT(1, X509_ALGOR, "openssl.x509_algor");
  ASN1_OBJECT* obj = CHECK_OBJECT(2, ASN1_OBJECT, "openssl.asn1_object");
  ASN1_STRING* val = lua_isnone(L, 3) ?
                     NULL : CHECK_OBJECT(3, ASN1_STRING, "openssl.asn1_string");
  obj = OBJ_dup(obj);
  if(val)
  {
    val = ASN1_STRING_dup(val);
    ret = X509_ALGOR_set0(alg, obj, val->type, val);
  }
  else
  {
    ret = X509_ALGOR_set0(alg, obj, 0, NULL);
  }
  return openssl_pushresult(L, ret);
}

/***
convert x509_algor to txt string of asn1_object
@function tostring
@tparam string txt of asn1_object
*/
static int openssl_xalgor_tostring(lua_State* L)
{
  int type;
  CONSTIFY_X509_get0 void* val;
  CONSTIFY_X509_get0 ASN1_OBJECT *obj;

  CONSTIFY_X509_get0 X509_ALGOR* alg = CHECK_OBJECT(1, X509_ALGOR, "openssl.x509_algor");

  X509_ALGOR_get0(&obj, &type, &val, alg);
  if (obj != NULL)
  {
    luaL_Buffer B;
    luaL_buffinit(L, &B);

    luaL_addsize(&B, OBJ_obj2txt(luaL_prepbuffer(&B), LUAL_BUFFERSIZE, obj, 0));
    luaL_pushresult(&B);
    return 1;
  }
  return 0;
}

/***
check with other x509_algor whether equals, alias with == operator
only when OPENSSL_VERSION_NUMBER >= 0x10002000L

@function equals
@tparam x509_algor other to compare
*/


static luaL_Reg xalgor_funcs[] =
{
  {"dup",               openssl_xalgor_dup},
  {"set",               openssl_xalgor_set},
  {"get",               openssl_xalgor_get},
#if OPENSSL_VERSION_NUMBER >= 0x10001000L
  {"md",                openssl_xalgor_md},
#endif
  {"tostring",          openssl_xalgor_tostring},
#if OPENSSL_VERSION_NUMBER >= 0x10002000L
  {"equals",            openssl_xalgor_cmp},
  {"__eq",              openssl_xalgor_cmp},
#endif
  {"__tostring",        auxiliar_tostring},
  {"__gc",              openssl_xalgor_gc},

  {NULL,          NULL},
};

int openssl_register_xalgor(lua_State*L)
{
  auxiliar_newclass(L, "openssl.x509_algor", xalgor_funcs);
  lua_newtable(L);
  luaL_setfuncs(L, R, 0);

  return 1;
}
