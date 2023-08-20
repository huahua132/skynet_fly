/*=========================================================================*\
* x509 routines
* lua-openssl toolkit
*
* This product includes PHP software, freely available from <http://www.php.net/software/>
* Author:  george zhao <zhaozg(at)gmail.com>
\*=========================================================================*/
#ifndef LUA_EAY_H
#define LUA_EAY_H
#include <lua.h>
#include <lualib.h>
#include <lauxlib.h>
#include "auxiliar.h"
#include "subsidiar.h"

#include <assert.h>
#include <string.h>
/* OpenSSL includes */
#include <openssl/evp.h>
#include <openssl/x509.h>
#include <openssl/x509v3.h>
#include <openssl/crypto.h>
#include <openssl/pem.h>
#include <openssl/err.h>
#include <openssl/conf.h>
#if !defined(OPENSSL_NO_COMP)
#include <openssl/comp.h>
#endif
#include <openssl/rand.h>
#include <openssl/pkcs12.h>
#include <openssl/opensslv.h>
#include <openssl/bn.h>
#include <openssl/hmac.h>
#include <openssl/ts.h>
#include <openssl/ocsp.h>

/*-
* Numeric release version identifier:
* MNNFFPPS: major minor fix patch status
* The status nibble has one of the values 0 for development, 1 to e for betas
* 1 to 14, and f for release.  The patch level is exactly that.
* For example:
* 0.9.3-dev      0x00903000
* 0.9.3-beta1    0x00903001
* 0.9.3-beta2-dev 0x00903002
* 0.9.3-beta2    0x00903002 (same as ...beta2-dev)
* 0.9.3          0x0090300f
* 0.9.3a         0x0090301f
* 0.9.4          0x0090400f
* 1.2.3z         0x102031af
*/

/*History
  2017-04-18  update to 0.7.1
  2017-08-04  update to 0.7.3
  2019-03-24  update to 0.7.5-1
  2019-05-19  update to 0.7.5-2
  2019-08-20  update to 0.7.6
*/

/*                              MNNFFPPS  */
#define LOPENSSL_VERSION_NUM  0x0080500f
#ifndef LOPENSSL_VERSION
#define LOPENSSL_VERSION  "0.8.5"
#endif

#if OPENSSL_VERSION_NUMBER >= 0x10000000L
#include <openssl/lhash.h>
#define OPENSSL_HAVE_TS
#define LHASH LHASH_OF(CONF_VALUE)
#endif
typedef unsigned char byte;

#define MULTI_LINE_MACRO_BEGIN do {
#ifdef _MSC_VER
#define MULTI_LINE_MACRO_END  \
__pragma(warning(push))   \
__pragma(warning(disable:4127)) \
} while(0)      \
__pragma(warning(pop))
#else
#define MULTI_LINE_MACRO_END \
} while(0)
#endif

/* Common */
#include <time.h>
#ifndef MAX_PATH
#define MAX_PATH 260
#endif

#ifdef WIN32
#define snprintf _snprintf
#ifndef strcasecmp
#define strcasecmp stricmp
#endif
#endif

#ifdef _MSC_VER
# ifndef inline
#  define inline __inline
# endif
#endif

#if defined(_AIX)
# ifndef inline
#  define inline __inline
# endif
#endif

#if defined(__STDC__) && !defined(__STDC_VERSION__)
#  define inline __inline
#endif

#define LUA_FUNCTION(X) int X(lua_State *L)

int openssl_s2i_revoke_reason(const char*s);

LUALIB_API LUA_FUNCTION(luaopen_openssl);
LUA_FUNCTION(luaopen_digest);
LUA_FUNCTION(luaopen_hmac);
LUA_FUNCTION(luaopen_cipher);
LUA_FUNCTION(luaopen_bn);
LUA_FUNCTION(luaopen_pkey);
LUA_FUNCTION(luaopen_x509);
LUA_FUNCTION(luaopen_pkcs7);
LUA_FUNCTION(luaopen_pkcs12);
LUA_FUNCTION(luaopen_bio);
LUA_FUNCTION(luaopen_asn1);

LUA_FUNCTION(luaopen_ts);
LUA_FUNCTION(luaopen_x509_req);
LUA_FUNCTION(luaopen_x509_crl);
LUA_FUNCTION(luaopen_ocsp);
LUA_FUNCTION(luaopen_cms);
LUA_FUNCTION(luaopen_ssl);
LUA_FUNCTION(luaopen_ec);
LUA_FUNCTION(luaopen_rsa);
LUA_FUNCTION(luaopen_dsa);
LUA_FUNCTION(luaopen_dh);
#if (OPENSSL_VERSION_NUMBER >= 0x30000000L)
LUA_FUNCTION(luaopen_mac);
#endif

void openssl_add_method_or_alias(const OBJ_NAME *name, void *arg) ;
void openssl_add_method(const OBJ_NAME *name, void *arg);

#define CHECK_OBJECT(n,type,name) *(type**)auxiliar_checkclass(L,name,n)
#define CHECK_GROUP(n,type,name)  *(type**)auxiliar_checkgroup(L,name,n)

static inline void* openssl_getclass(lua_State *L, const char* name, int idx)
{
  void **p = (void**)auxiliar_getclassudata(L, name, idx);
  return p!=NULL ? *p : NULL;
}

static inline void* openssl_getgroup(lua_State *L, const char* name, int idx)
{
  void **p = (void**)auxiliar_getgroupudata(L, name, idx);
  return p!=NULL ? *p : NULL;
}

#define GET_OBJECT(n,type,name) ((type*)openssl_getclass(L,name,n))
#define GET_GROUP(n,type,name)  ((type*)openssl_getgroup(L,name,n))

#define PUSH_OBJECT(o, tname)                                   \
  MULTI_LINE_MACRO_BEGIN                                        \
  if(o) {                                                       \
  *(void **)(lua_newuserdata(L, sizeof(void *))) = (void*)(o);  \
  auxiliar_setclass(L,tname,-1);                                \
  } else lua_pushnil(L);                                        \
  MULTI_LINE_MACRO_END

#define FREE_OBJECT(i)  (*(void**)lua_touserdata(L, i) = NULL)

int openssl_register_lhash(lua_State* L);
int openssl_register_engine(lua_State* L);

LUA_FUNCTION(luaopen_srp);

#endif
