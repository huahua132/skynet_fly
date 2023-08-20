/***
Openssl binding for Lua, provide openssl full function in lua.

@module openssl
@usage
  openssl = require('openssl')
*/

#include "openssl.h"
#include <openssl/ssl.h>
#include <openssl/asn1.h>
#include <openssl/engine.h>
#include <openssl/opensslconf.h>
#include "private.h"

/***
get lua-openssl version
@function version
@tparam[opt] boolean format result will be number when set true, or string
@treturn lua-openssl version, lua version, openssl version
*/
static int openssl_version(lua_State*L)
{
  int num = lua_isnone(L, 1) ? 0 : auxiliar_checkboolean(L, 1);
  if (num)
  {
    lua_pushinteger(L, LOPENSSL_VERSION_NUM);
    lua_pushinteger(L, LUA_VERSION_NUM);
#ifdef LIBRESSL_VERSION_NUMBER
    lua_pushinteger(L, LIBRESSL_VERSION_NUMBER);
#else
    lua_pushinteger(L, OPENSSL_VERSION_NUMBER);
#endif
  }
  else
  {
    lua_pushstring(L, LOPENSSL_VERSION);
    lua_pushstring(L, LUA_VERSION);
    lua_pushstring(L, OPENSSL_VERSION_TEXT);
  }
  return 3;
}

/***
hex encode or decode string
@function hex
@tparam string str
@tparam[opt=true] boolean encode true to encoed, false to decode
@treturn string
*/
static LUA_FUNCTION(openssl_hex)
{
  size_t l = 0;
  const char* s = luaL_checklstring(L, 1, &l);
  int encode = lua_isnone(L, 2) ? 1 : lua_toboolean(L, 2);
  char* h = NULL;

  if (l == 0)
  {
    lua_pushstring(L, "");
    return 1;
  }
  if (encode)
  {
    h = OPENSSL_malloc(2 * l + 1);
    l = bin2hex((const unsigned char *)s, h, l);
  }
  else
  {
    h = OPENSSL_malloc(l / 2 + 1);
    l = hex2bin(s, (unsigned char *)h, l);
  };
  lua_pushlstring(L, (const char*)h, l);
  OPENSSL_free(h);

  return 1;
}

/***
base64 encode or decode
@function base64
@tparam string|bio input
@tparam[opt=true] boolean encode true to encoed, false to decode
@tparam[opt=true] boolean NO_NL true with newline, false without newline
@treturn string
*/
static LUA_FUNCTION(openssl_base64)
{
  BIO *inp = load_bio_object(L, 1);
  int encode = lua_isnone(L, 2) ? 1 : lua_toboolean(L, 2);
  int nonl = lua_isnone(L, 3) ? BIO_FLAGS_BASE64_NO_NL
             : (lua_toboolean(L, 3) ? BIO_FLAGS_BASE64_NO_NL : 0);
  BIO *b64 = BIO_new(BIO_f_base64());
  BIO *out = BIO_new(BIO_s_mem());
  BUF_MEM* mem = {0};
  int ret = 0;

  BIO_set_flags(b64, nonl);
  if (encode)
  {
    BIO_push(b64, out);
    BIO_get_mem_ptr(inp, &mem);
    BIO_write(b64, mem->data, mem->length);
    (void)BIO_flush(b64);
  }
  else
  {
    char inbuf[512];
    int inlen;
    BIO_push(b64, inp);
    while ((inlen = BIO_read(b64, inbuf, 512)) > 0)
      BIO_write(out, inbuf, inlen);
    (void)BIO_flush(out);
  }

  BIO_get_mem_ptr(out, &mem);
  if (mem->length > 0)
  {
    lua_pushlstring(L, mem->data, mem->length);
    ret = 1;
  }
  BIO_free_all(b64);
  if (encode)
    BIO_free(inp);
  else
    BIO_free(out);
  return ret;
}

static void list_callback(const OBJ_NAME *obj, void *arg)
{
  lua_State *L = (lua_State *)arg;
  int idx = (int)lua_rawlen(L, -1);
  lua_pushstring(L, obj->name);
  lua_rawseti(L, -2, idx + 1);
}

/***
get method names
@function list
@tparam string type support 'cipher','digests','pkeys','comps'
@treturn table as array
*/
static LUA_FUNCTION(openssl_list)
{
  static int options[] =
  {
    OBJ_NAME_TYPE_MD_METH,
    OBJ_NAME_TYPE_CIPHER_METH,
    OBJ_NAME_TYPE_PKEY_METH,
    OBJ_NAME_TYPE_COMP_METH
  };
  static const char *names[] = {"digests", "ciphers", "pkeys", "comps", NULL};
  int type = auxiliar_checkoption (L, 1, NULL, names, options);
  lua_createtable(L, 0, 0);
  OBJ_NAME_do_all_sorted(type, list_callback, L);
  return 1;
}

/***
get last or given error infomation

Most lua-openssl function or methods return nil or false when error or
failed, followed by string type error _reason_ and number type error _code_,
_code_ can pass to openssl.error() to get more error information.

@function error
@tparam[opt] number error, default use ERR_get_error() return value
@treturn number errcode
@treturn string reason
@treturn string library name
@treturn string function name
@treturn boolean is this is fatal error
*/
static LUA_FUNCTION(openssl_error_string)
{
  unsigned long val = ERR_get_error();
  if (val==0)
    return 0;

  val = (unsigned long)luaL_optinteger(L, 1, val);

  lua_pushstring (L, ERR_reason_error_string(val));
  lua_pushstring (L, ERR_lib_error_string   (val));
  lua_pushinteger(L, val);

#if (OPENSSL_VERSION_NUMBER < 0x30000000L)
  lua_pushstring (L, ERR_func_error_string  (val));
#else
  lua_pushnil(L);
#endif

#ifdef ERR_FATAL_ERROR
    lua_pushboolean(L, ERR_FATAL_ERROR      (val));
#else
  lua_pushnil(L);
#endif

  return 5;
}

static LUA_FUNCTION(openssl_clear_error)
{
  ERR_clear_error();
  return 0;
}

static LUA_FUNCTION(openssl_errors)
{
  int ret = 0;
  BIO *out = BIO_new(BIO_s_mem());
  if(out)
  {
    BUF_MEM* mem;

    ERR_print_errors(out);
    BIO_get_mem_ptr(out, &mem);
    lua_pushlstring(L, mem->data, mem->length);
    BIO_free(out);

    ERR_clear_error();
    ret = 1;
  }
  return ret;
}

/***
mixes the num bytes at buf into the PRNG state.
@function rand_add
@tparam string seed data to seed random generator
@tparam number entropy the lower bound of an estimate of how much randomness is contained in buf, measured in bytes.
*/
static int openssl_random_add(lua_State*L)
{
  size_t num = 0;
  const void *buf = luaL_checklstring(L, 1, &num);
  double entropy = luaL_optinteger(L, 2, num);

  RAND_add(buf, num, entropy);
  return 0;
}

/***
load rand seed from file
@function rand_load
@tparam[opt=nil] string file path to laod seed, default openssl management
@treturn boolean result
*/
static int openssl_random_load(lua_State*L)
{
  const char *file = luaL_optstring(L, 1, NULL);
  char buffer[MAX_PATH];
  int ret = 0, len = luaL_optinteger(L, 2, 2048);

  if (file == NULL)
    file = RAND_file_name(buffer, sizeof buffer);
  ret = RAND_load_file(file, len);

  lua_pushboolean(L, ret);
  return 1;
}

/***
save rand seed to file
@function rand_write
@tparam[opt=nil] string file path to save seed, default openssl management
@treturn bool result
*/
static int openssl_random_write(lua_State *L)
{
  const char *file = luaL_optstring(L, 1, NULL);
  char buffer[MAX_PATH];
  int ret = 0;

  if (file == NULL)
    file = RAND_file_name(buffer, sizeof buffer);
#ifndef OPENSSL_NO_EGD
  ret = RAND_egd(file);
  /* we try if the given filename is an EGD socket.
     if it is, we don't write anything back to the file.
   */
#endif
  if (ret!=1) ret = RAND_write_file(file);

  return openssl_pushresult(L, ret);
}

/***
get random generator state
@function rand_status
@tparam boolean result true for sucess
*/
static int openssl_random_status(lua_State *L)
{
  lua_pushboolean(L, RAND_status());
  return 1;
}

/***
get random bytes
@function random
@tparam number length
@treturn string
*/
static LUA_FUNCTION(openssl_random_bytes)
{
  long length = luaL_checkint(L, 1);

  char *buffer = NULL;
  int ret = 0;

  luaL_argcheck(L, length > 0, 1, "must greater than 0");

  buffer = malloc(length + 1);
  ret = RAND_bytes((byte*)buffer, length);
  if (ret == 1)
  {
    lua_pushlstring(L, buffer, length);
  }
  free(buffer);
  return ret==1 ? 1 : openssl_pushresult(L, ret);
}

/***
set FIPS mode
@function FIPS_mode
@tparam boolean fips true enable FIPS mode, false disable it.
@treturn boolean success
*/

/***
get FIPS mode
@function FIPS_mode
@treturn boolean return true when FIPS mode enabled, false when FIPS mode disabled.
*/
static int openssl_fips_mode(lua_State *L)
{
  int ret =0;
#if !defined(LIBRESSL_VERSION_NUMBER) && (OPENSSL_VERSION_NUMBER < 0x30000000L)
  int on = 0;
  FIPS_mode_set(0);
  if(lua_isnone(L, 1))
  {
    lua_pushboolean(L, FIPS_mode());
    ret = 1;
  }
  else
  {
    on = auxiliar_checkboolean(L, 1);
    ret = FIPS_mode_set(on);
    ret = openssl_pushresult(L, ret);
  }
#endif

  return ret;
}

#ifndef OPENSSL_NO_CRYPTO_MDEBUG
static int openssl_mem_leaks(lua_State*L)
{
  BIO *bio = BIO_new(BIO_s_mem());
  BUF_MEM* mem;

  CRYPTO_mem_leaks(bio);
  BIO_get_mem_ptr(bio, &mem);
  lua_pushlstring(L, mem->data, mem->length);
  BIO_free(bio);
  return 1;
}
#endif

/***
get openssl engine object
@function engine
@tparam string engine_id
@treturn engine
*/
static const luaL_Reg eay_functions[] =
{
  {"version",     openssl_version},
  {"list",        openssl_list},
  {"hex",         openssl_hex},
  {"base64",      openssl_base64},
#ifndef OPENSSL_NO_CRYPTO_MDEBUG
  {"mem_leaks",   openssl_mem_leaks},
#endif
  {"rand_status", openssl_random_status},
  {"rand_add",    openssl_random_add},
  {"rand_load",   openssl_random_load},
  {"rand_write",  openssl_random_write},
  {"random",      openssl_random_bytes},

  {"clear_error", openssl_clear_error},
  {"error",       openssl_error_string},
  {"errors",      openssl_errors},
  {"engine",      openssl_engine},
  {"FIPS_mode",   openssl_fips_mode},

  {NULL, NULL}
};

#if defined(OPENSSL_THREADS)
void CRYPTO_thread_setup(void);
void CRYPTO_thread_cleanup(void);
#endif

static void openssl_finalize()
{
#if OPENSSL_VERSION_NUMBER < 0x10100000L || defined(LIBRESSL_VERSION_NUMBER)
#if !defined(LIBRESSL_VERSION_NUMBER) && (OPENSSL_VERSION_NUMBER < 0x30000000L)
  FIPS_mode_set(0);
#endif

  OBJ_cleanup();
  EVP_cleanup();
  ENGINE_cleanup();
  RAND_cleanup();

#if OPENSSL_VERSION_NUMBER >= 0x10002000L && !defined(LIBRESSL_VERSION_NUMBER)
  SSL_COMP_free_compression_methods();
#endif
#if !defined(OPENSSL_NO_COMP)
  COMP_zlib_cleanup();
#endif


#if OPENSSL_VERSION_NUMBER < 0x10000000L
  ERR_remove_state(0);
#elif OPENSSL_VERSION_NUMBER < 0x10100000L || defined(LIBRESSL_VERSION_NUMBER)
  ERR_remove_thread_state(NULL);
#endif
#if defined(OPENSSL_THREADS)
  CRYPTO_thread_cleanup();
#endif
  CRYPTO_THREADID_set_callback(NULL);
  CRYPTO_set_locking_callback(NULL);

  CRYPTO_cleanup_all_ex_data();
  ERR_free_strings();

  CONF_modules_free();
  CONF_modules_unload(1);

#if OPENSSL_VERSION_NUMBER >= 0x30000000L
  OSSL_PROVIDER_unload("legacy");
  OSSL_PROVIDER_unload("default");
#endif

#ifndef OPENSSL_NO_CRYPTO_MDEBUG
#if !(defined(OPENSSL_NO_STDIO) || defined(OPENSSL_NO_FP_API))
#if defined(LIBRESSL_VERSION_NUMBER) || OPENSSL_VERSION_NUMBER < 0x10101000L
  CRYPTO_mem_leaks_fp(stderr);
#else
  if(CRYPTO_mem_leaks_fp(stderr)!=1)
  {
    fprintf(stderr,
            "Please report a bug on https://github.com/zhaozg/lua-openssl."
            "And if can, please provide a reproduce method and minimal code.\n"
            "\n\tThank You.");
  }
#endif
#endif /* OPENSSL_NO_STDIO or OPENSSL_NO_FP_API */
#endif /* OPENSSL_NO_CRYPTO_MDEBUG */
#endif /* OPENSSL_VERSION_NUMBER < 0x10100000L or defined(LIBRESSL_VERSION_NUMBER) */
}

#if OPENSSL_VERSION_NUMBER >= 0x30000000L
static OSSL_PROVIDER* legacy = NULL;
static OSSL_PROVIDER* openssl= NULL;

void openssl_atexit()
{
  if (legacy)
    OSSL_PROVIDER_unload(legacy);
  if (openssl)
    OSSL_PROVIDER_unload(openssl);
}
#endif

static void openssl_initialize() {
#if OPENSSL_VERSION_NUMBER < 0x10100000L || defined(LIBRESSL_VERSION_NUMBER)
#if defined(OPENSSL_THREADS)
  CRYPTO_thread_setup();
#endif

  OpenSSL_add_all_ciphers();
  OpenSSL_add_all_digests();
  SSL_library_init();

  ERR_load_ERR_strings();
  ERR_load_EVP_strings();
  ERR_load_crypto_strings();
  ERR_load_SSL_strings();
#endif

#ifndef OPENSSL_NO_ENGINE
#if OPENSSL_VERSION_NUMBER < 0x10100000L || defined(LIBRESSL_VERSION_NUMBER)
  ENGINE_load_openssl();
#else
  OPENSSL_init_crypto(OPENSSL_INIT_ENGINE_OPENSSL, NULL);
  OPENSSL_init_ssl(OPENSSL_INIT_ENGINE_ALL_BUILTIN
                  |OPENSSL_INIT_LOAD_CONFIG, NULL);
#endif
#if OPENSSL_VERSION_NUMBER < 0x30000000L
  ENGINE_load_builtin_engines();
#endif
#endif

#ifdef LOAD_ENGINE_CUSTOM
  LOAD_ENGINE_CUSTOM
#endif

#if OPENSSL_VERSION_NUMBER >= 0x30000000L
  legacy = OSSL_PROVIDER_load(NULL, "legacy");
  openssl = OSSL_PROVIDER_load(NULL, "default");
  atexit(openssl_atexit);
#endif
}

static int _guard = 0;

static int luaclose_openssl(lua_State *L)
{
  if(--_guard)
    return 0;
  openssl_finalize();
  return 0;
}

LUALIB_API int luaopen_openssl(lua_State*L)
{
  if(_guard++ == 0) {
    openssl_initialize();
  }

  lua_newtable(L);

  luaL_newmetatable(L, "openssl");
  lua_pushcfunction(L, luaclose_openssl);
  lua_setfield(L, -2, "__gc");
  lua_setmetatable(L, -2);

  luaL_setfuncs(L, eay_functions, 0);

  openssl_register_lhash(L);
  openssl_register_engine(L);

  luaopen_bio(L);
  lua_setfield(L, -2, "bio");

  luaopen_asn1(L);
  lua_setfield(L, -2, "asn1");


  luaopen_digest(L);
  lua_setfield(L, -2, "digest");

  luaopen_cipher(L);
  lua_setfield(L, -2, "cipher");

  luaopen_hmac(L);
  lua_setfield(L, -2, "hmac");

#if (OPENSSL_VERSION_NUMBER >= 0x30000000L)
  luaopen_mac(L);
  lua_setfield(L, -2, "mac");
#endif

  luaopen_pkey(L);
  lua_setfield(L, -2, "pkey");

#ifdef EVP_PKEY_EC
  luaopen_ec(L);
  lua_setfield(L, -2, "ec");
#endif

  luaopen_x509(L);
  lua_setfield(L, -2, "x509");

  luaopen_pkcs7(L);
  lua_setfield(L, -2, "pkcs7");

  luaopen_pkcs12(L);
  lua_setfield(L, -2, "pkcs12");

  luaopen_ocsp(L);
  lua_setfield(L, -2, "ocsp");

#ifdef OPENSSL_HAVE_TS
  /* timestamp handling */
  luaopen_ts(L);
  lua_setfield(L, -2, "ts");
#endif

  luaopen_cms(L);
  lua_setfield(L, -2, "cms");

  luaopen_ssl(L);
  lua_setfield(L, -2, "ssl");

  /* third part */
  luaopen_bn(L);
  lua_setfield(L, -2, "bn");

  luaopen_rsa(L);
  lua_setfield(L, -2, "rsa");
  luaopen_dsa(L);
  lua_setfield(L, -2, "dsa");
  luaopen_dh(L);
  lua_setfield(L, -2, "dh");

#ifndef OPENSSL_NO_SRP
  luaopen_srp(L);
  lua_setfield(L, -2, "srp");
#endif

#ifdef ENABLE_OPENSSL_GLOBAL
  lua_pushvalue(L, -1);
  lua_setglobal(L, "openssl");
#endif

  return 1;
}
