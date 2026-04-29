/* vim: set filetype=c : */

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
#define LOPENSSL_VERSION_NUM  0x00b0000f
#ifndef LOPENSSL_VERSION
#define LOPENSSL_VERSION  "0.11.1"
#endif

#if OPENSSL_VERSION_NUMBER >= 0x10000000L
#include <openssl/lhash.h>
#define OPENSSL_HAVE_TS
#define LHASH LHASH_OF(CONF_VALUE)
#endif



int openssl_s2i_revoke_reason(const char*s);

LUALIB_API int luaopen_openssl(lua_State *L);
int luaopen_digest(lua_State *L);
int luaopen_hmac(lua_State *L);
int luaopen_cipher(lua_State *L);
int luaopen_bn(lua_State *L);
int luaopen_pkey(lua_State *L);
int luaopen_x509(lua_State *L);
int luaopen_pkcs7(lua_State *L);
int luaopen_pkcs12(lua_State *L);
int luaopen_bio(lua_State *L);
int luaopen_asn1(lua_State *L);

int luaopen_ts(lua_State *L);
int luaopen_x509_req(lua_State *L);
int luaopen_x509_crl(lua_State *L);
int luaopen_ocsp(lua_State *L);
int luaopen_cms(lua_State *L);
int luaopen_ssl(lua_State *L);
int luaopen_ec(lua_State *L);
int luaopen_group(lua_State *L);
int luaopen_point(lua_State *L);
int luaopen_rsa(lua_State *L);
int luaopen_dsa(lua_State *L);
int luaopen_dh(lua_State *L);
#if (OPENSSL_VERSION_NUMBER >= 0x30000000L) && !defined(LIBRESSL_VERSION_NUMBER)
int luaopen_mac(lua_State *L);
int luaopen_param(lua_State *L);
int luaopen_provider(lua_State *L);
#endif
int luaopen_kdf(lua_State *L);
int luaopen_srp(lua_State *L);

#endif
