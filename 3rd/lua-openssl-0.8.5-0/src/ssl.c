/***
ssl modules to create SSL/TLS server or client, send and recv data over SSL channels.

@module ssl
@usage
  ssl = require('openssl').ssl
*/
#include "openssl.h"
#include "private.h"
#include <stdint.h>
#include "ssl_options.h"

#include <openssl/ssl.h>
#include <openssl/rsa.h>
#include <openssl/ec.h>
#include <openssl/dh.h>

#if OPENSSL_VERSION_NUMBER > 0x30000000
#ifndef SSL_get_peer_certificate
#define SSL_get_peer_certificate SSL_get1_peer_certificate
#endif
#ifndef SSL_DEFAULT_CIPHER_LIST
#define SSL_DEFAULT_CIPHER_LIST OSSL_default_cipher_list()
#endif
#endif

/***
create ssl_ctx object, which mapping to SSL_CTX in openssl.
@function ctx_new
@tparam string protocol support 'SSLv3', 'SSLv23', 'SSLv2', 'TSLv1', 'TSLv1_1','TSLv1_2','TLS', 'DTLSv1','DTLSv1_2', and can be follow by '_server' or '_client', in general you should use 'TLS' to negotiate highest available SSL/TLS version
@tparam[opt] string support_ciphers, if not given, default of openssl will be used
@treturn ssl_ctx
*/
#if OPENSSL_VERSION_NUMBER > 0x10100000L
#define  TLS_PROTOCOL_TIPS  \
  "only support TLS, DTLS to negotiate highest available SSL/TLS or DTLS " \
  "version above openssl v1.1.0\n" \
  "optional followed by _client or _server\n" \
  "default is TLS\n"
#define DEFAULT_PROTOCOL "TLS"
#else
#define  TLS_PROTOCOL_TIPS  \
  "SSLv23, TLSv1_2, TLSv1_1, TLSv1, DTLSv1_2 or DTLSv1, optional followed by _client or _server\n" \
  "optional followed by _client or _server\n" \
  "default is SSLv23 to negotiate highest available SSL/TLS\n"
#define DEFAULT_PROTOCOL "SSLv23"
#endif

typedef enum{
  SSL_CTX_SESSION_ADD = 0,
  SSL_CTX_SESSION_GET,
  SSL_CTX_SESSION_DEL,
#if OPENSSL_VERSION_NUMBER < 0x10100000L

  SSL_CTX_TEMP_DH,
  SSL_CTX_TEMP_RSA,
  SSL_CTX_TEMP_ECDH,
#endif
  SSL_CTX_MAX_IDX
}SSL_CTX_INDEX;

static int openssl_ssl_ctx_new(lua_State*L)
{
  const char* meth = luaL_optstring(L, 1, DEFAULT_PROTOCOL);
#if OPENSSL_VERSION_NUMBER >= 0x01000000L
  const
#endif
  SSL_METHOD* method = NULL;
  const char* ciphers;
  SSL_CTX* ctx;

  if (strcmp(meth, "SSLv23") == 0)
    method = SSLv23_method();
  else if (strcmp(meth, "SSLv23_server") == 0)
    method = SSLv23_server_method();
  else if (strcmp(meth, "SSLv23_client") == 0)
    method = SSLv23_client_method();

#if OPENSSL_VERSION_NUMBER > 0x10100000L
  else if (strcmp(meth, "TLS") == 0)
    method = TLS_method();
  else if (strcmp(meth, "TLS_server") == 0)
    method = TLS_server_method();
  else if (strcmp(meth, "TLS_client") == 0)
    method = TLS_client_method();

  else if (strcmp(meth, "DTLS") == 0)
    method = DTLS_method();
  else if (strcmp(meth, "DTLS_server") == 0)
    method = DTLS_server_method();
  else if (strcmp(meth, "DTLS_client") == 0)
    method = DTLS_client_method();
#endif

#ifndef OPENSSL_NO_DTLS1_2_METHOD
  else if (strcmp(meth, "DTLSv1_2") == 0)
    method = DTLSv1_2_method();
  else if (strcmp(meth, "DTLSv1_2_server") == 0)
    method = DTLSv1_2_server_method();
  else if (strcmp(meth, "DTLSv1_2_client") == 0)
    method = DTLSv1_2_client_method();
#endif

#ifndef OPENSSL_NO_DTLS1_METHOD
  else if (strcmp(meth, "DTLSv1") == 0)
    method = DTLSv1_method();
  else if (strcmp(meth, "DTLSv1_server") == 0)
    method = DTLSv1_server_method();
  else if (strcmp(meth, "DTLSv1_client") == 0)
    method = DTLSv1_client_method();
#endif

#ifndef OPENSSL_NO_TLS1_2_METHOD
  else if (strcmp(meth, "TLSv1_2") == 0)
    method = TLSv1_2_method();
  else if (strcmp(meth, "TLSv1_2_server") == 0)
    method = TLSv1_2_server_method();
  else if (strcmp(meth, "TLSv1_2_client") == 0)
    method = TLSv1_2_client_method();
#endif

#ifndef OPENSSL_NO_TLS1_1_METHOD
  else if (strcmp(meth, "TLSv1_1") == 0)
    method = TLSv1_1_method();
  else if (strcmp(meth, "TLSv1_1_server") == 0)
    method = TLSv1_1_server_method();
  else if (strcmp(meth, "TLSv1_1_client") == 0)
    method = TLSv1_1_client_method();
#endif

#ifndef OPENSSL_NO_TLS1_METHOD
  else if (strcmp(meth, "TLSv1") == 0)
    method = TLSv1_method();
  else if (strcmp(meth, "TLSv1_server") == 0)
    method = TLSv1_server_method();
  else if (strcmp(meth, "TLSv1_client") == 0)
    method = TLSv1_client_method();
#endif

#ifndef OPENSSL_NO_SSL3_METHOD
  else if (strcmp(meth, "SSLv3") == 0)
    method = SSLv3_method();
  else if (strcmp(meth, "SSLv3_server") == 0)
    method = SSLv3_server_method();
  else if (strcmp(meth, "SSLv3_client") == 0)
    method = SSLv3_client_method();
#endif

#ifdef LOAD_SSL_CUSTOM
  LOAD_SSL_CUSTOM
#endif
  else
    luaL_argerror(L, 1, TLS_PROTOCOL_TIPS);

  ctx = SSL_CTX_new(method);
  if (!ctx)
    luaL_argerror(L, 1, TLS_PROTOCOL_TIPS);

  ciphers = luaL_optstring(L, 2, SSL_DEFAULT_CIPHER_LIST);
#if OPENSSL_VERSION_NUMBER > 0x10100000L && !defined(LIBRESSL_VERSION_NUMBER)
  if(!SSL_CTX_set_ciphersuites(ctx, ciphers) &&
     !SSL_CTX_set_cipher_list(ctx, ciphers))
#else
  if(!SSL_CTX_set_cipher_list(ctx, ciphers))
#endif
    luaL_argerror(L, 2, "Error to set cipher list");

  PUSH_OBJECT(ctx, "openssl.ssl_ctx");
  SSL_CTX_set_app_data(ctx, L);
  openssl_newvalue(L, ctx);

  return 1;
}

/***
get alert_type for ssl state
@function alert_type
@tparam number alert
@tparam[opt=false] boolean long
@treturn string alert type
*/
static int openssl_ssl_alert_type(lua_State*L)
{
  int v = luaL_checkint(L, 1);
  int _long = lua_isnone(L, 2) ? 0 : auxiliar_checkboolean(L, 2);
  const char* val;

  if (_long)
    val = SSL_alert_type_string_long(v << 8);
  else
    val = SSL_alert_type_string(v << 8);
  lua_pushstring(L, val);

  return 1;
}

/***
get alert_desc for ssl state
@function alert_desc
@tparam number alert
@tparam[opt=false] boolean long
@treturn string alert type
@treturn string desc string, if long set true will return long info
*/
static int openssl_ssl_alert_desc(lua_State*L)
{
  int v = luaL_checkint(L, 1);
  int _long = lua_isnone(L, 2) ? 0 : auxiliar_checkboolean(L, 2);
  const char* val;

  if (_long)
    val = SSL_alert_desc_string_long(v);
  else
    val = SSL_alert_desc_string(v);
  lua_pushstring(L, val);

  return 1;
}

static int openssl_ssl_session_new(lua_State*L)
{
  SSL_SESSION *ss = SSL_SESSION_new();
  PUSH_OBJECT(ss, "openssl.ssl_session");
  return 1;
}

static int openssl_ssl_session_read(lua_State*L)
{
  BIO *in = load_bio_object(L, 1);
  SSL_SESSION* ss = PEM_read_bio_SSL_SESSION(in, NULL, NULL, NULL);
  if (!ss)
  {
    (void)BIO_reset(in);
    ss = d2i_SSL_SESSION_bio(in, NULL);
  }
  BIO_free(in);
  if (ss)
  {
    PUSH_OBJECT(ss, "openssl.ssl_session");
    return 1;
  }
  return openssl_pushresult(L, 0);
}

static luaL_Reg R[] =
{
  {"ctx_new",       openssl_ssl_ctx_new },
  {"alert_type",    openssl_ssl_alert_type },
  {"alert_desc",    openssl_ssl_alert_desc },

  {"session_new",   openssl_ssl_session_new},
  {"session_read",  openssl_ssl_session_read},
  {NULL,    NULL}
};

/****************************SSL CTX********************************/
/***
openssl.ssl_ctx object
@type ssl_ctx
*/

/***
tell ssl_ctx use private key and certificate, and check private key
@function use
@tparam evp_pkey pkey
@tparam x509 cert
@treturn boolean result return true for ok, or nil followed by errmsg and errval
*/
static int openssl_ssl_ctx_use(lua_State*L)
{
  int ret;
  SSL_CTX* ctx = CHECK_OBJECT(1, SSL_CTX, "openssl.ssl_ctx");
  EVP_PKEY* pkey = CHECK_OBJECT(2, EVP_PKEY, "openssl.evp_pkey");

  if(lua_isstring(L, 3))
  {
    ret = SSL_CTX_use_certificate_chain_file(ctx, luaL_checkstring(L, 3));
  }
  else
  {
    X509* cert = CHECK_OBJECT(3, X509, "openssl.x509");
    ret = SSL_CTX_use_certificate(ctx, cert);
  }
  if (ret == 1)
  {
    ret = SSL_CTX_use_PrivateKey(ctx, pkey);
    if (ret == 1)
    {
      ret = SSL_CTX_check_private_key(ctx);
    }
  }
  return openssl_pushresult(L, ret);
}

/***
add client ca cert and option extra chain cert
@function add
@tparam x509 clientca
@tparam[opt] table extra_chain_cert_array
@treturn boolean result
*/
static int openssl_ssl_ctx_add(lua_State*L)
{
  SSL_CTX* ctx = CHECK_OBJECT(1, SSL_CTX, "openssl.ssl_ctx");
  X509* x = CHECK_OBJECT(2, X509, "openssl.x509");
  int ret = SSL_CTX_add_client_CA(ctx, x);
  if (ret == 1 && !lua_isnone(L, 3))
  {
    size_t i;
    luaL_checktable(L, 3);

    for (i = 1; ret == 1 && i <= lua_rawlen(L, 3); i++ )
    {
      lua_rawgeti(L, 3, i);
      x = CHECK_OBJECT(2, X509, "openssl.x509");
      lua_pop(L, 1);
      X509_up_ref(x);
      ret = SSL_CTX_add_extra_chain_cert(ctx, x);
    }
  }
  return openssl_pushresult(L, ret);
}

static int openssl_ssl_ctx_gc(lua_State*L)
{
  SSL_CTX* ctx = CHECK_OBJECT(1, SSL_CTX, "openssl.ssl_ctx");
  SSL_CTX_free(ctx);
  openssl_freevalue(L, ctx);

  return 0;
}

/***
get timeout
@function timeout
@return number
*/
/***
set timeout
@function timeout
@tparam number timeout
@treturn number previous timeout
*/
static int openssl_ssl_ctx_timeout(lua_State*L)
{
  SSL_CTX* ctx = CHECK_OBJECT(1, SSL_CTX, "openssl.ssl_ctx");
  long t;
  if (!lua_isnone(L, 2))
  {
    t = SSL_CTX_set_timeout(ctx, luaL_checkint(L, 2));
    lua_pushinteger(L, t);
    return 1;
  }
  t = SSL_CTX_get_timeout(ctx);
  lua_pushinteger(L, t);
  return 1;
}

static const int iMode_options[] =
{
  SSL_MODE_ENABLE_PARTIAL_WRITE,
  SSL_MODE_ACCEPT_MOVING_WRITE_BUFFER,
  SSL_MODE_AUTO_RETRY,
  SSL_MODE_NO_AUTO_CHAIN,
#ifdef SSL_MODE_RELEASE_BUFFERS
  SSL_MODE_RELEASE_BUFFERS,
#endif
  0
};

static const char* sMode_options[] =
{
  "enable_partial_write",
  "accept_moving_write_buffer",
  "auto_retry",
  "no_auto_chain",
#ifdef SSL_MODE_RELEASE_BUFFERS
  "release_buffers",
#endif
  NULL
};

/***
clean given mode
mode support 'enable_partial_write','accept_moving_write_buffer','auto_retry','no_auto_chain','release_buffers'
@function mode
@tparam boolean clear must be true
@tparam string mode
@param[opt] ...
@treturn string
@treturn ...
@usage
 modes = { ssl_ctx:mode('enable_partial_write','accept_moving_write_buffer','auto_retry') },

  for  i, v in ipairs(modes)
    print(v)
 end
 --output 'enable_partial_write','accept_moving_write_buffer','auto_retry'
*/
static int openssl_ssl_ctx_mode(lua_State*L)
{
  SSL_CTX* ctx = CHECK_OBJECT(1, SSL_CTX, "openssl.ssl_ctx");
  int mode = 0;
  int ret;
  int i;
  if (!lua_isnoneornil(L, 2))
  {
    int clear = 0;
    if(lua_isboolean(L, 2))
    {
      clear = lua_toboolean(L, 2);
      i = 3;
    }
    else
      i = 2;
    while (i <= lua_gettop(L))
    {
      mode = mode | auxiliar_checkoption(L, i++, NULL, sMode_options, iMode_options);
    }
    if (clear != 0)
      mode = SSL_CTX_set_mode(ctx, mode);
    else
      mode = SSL_CTX_clear_mode(ctx, mode);
  }
  else
    mode = SSL_CTX_get_mode(ctx);
  ret = 0;
  for (i = 0; i < sizeof(iMode_options) / sizeof(int); i++)
  {
    if (mode & iMode_options[i])
    {
      lua_pushstring(L, sMode_options[i]);
      ret++;
    }
  }
  return ret;
};

/***
get options
@function options
@treturn table string list of current options
*/

/***
set options
@function options
@tparam string option, support "microsoft_sess_id_bug", "netscape_challenge_bug", "netscape_reuse_cipher_change_bug",
"sslref2_reuse_cert_type_bug", "microsoft_big_sslv3_buffer", "msie_sslv3_rsa_padding","ssleay_080_client_dh_bug",
"tls_d5_bug","tls_block_padding_bug","dont_insert_empty_fragments","all", please to see ssl_options.h
@treturn table string list of current options after set new option
*/

/***
clear options
@function options
@tparam boolean clear set true to clear options
@tparam string option, support "microsoft_sess_id_bug", "netscape_challenge_bug", "netscape_reuse_cipher_change_bug",
"sslref2_reuse_cert_type_bug", "microsoft_big_sslv3_buffer", "msie_sslv3_rsa_padding","ssleay_080_client_dh_bug",
"tls_d5_bug","tls_block_padding_bug","dont_insert_empty_fragments","all",  please to see ssl_options.h
@treturn table string list of current options after clear some option
*/
static int openssl_ssl_ctx_options(lua_State*L)
{
  SSL_CTX* ctx = CHECK_OBJECT(1, SSL_CTX, "openssl.ssl_ctx");
  long options = 0;
  int ret;
  int i;
  if (!lua_isnone(L, 2))
  {
    int top = lua_gettop(L);
    int clear = 0;
    if (lua_isboolean(L, 2))
    {
      clear = lua_toboolean(L, 2);
      i = 3;
    }
    else
      i = 2;
    for (; i <= top; i++)
    {
      if (lua_isnumber(L, i))
        options |= (long)luaL_checkinteger(L, i);
      else
      {
        const char* s = luaL_checkstring(L, i);
        int j;
        for (j = 0; ssl_options[j].name; j++)
        {
          LuaL_Enumeration e = ssl_options[j];
          if (strcasecmp(s, e.name) == 0)
          {
            options |= e.val;
            break;
          }
        }
      }
    }

    if (clear != 0)
      options = SSL_CTX_clear_options(ctx, options);
    else
      options = SSL_CTX_set_options(ctx, options);
  }
  else
    options = SSL_CTX_get_options(ctx);

  lua_newtable(L);
  ret = 0;
  for (i = 0; ssl_options[i].name; i++)
  {
    LuaL_Enumeration e = ssl_options[i];
    if (options & e.val)
    {
      lua_pushstring(L, e.name);
      ret++;
      lua_rawseti(L, -2, ret);
    }
  }
  return 1;
}

/***
get min_proto_version and max_proto_version
@function version
@treturn[1] integer min_proto_version
@treturn[2] integer man_proto_version
*/

/***
set min_proto_version and max_proto_version
@function options
@tparam integer min
@tparam integer max
@treturn boolean result or fail
*/
#if OPENSSL_VERSION_NUMBER > 0x10100000L
static int openssl_ssl_ctx_version(lua_State*L)
{
  SSL_CTX* ctx = CHECK_OBJECT(1, SSL_CTX, "openssl.ssl_ctx");
  int ret;
  int minv = SSL_CTX_get_min_proto_version(ctx);
  int maxv = SSL_CTX_get_max_proto_version(ctx);

  if (lua_isnone(L, 2))
  {
    lua_pushinteger(L, minv);
    lua_pushinteger(L, maxv);
    return 2;
  }

  minv = luaL_optinteger(L, 2, minv);
  maxv = luaL_optinteger(L, 3, maxv);
  luaL_argcheck(L, minv <= maxv, 3, "max version can't less than min");

  ret = SSL_CTX_set_min_proto_version(ctx, minv);
  if (ret == 1)
    ret = SSL_CTX_set_min_proto_version(ctx, maxv);

  if (ret==1)
  {
    lua_pushvalue(L, 1);
    return 1;
  }
  return openssl_pushresult(L, ret);
}
#endif

/***
get quit_shutdown is set or not
Normally when a SSL connection is finished, the parties must send out
"close notify" alert messages using ***SSL:shutdown"*** for a clean shutdown.
@function quiet_shutdown
@treturn boolean result
*/
/***
set quiet_shutdown
@function quiet_shutdown
@tparam boolean quiet
When setting the "quiet shutdown" flag to 1, ***SSL:shutdown*** will set the internal flags
to SSL_SENT_SHUTDOWN|SSL_RECEIVED_SHUTDOWN. ***SSL:shutdown*** then behaves like
***SSL:set_shutdown*** called with SSL_SENT_SHUTDOWN|SSL_RECEIVED_SHUTDOWN.
The session is thus considered to be shutdown, but no "close notify" alert
is sent to the peer. This behaviour violates the TLS standard.
The default is normal shutdown behaviour as described by the TLS standard.
@treturn boolean result
*/
static int openssl_ssl_ctx_quiet_shutdown(lua_State*L)
{
  SSL_CTX* s = CHECK_OBJECT(1, SSL_CTX, "openssl.ssl_ctx");
  if (lua_isnone(L, 2))
  {
    int m = SSL_CTX_get_quiet_shutdown(s);
    lua_pushinteger(L, m);
    return 1;
  }
  else
  {
    int m = luaL_checkint(L, 2);
    SSL_CTX_set_quiet_shutdown(s, m);
    return 0;
  }
};

/***
set verify locations with cafile and capath
ssl_ctx:verify_locations specifies the locations for *ctx*, at
which CA certificates for verification purposes are located. The certificates
available via *CAfile* and *CApath* are trusted.
@function verify_locations
@tparam string cafile
@tparam string capath
@treturn boolean result
*/
static int openssl_ssl_ctx_load_verify_locations(lua_State*L)
{
  SSL_CTX* ctx = CHECK_OBJECT(1, SSL_CTX, "openssl.ssl_ctx");
  const char* CAfile = luaL_checkstring(L, 2);
  const char* CApath = luaL_optstring(L, 3, NULL);
#if (OPENSSL_VERSION_NUMBER >= 0x30000000L)
  int ret = !(CAfile == NULL && CApath == NULL);
  if (CAfile != NULL)
    ret = SSL_CTX_load_verify_file(ctx, CAfile);
  if ( ret==1 && CApath != NULL)
    ret = SSL_CTX_load_verify_dir(ctx, CApath);
#else
  int ret = SSL_CTX_load_verify_locations(ctx, CAfile, CApath);
#endif
  return openssl_pushresult(L, ret);
}

/***
get certificate verification store of ssl_ctx
@function cert_store
@treturn x509_store store
*/
/***
set or replaces then certificate verification store of ssl_ctx
@function cert_store
@tparam x509_store store
@treturn x509_store store
*/
static int openssl_ssl_ctx_cert_store(lua_State*L)
{
#if OPENSSL_VERSION_NUMBER >  0x10002000L
  SSL_CTX* ctx = CHECK_OBJECT(1, SSL_CTX, "openssl.ssl_ctx");
  X509_STORE *store = NULL;
  if (lua_isnone(L, 2))
  {
    store = SSL_CTX_get_cert_store(ctx);
    X509_STORE_up_ref(store);
    PUSH_OBJECT(store, "openssl.x509_store");
    return 1;
  }
  else
  {
    store = CHECK_OBJECT(2, X509_STORE, "openssl.x509_store");
    X509_STORE_up_ref(store);
    SSL_CTX_set_cert_store(ctx, store);
    X509_STORE_set_trust(store, 1);
    return 0;
  }
#else
  luaL_error(L, "NYI, openssl below 1.0.2 not fully support this feature");
  return 0;
#endif
}

#ifndef OPENSSL_NO_ENGINE
static int openssl_ssl_ctx_set_engine(lua_State*L)
{
  SSL_CTX* ctx = CHECK_OBJECT(1, SSL_CTX, "openssl.ssl_ctx");
  ENGINE* eng = CHECK_OBJECT(2, ENGINE,  "openssl.engine");
  int ret = SSL_CTX_set_client_cert_engine(ctx, eng);
  return openssl_pushresult(L, ret);
}
#endif

/****************************************************************************/
/***
create ssl object
@function ssl
@tparam number fd
@tparam[opt=false] boolean server, true will make ssl server
@treturn ssl
*/
/***
create ssl object
@function ssl
@tparam bio input
@tparam[opt=input] bio ouput, default will use input as output
@tparam[opt=false] boolean server, true will make ssl server
@treturn ssl
*/
static int openssl_ssl_ctx_new_ssl(lua_State*L)
{
  SSL_CTX* ctx = CHECK_OBJECT(1, SSL_CTX, "openssl.ssl_ctx");
  int server = 0;
  int mode_idx = 2;
  SSL *ssl = SSL_new(ctx);
  int ret = 1;

  if (auxiliar_getclassudata(L, "openssl.bio", 2))
  {
    BIO *bi = CHECK_OBJECT(2, BIO, "openssl.bio");
    BIO *bo = bi;

    /* avoid bi be gc */
    BIO_up_ref(bi);

    if (auxiliar_getclassudata(L, "openssl.bio", 3))
    {
      bo = CHECK_OBJECT(3, BIO, "openssl.bio");
      mode_idx = 4;
    }
    else
      mode_idx = 3;

    /* avoid bo be gc */
    BIO_up_ref(bo);

#if OPENSSL_VERSION_NUMBER > 0x10100000L && !defined(LIBRESSL_VERSION_NUMBER)
    SSL_set0_rbio(ssl, bi);
    SSL_set0_wbio(ssl, bo);
#else
    SSL_set_bio(ssl, bi, bo);
#endif
    ret = 1;
  }
  else if (lua_isnumber(L, 2))
  {
    ret = SSL_set_fd(ssl, luaL_checkint(L, 2));
    mode_idx = 3;
  }

  if (ret == 1 && !lua_isnone(L, mode_idx))
  {
    server = lua_isnil(L, mode_idx) ? 0 : auxiliar_checkboolean(L, mode_idx);
  }

  if (ret == 1)
  {
    if (server)
      SSL_set_accept_state(ssl);
    else
      SSL_set_connect_state(ssl);

    PUSH_OBJECT(ssl, "openssl.ssl");
    openssl_newvalue(L, ssl);

    /* ref to ctx */
    lua_pushvalue(L, 1);
    openssl_valueset(L, ssl, "ctx");
  }
  else
  {
    SSL_free(ssl);
    openssl_freevalue(L, ssl);
    return openssl_pushresult(L, ret);
  }
  return 1;
}

/***
create bio object
@function bio
@tparam string host_addr format like 'host:port'
@tparam[opt=false] boolean server, true listen at host_addr,false connect to host_addr
@tparam[opt=true] boolean autoretry ssl operation autoretry mode
@treturn bio bio object
*/
static int openssl_ssl_ctx_new_bio(lua_State*L)
{
  SSL_CTX* ctx = CHECK_OBJECT(1, SSL_CTX, "openssl.ssl_ctx");
  const char* host_addr = luaL_checkstring(L, 2);
  int server = lua_isnone(L, 3) ? 0 : auxiliar_checkboolean(L, 3);
  int autoretry = lua_isnone(L, 4) ? 1 : auxiliar_checkboolean(L, 4);

  BIO *bio = server ? BIO_new_ssl(ctx, 0) : BIO_new_ssl_connect(ctx);
  if (bio)
  {
    int ret = 0;
    if (autoretry)
    {
      SSL *ssl = NULL;
      ret = BIO_get_ssl(bio, &ssl);
      if (ret==1)
        SSL_set_mode(ssl, SSL_MODE_AUTO_RETRY);
    }
    if (server)
    {
      BIO* acpt = BIO_new_accept((char*)host_addr);
      BIO_set_accept_bios(acpt, bio);
      bio = acpt;
    }
    else
    {
      ret = BIO_set_conn_hostname(bio, host_addr);
    }
    if (ret == 1)
    {
      PUSH_OBJECT(bio, "openssl.bio");
      return 1;
    }
    else
      return openssl_pushresult(L, ret);
  }
  else
  {
    BIO_free(bio);
    bio = NULL;
    return 0;
  }
}

/***
get verify depth when cert chain veirition
@function verify_depth
@treturn number depth
*/
/***
set verify depth when cert chain veirition
@function verify_depth
@tparam number depth
@treturn number depth
*/
static int openssl_ssl_ctx_verify_depth(lua_State*L)
{
  SSL_CTX* ctx = CHECK_OBJECT(1, SSL_CTX, "openssl.ssl_ctx");
  int depth;
  if (!lua_isnone(L, 2))
  {
    depth = luaL_checkint(L, 2);
    SSL_CTX_set_verify_depth(ctx, depth);
  }
  depth = SSL_CTX_get_verify_depth(ctx);
  lua_pushinteger(L, depth);
  return 1;
}

static const int iVerifyMode_Options[] =
{
  SSL_VERIFY_NONE,
  SSL_VERIFY_PEER,
  SSL_VERIFY_FAIL_IF_NO_PEER_CERT,
  SSL_VERIFY_CLIENT_ONCE,
  0
};

static const char* sVerifyMode_Options[] =
{
  "none",
  "peer",
  "fail", /* fail_if_no_peer_cert */
  "once",
  NULL
};

/***
get verify_mode, return number mode and all string modes list
@function verify_mode
@treturn number mode_code
@return ...
  none: not verify client cert
  peer: verify client cert
  fail: if client not have cert, will failure
  once: verify client only once.
@usage
  mode = {ctx:verify_mode()}
  print('integer mode',mode[1])
  for i=2, #mode then
    print('string mode:'..mode[i])
  end
*/
/***
set ssl verify mode and callback
@function verify_mode
@tparam number mode, mode set to ctx, must be ssl.none or ssl.peer, and ssl.peer support combine with ssl.fail or ssl.once
@tparam[opt=nil] function ssl verify callback in lua function, not give will use default openssl callback, when mode is 'none', will be ignore this
verify_cb must be boolean function(verifyarg) prototype, return true to continue or false to end ssl handshake
verifyarg has field 'error', 'error_string','error_depth','current_cert', and 'preverify_ok'
@treturn boolean result
*/
static int openssl_ssl_ctx_verify_mode(lua_State*L)
{
  SSL_CTX* ctx = CHECK_OBJECT(1, SSL_CTX, "openssl.ssl_ctx");
  if (lua_gettop(L) > 1)
  {
    int mode = luaL_checkint(L, 2);
    luaL_argcheck(L,
                  mode == SSL_VERIFY_NONE ||
                  (mode & ~(SSL_VERIFY_PEER |
                            SSL_VERIFY_FAIL_IF_NO_PEER_CERT |
                            SSL_VERIFY_CLIENT_ONCE)) == 0,
                  2,
                  "must be none or peer(combined with fail, once or none");

    luaL_argcheck(L, lua_isnone(L, 3) || lua_isfunction(L, 3), 3, "must be callback function");

    if (lua_isfunction(L, 3))
    {
      lua_pushvalue(L, 3);
      openssl_valueset(L, ctx, "verify_cb");
      SSL_CTX_set_verify(ctx, mode, openssl_verify_cb);
    }
    else
    {
      lua_pushnil(L);
      openssl_valueset(L, ctx, "verify_cb");
      SSL_CTX_set_verify(ctx, mode, openssl_verify_cb);
    }
    return 0;
  }
  else
  {
    int i = 0;
    int mode = SSL_CTX_get_verify_mode(ctx);
    lua_pushinteger(L, mode);
    i += 1;

    if (mode ==  SSL_VERIFY_NONE)
    {
      lua_pushstring(L, "none");
      i += 1;
    }
    else
    {
      if (mode & SSL_VERIFY_PEER)
      {
        lua_pushstring(L, "peer");
        i += 1;

        if (mode & SSL_VERIFY_FAIL_IF_NO_PEER_CERT)
        {
          lua_pushstring(L, "fail");
          i += 1;
        }
        if (mode & SSL_VERIFY_CLIENT_ONCE)
        {
          lua_pushstring(L, "once");
          i += 1;
        }
      }
    }
    return i;
  }
}

/***
set certificate verify callback function
@function set_cert_verify
@tparam[opt] function cert_verify_cb with boolean function(verifyargs) prototype, if nil or none will use openssl default callback
verifyargs has field 'error', 'error_string','error_depth','current_cert'
*/
/***
set certificate verify options
@function set_cert_verify
@tparam table verify_cb_flag support field always_continue with boolean value and verify_depth with number value.
*/
static int openssl_ssl_ctx_set_cert_verify(lua_State*L)
{
  SSL_CTX* ctx = CHECK_OBJECT(1, SSL_CTX, "openssl.ssl_ctx");
  luaL_argcheck(L,
                lua_isnone(L, 2) || lua_isfunction(L, 2) || lua_istable(L, 2),
                2,
                "need function or table contains flags");
  if (lua_istable(L, 2))
  {
    lua_pushvalue(L, 2);
    openssl_valueset(L, ctx, "verify_cb_flags");
    SSL_CTX_set_cert_verify_callback(ctx, openssl_cert_verify_cb, L);
  }
  else if (lua_isfunction(L, 2))
  {
    lua_pushvalue(L, 2);
    openssl_valueset(L, ctx, "cert_verify_cb");
    SSL_CTX_set_cert_verify_callback(ctx, openssl_cert_verify_cb, L);
  }
  else
    SSL_CTX_set_cert_verify_callback(ctx, NULL, NULL);
  return 0;
}

#if OPENSSL_VERSION_NUMBER < 0x10100000L
static DH *tmp_dh_callback(SSL *ssl, int is_export, int keylength)
{
  DH *dh_tmp = NULL;
  SSL_CTX *ctx = SSL_get_SSL_CTX(ssl);
  lua_State *L = SSL_CTX_get_app_data(ctx);

  int type = openssl_valuegeti(L, ctx, SSL_CTX_TEMP_DH);
  if (type == LUA_TFUNCTION)
  {
    int ret;
    /* top is callback function */
    /* Invoke the callback */
    lua_pushboolean(L, is_export);
    lua_pushnumber(L, keylength);
    ret = lua_pcall(L, 2, 1, 0);
    if (ret == 0)
    {
      BIO *bio;
      /* Load parameters from returned value */
      if (lua_type(L, -1) != LUA_TSTRING)
      {
        lua_pop(L, 2);  /* Remove values from stack */
        return NULL;
      }
      bio = BIO_new_mem_buf((void*)lua_tostring(L, -1),
                            lua_rawlen(L, -1));
      if (bio)
      {
        dh_tmp = PEM_read_bio_DHparams(bio, NULL, NULL, NULL);
        BIO_free(bio);
      }
    }
    else
    {
      lua_error(L);
    }

    lua_pop(L, 2);    /* Remove values from stack */
    return dh_tmp;
  }
  lua_pop(L, 1);
  return NULL;
}

static RSA *tmp_rsa_callback(SSL *ssl, int is_export, int keylength)
{
  RSA *rsa_tmp = NULL;
  SSL_CTX *ctx = SSL_get_SSL_CTX(ssl);
  lua_State *L = SSL_CTX_get_app_data(ctx);
  int type = openssl_valuegeti(L, ctx, SSL_CTX_TEMP_RSA);
  if (type == LUA_TFUNCTION)
  {
    int ret;
    /* top is callback function */
    /* Invoke the callback */
    lua_pushboolean(L, is_export);
    lua_pushnumber(L, keylength);
    ret = lua_pcall(L, 2, 1, 0);
    if (ret == 0)
    {
      BIO *bio;
      /* Load parameters from returned value */
      if (lua_type(L, -1) != LUA_TSTRING)
      {
        lua_pop(L, 2);  /* Remove values from stack */
        return NULL;
      }
      bio = BIO_new_mem_buf((void*)lua_tostring(L, -1), lua_rawlen(L, -1));
      if (bio)
      {
        rsa_tmp = PEM_read_bio_RSAPrivateKey(bio, NULL, NULL, NULL);
        BIO_free(bio);
      }
    }
    else
    {
      lua_error(L);
    }

    lua_pop(L, 2);    /* Remove values from stack */
    return rsa_tmp;
  }
  lua_pop(L, 1);
  return NULL;
}

static EC_KEY *tmp_ecdh_callback(SSL *ssl, int is_export, int keylength)
{
  EC_KEY *ec_tmp = NULL;
  SSL_CTX *ctx = SSL_get_SSL_CTX(ssl);
  lua_State *L = SSL_CTX_get_app_data(ctx);
  int type = openssl_valuegeti(L, ctx, SSL_CTX_TEMP_ECDH);
  if (type == LUA_TFUNCTION)
  {
    int ret;
    /* top is callback function */
    /* Invoke the callback */
    lua_pushboolean(L, is_export);
    lua_pushnumber(L, keylength);
    ret = lua_pcall(L, 2, 1, 0);
    if (ret == 0)
    {
      BIO *bio;
      /* Load parameters from returned value */
      if (lua_type(L, -1) != LUA_TSTRING)
      {
        lua_pop(L, 2);  /* Remove values from stack */
        return NULL;
      }
      bio = BIO_new_mem_buf((void*)lua_tostring(L, -1),
                            lua_rawlen(L, -1));
      if (bio)
      {
        ec_tmp = PEM_read_bio_ECPrivateKey(bio, NULL, NULL, NULL);
        BIO_free(bio);
      }
    }
    else
    {
      lua_error(L);
    }

    lua_pop(L, 2);    /* Remove values from stack */
    return ec_tmp;
  }
  lua_pop(L, 1);
  return NULL;
}

/***
set temp callback
@function set_tmp
@tparam string keytype, 'dh','ecdh',or 'rsa'
@tparam function tmp_cb
@param[opt] vararg
*/
/***
set tmp key content pem format
@function set_tmp
@tparam string keytype, 'dh','ecdh',or 'rsa'
@tparam[opt] string private key file
*/

static int openssl_ssl_ctx_set_tmp(lua_State *L)
{
  SSL_CTX* ctx = CHECK_OBJECT(1, SSL_CTX, "openssl.ssl_ctx");
  static const char* which[] =
  {
    "dh",
    "rsa",
    "ecdh",
    NULL
  };

  int nwhich = luaL_checkoption(L, 2, "rsa", which);

  if (lua_isfunction(L, 3))
  {
    lua_pushvalue(L, 3);
    /* set callback function */
    switch (nwhich)
    {
    case 0:
      openssl_valueseti(L, ctx, SSL_CTX_TEMP_DH);
      SSL_CTX_set_tmp_dh_callback(ctx, tmp_dh_callback);
      break;
    case 1:
      openssl_valueseti(L, ctx, SSL_CTX_TEMP_RSA);
      SSL_CTX_set_tmp_rsa_callback(ctx, tmp_rsa_callback);
      break;
    case 2:
      openssl_valueseti(L, ctx, SSL_CTX_TEMP_ECDH);
      SSL_CTX_set_tmp_ecdh_callback(ctx, tmp_ecdh_callback);
    break;
    }
    lua_pushboolean(L, 1);
    return 1;
  }
  else if (lua_isuserdata(L, 3))
  {
    luaL_argerror(L, 3, "userdata arg NYI");
  }
  else
  {
    int ret;
    BIO* bio = lua_isstring(L, 3) ? load_bio_object(L, 3) : NULL;
    switch (nwhich)
    {
    case 0:
    {
      DH* dh = NULL;
      if (bio)
      {
        dh = PEM_read_bio_DHparams(bio, NULL, NULL, NULL);
        BIO_free(bio);
      } else
      {
        int bits = 1024;
        int generator = 2;
        dh = DH_new();
        ret = DH_generate_parameters_ex(dh, bits, generator, NULL);
        if (ret == 1)
        {
          ret = DH_generate_key(dh);
        }
        if (ret!=1)
        {
          DH_free(dh);
          dh = NULL;
        }
      }
      if (dh)
      {
        ret = SSL_CTX_set_tmp_dh(ctx, dh);
        if (ret)
          PUSH_OBJECT(dh, "openssl.dh");
        else
        {
          DH_free(dh);
          lua_pushnil(L);
        }
        return 1;
      }
      else
        luaL_error(L, "load or generate new tmp dh fail");
    }
    break;
    case 1:
    {
      RSA* rsa = NULL;
      if (bio)
      {
        rsa = PEM_read_bio_RSAPrivateKey(bio, NULL, NULL, NULL);
        BIO_free(bio);
      }
      else
      {
        BIGNUM *e = BN_new();
        rsa = RSA_new();
        BN_set_word(e, RSA_F4);
        ret = RSA_generate_key_ex(rsa, 2048, e, NULL);
        BN_free(e);
        if (ret!=0) {
          RSA_free(rsa);
          rsa = NULL;
        }
      }

      if (rsa)
      {
        ret = SSL_CTX_set_tmp_rsa(ctx, rsa);
        if (ret)
        {
          PUSH_OBJECT(rsa, "openssl.rsa");
        } else {
          RSA_free(rsa);
          lua_pushnil(L);
        }
        return 1;
      }
      else
        luaL_error(L, "load or generate new tmp rsa fail");
    }
    break;
    case 2:
    {
      int nid = NID_undef;
      EC_GROUP *g = NULL;
      EC_KEY* ec = NULL;

      if (lua_isstring(L, 3))
      {
        nid = OBJ_txt2nid(lua_tostring(L, 3));
        if (nid != NID_undef)
        {
          BIO_free(bio);
          bio = NULL;
        }
      }else
      {
        nid = OBJ_txt2nid("prime256v1");
      }
      if (nid != NID_undef)
        g = EC_GROUP_new_by_curve_name(nid);

      if (bio)
      {
        ec = PEM_read_bio_ECPrivateKey(bio, NULL, NULL, NULL);
        BIO_free(bio);
      } else if(g) {
        ec = EC_KEY_new();
        EC_KEY_set_group(ec, g);
        EC_GROUP_free(g);
        ret = EC_KEY_generate_key(ec);
        if (ret!=1)
        {
          EC_KEY_free(ec);
          ec = NULL;
        }
      }

      if (ec)
      {
        ret = SSL_CTX_set_tmp_ecdh(ctx, ec);
        if (ret)
        {
          PUSH_OBJECT(ec, "openssl.ec_key");
        } else {
          EC_KEY_free(ec);
          lua_pushnil(L);
        }
        return 1;
      }
      else
        luaL_error(L, "load or generate new tmp ec_key fail");
    }
    break;
    }
  }

  return openssl_pushresult(L, 0);
}
#endif

static int tlsext_servername_callback(SSL *ssl, int *ad, void *arg)
{
  SSL_CTX *newctx = NULL;
  SSL_CTX *ctx = SSL_get_SSL_CTX(ssl);
  lua_State *L = SSL_CTX_get_app_data(ctx);
  const char *name = SSL_get_servername(ssl, TLSEXT_NAMETYPE_host_name);
  (void) ad;
  (void) arg;
  /* No name, use default context */
  if (!name)
    return SSL_TLSEXT_ERR_NOACK;

  /* Search for the name in the map */
  openssl_valueget(L, ctx, "tlsext_servername");
  if (lua_istable(L, -1))
  {
    lua_getfield(L, -1, name);
    if (auxiliar_getclassudata(L, "openssl.ssl_ctx", -1))
    {
      newctx = CHECK_OBJECT(-1, SSL_CTX, "openssl.ssl_ctx");
      SSL_set_SSL_CTX(ssl, newctx);
      lua_pop(L, 2);
      return SSL_TLSEXT_ERR_OK;
    }
  }

  lua_pop(L, 1);
  return SSL_TLSEXT_ERR_ALERT_FATAL;
}

/***
set servername callback
@function set_servefrname_callback
@todo
*/
static int openssl_ssl_ctx_set_servername_callback(lua_State*L)
{
  SSL_CTX* ctx = CHECK_OBJECT(1, SSL_CTX, "openssl.ssl_ctx");
  luaL_argcheck(L, lua_istable(L, 2) || lua_isfunction(L, 2), 2, "must be table or function");

  lua_pushvalue(L, 2);
  openssl_valueset(L, ctx, "tlsext_servername");
  SSL_CTX_set_tlsext_servername_callback(ctx, tlsext_servername_callback);
  return 0;
}

/***
set session callback
@function set_session_callback
@tparam function new
@tparam function get
@tparam function remove
*/

static int openssl_add_session(SSL *ssl, SSL_SESSION *session)
{
  int ret;
  SSL_CTX *ctx = SSL_get_SSL_CTX(ssl);
  lua_State *L = SSL_CTX_get_app_data(ctx);

  openssl_valuegeti(L, ctx, SSL_CTX_SESSION_ADD);
  SSL_up_ref(ssl);
  PUSH_OBJECT(ssl, "openssl.ssl");
  openssl_newvalue(L, ssl);
  PUSH_OBJECT(session, "openssl.ssl_session");

  ret = lua_pcall(L, 2, 1, 0);
  if (ret != LUA_OK)
  {
    fprintf(stderr, "add session callback error: %s\n", lua_tostring(L, -1));
    ret = 0;
  }
  else
    ret = lua_isboolean(L, -1) ? lua_toboolean(L, -1) : lua_tointeger(L, -1);

  lua_pop(L, 1);
  return ret;
}

static SSL_SESSION *openssl_get_session(SSL *ssl,
                                        CONSTIFY_OPENSSL unsigned char *id,
                                        int idlen, int *do_copy)
{
  int ret;
  SSL_CTX *ctx = SSL_get_SSL_CTX(ssl);
  lua_State *L = SSL_CTX_get_app_data(ctx);
  SSL_SESSION *session = NULL;

  openssl_valuegeti(L, ctx, SSL_CTX_SESSION_GET);
  SSL_up_ref(ssl);
  PUSH_OBJECT(ssl, "openssl.ssl");
  openssl_newvalue(L, ssl);
  lua_pushlstring(L, (const char*)id, idlen);

  ret = lua_pcall(L, 2, 1, 0);
  if (ret != LUA_OK)
  {
    fprintf(stderr, "get session callback error: %s\n", lua_tostring(L, -1));
    lua_pop(L, 1);
    return NULL;
  }
  if (lua_isstring(L, -1))
  {
    size_t size = 0;
    const unsigned char* p = (const unsigned char*)lua_tolstring(L, -1, &size);
    *do_copy = 0;
    session = d2i_SSL_SESSION(NULL, &p, (int)size);
  }
  else if ((session = GET_OBJECT(-1, SSL_SESSION, "openssl.ssl_session")) != NULL)
  {
    *do_copy = 1;
  }
  else if (lua_type(L, -1) != LUA_TNIL) {
    fprintf(stderr, "get session callback return unaccpet value: (type=%s)%s\n",
            luaL_typename(L, -1),lua_tostring(L, -1));
  }
  lua_pop(L, 1);
  return session;
}

static void openssl_del_session(SSL_CTX *ctx, SSL_SESSION *session)
{
  int ret;
  unsigned int len = 0;;
  const unsigned char* id = NULL;
  lua_State *L = SSL_CTX_get_app_data(ctx);

  openssl_valuegeti(L, ctx, SSL_CTX_SESSION_DEL);

  id = SSL_SESSION_get_id(session, &len);
  lua_pushlstring(L, (const char*)id, len);

  ret = lua_pcall(L, 1, 0, 0);
  if (ret != LUA_OK)
  {
    fprintf(stderr, "del session callback error: %s\n", lua_tostring(L, -1));
    lua_pop(L, 1);
  }
}

static int openssl_ssl_ctx_set_session_callback(lua_State*L)
{
  SSL_CTX* ctx = CHECK_OBJECT(1, SSL_CTX, "openssl.ssl_ctx");
  if (!lua_isnoneornil(L, 2))
  {
    luaL_checktype(L, 2, LUA_TFUNCTION);
    lua_pushvalue(L, 2);
    openssl_valueseti(L, ctx, SSL_CTX_SESSION_ADD);
    SSL_CTX_sess_set_new_cb(ctx, openssl_add_session);
  }
  if (!lua_isnoneornil(L, 3))
  {
    luaL_checktype(L, 3, LUA_TFUNCTION);
    lua_pushvalue(L, 3);
    openssl_valueseti(L, ctx, SSL_CTX_SESSION_GET);
    SSL_CTX_sess_set_get_cb(ctx, openssl_get_session);
  }
  if (!lua_isnoneornil(L, 4))
  {
    luaL_checktype(L, 4, LUA_TFUNCTION);
    lua_pushvalue(L, 4);
    openssl_valueseti(L, ctx, SSL_CTX_SESSION_DEL);
    SSL_CTX_sess_set_remove_cb(ctx, openssl_del_session);
  }
  lua_pushvalue(L, 1);
  return 1;
}

/***
flush sessions
@function flush
*/
static int openssl_ssl_ctx_flush_sessions(lua_State*L)
{
  SSL_CTX* ctx = CHECK_OBJECT(1, SSL_CTX, "openssl.ssl_ctx");
  long tm = luaL_checkinteger(L, 2);
  SSL_CTX_flush_sessions(ctx, tm);
  return 0;
}

/***
set ssl session
@function sessions
*/
static int openssl_ssl_ctx_sessions(lua_State*L)
{
  SSL_CTX* ctx = CHECK_OBJECT(1, SSL_CTX, "openssl.ssl_ctx");
  if (lua_isstring(L, 2))
  {
    size_t s;
    unsigned char* sid_ctx = (unsigned char*)luaL_checklstring(L, 2, &s);
    int ret = SSL_CTX_set_session_id_context(ctx, sid_ctx, s);
    return openssl_pushresult(L, ret);
  }
  else
  {
    SSL_SESSION *s = CHECK_OBJECT(2, SSL_SESSION, "openssl.ssl_session");
    int add = lua_isnone(L, 3) ? 1 : auxiliar_checkboolean(L, 3);

    if (add)
      add = SSL_CTX_add_session(ctx, s);
    else
      add = SSL_CTX_remove_session(ctx, s);
    return openssl_pushresult(L, add);
  }
}

/***
get current session cache mode
@function session_cache_mode
@treturn table modes as array, mode is 'no_auto_clear','server','client','both','off'
*/

/***
set session cache mode,and return old mode
@function session_cache_mode
@tparam string mode support 'no_auto_clear','server','client','both','off',
'no_auto_clear' can be combine with others, so accept one or two param.
*/
static int openssl_session_cache_mode(lua_State *L)
{
  static const char* smode[] =
  {
    "off",
    "client",
    "server",
    "both",
    "no_auto_clear",
    "no_internal_lookup",
    "no_internal_store",
    "no_internal",
    NULL
  };
  static const int imode[] =
  {
    SSL_SESS_CACHE_OFF,
    SSL_SESS_CACHE_CLIENT,
    SSL_SESS_CACHE_SERVER,
    SSL_SESS_CACHE_BOTH,
    SSL_SESS_CACHE_NO_AUTO_CLEAR,
    SSL_SESS_CACHE_NO_INTERNAL_LOOKUP,
    SSL_SESS_CACHE_NO_INTERNAL_STORE,
    SSL_SESS_CACHE_NO_INTERNAL,
    -1
  };

  SSL_CTX* ctx = CHECK_OBJECT(1, SSL_CTX, "openssl.ssl_ctx");
  int n = lua_gettop(L);
  long mode = 0;
  int i;
  if (n > 1)
  {
    if (lua_isnumber(L, 2))
    {
      mode = luaL_checkinteger(L, 2);
      mode = SSL_CTX_set_session_cache_mode(ctx, mode);
    }
    else
    {
      for (i = 2; i <= n; i++)
      {
        int j = auxiliar_checkoption(L, i, NULL, smode, imode);
        mode |= j;
      }
      mode = SSL_CTX_set_session_cache_mode(ctx, mode);
    }
  }
  else
  {
    mode = SSL_CTX_get_session_cache_mode(ctx);
  };

  lua_newtable(L);
  i = 0;
  if (mode == SSL_SESS_CACHE_OFF )
  {
    lua_pushstring(L, "off");
    lua_rawseti(L, -2, ++i);
  }
  else
  {
    if (mode & SSL_SESS_CACHE_NO_AUTO_CLEAR)
    {
      lua_pushstring(L, "no_auto_clear");
      lua_rawseti(L, -2, ++i);
    }
    if ((mode & SSL_SESS_CACHE_BOTH)==SSL_SESS_CACHE_BOTH)
    {
      lua_pushstring(L, "both");
      lua_rawseti(L, -2, ++i);
    }
    else if (mode & SSL_SESS_CACHE_SERVER)
    {
      lua_pushstring(L, "server");
      lua_rawseti(L, -2, ++i);
    }
    else if (mode & SSL_SESS_CACHE_CLIENT)
    {
      lua_pushstring(L, "client");
      lua_rawseti(L, -2, ++i);
    }
    if ((mode & SSL_SESS_CACHE_NO_INTERNAL)==SSL_SESS_CACHE_NO_INTERNAL)
    {
      lua_pushstring(L, "no_internal");
      lua_rawseti(L, -2, ++i);
    }
    else if (mode & SSL_SESS_CACHE_NO_INTERNAL_LOOKUP)
    {
      lua_pushstring(L, "no_internal_lookup");
      lua_rawseti(L, -2, ++i);
    }
    else if (mode & SSL_SESS_CACHE_NO_INTERNAL_STORE)
    {
      lua_pushstring(L, "no_internal_store");
      lua_rawseti(L, -2, ++i);
    }
  }

  return 1;
}

#if OPENSSL_VERSION_NUMBER > 0x1010100FL && !defined(LIBRESSL_VERSION_NUMBER)
static int openssl_ssl_ctx_num_tickets(lua_State*L)
{
  SSL_CTX* ctx = CHECK_OBJECT(1, SSL_CTX, "openssl.ssl_ctx");
  size_t num;
  if (!lua_isnone(L, 2))
  {
    num = luaL_checkinteger(L, 2);
    SSL_CTX_set_num_tickets(ctx, num);
  }
  else
    num = SSL_CTX_get_num_tickets(ctx);

  lua_pushinteger(L, num);
  return 1;
}
#endif

#ifdef SSL_CTX_EXT_DEFINE
SSL_CTX_EXT_DEFINE
#endif

static luaL_Reg ssl_ctx_funcs[] =
{
  {"ssl",             openssl_ssl_ctx_new_ssl},
  {"bio",             openssl_ssl_ctx_new_bio},
#ifndef SSL_CTX_USE_EXT
  {"use",             openssl_ssl_ctx_use},
#else
  SSL_CTX_USE_EXT
#endif
  {"add",             openssl_ssl_ctx_add},
  {"mode",            openssl_ssl_ctx_mode},
  {"timeout",         openssl_ssl_ctx_timeout},
  {"options",         openssl_ssl_ctx_options},
#if OPENSSL_VERSION_NUMBER > 0x10100000L
  {"version",         openssl_ssl_ctx_version},
#endif
#if OPENSSL_VERSION_NUMBER > 0x1010100FL && !defined(LIBRESSL_VERSION_NUMBER)
  {"num_tickets",     openssl_ssl_ctx_num_tickets},
#endif
  {"quiet_shutdown",  openssl_ssl_ctx_quiet_shutdown},
  {"verify_locations", openssl_ssl_ctx_load_verify_locations},
  {"cert_store",      openssl_ssl_ctx_cert_store},
#ifndef OPENSSL_NO_ENGINE
  {"set_engine",      openssl_ssl_ctx_set_engine},
#endif
  {"verify_mode",     openssl_ssl_ctx_verify_mode},
  {"set_cert_verify", openssl_ssl_ctx_set_cert_verify},

  {"verify_depth",    openssl_ssl_ctx_verify_depth},
#if OPENSSL_VERSION_NUMBER < 0x10100000L
  {"set_tmp",         openssl_ssl_ctx_set_tmp},
#endif
  {"flush_sessions",  openssl_ssl_ctx_flush_sessions},
  {"session",         openssl_ssl_ctx_sessions},
  {"session_cache_mode",        openssl_session_cache_mode},
  {"set_session_callback",      openssl_ssl_ctx_set_session_callback},
  {"set_servername_callback",   openssl_ssl_ctx_set_servername_callback},

  {"__gc",            openssl_ssl_ctx_gc},
  {"__tostring",      auxiliar_tostring},

  {NULL,      NULL},
};

/****************************SSL SESSION********************************/
/***
get peer certificate verify result
@function getpeerverification
@treturn boolean true for success
@treturn table all certificate in chains verify result
 preverify_ok as boolean verify result
 error as number error code
 error_string as string error message
 error_depth as number verify depth
 current_cert as x509 certificate to verified
*/
static int openssl_ssl_getpeerverification(lua_State *L)
{
  long err;
  SSL* ssl = CHECK_OBJECT(1, SSL, "openssl.ssl");

  err = SSL_get_verify_result(ssl);
  lua_pushboolean(L, err == X509_V_OK);
  openssl_valueget(L, ssl, "verify_cert");
  return 2;
}

static int openssl_ssl_session_time(lua_State*L)
{
  SSL_SESSION* session = CHECK_OBJECT(1, SSL_SESSION, "openssl.ssl_session");
  int time;
  if (!lua_isnone(L, 2))
  {
    time = luaL_checklong(L, 2);
    time = SSL_SESSION_set_time(session, time);
    lua_pushinteger(L, time);
    return 1;
  }
  time = SSL_SESSION_get_time(session);
  lua_pushinteger(L, time);
  return 1;
}


static int openssl_ssl_session_timeout(lua_State*L)
{
  SSL_SESSION* session = CHECK_OBJECT(1, SSL_SESSION, "openssl.ssl_session");
  int time;
  if (!lua_isnone(L, 2))
  {
    time = luaL_checkint(L, 2);
    time = SSL_SESSION_set_timeout(session, time);
    lua_pushinteger(L, time);
    return 1;
  }
  time = SSL_SESSION_get_timeout(session);
  lua_pushinteger(L, time);
  return 1;
}

static int openssl_ssl_session_gc(lua_State*L)
{
  SSL_SESSION* session = CHECK_OBJECT(1, SSL_SESSION, "openssl.ssl_session");
  SSL_SESSION_free(session);
  return 0;
}

#if OPENSSL_VERSION_NUMBER > 0x10000000L
static int openssl_ssl_session_peer(lua_State*L)
{
  SSL_SESSION* session = CHECK_OBJECT(1, SSL_SESSION, "openssl.ssl_session");
  X509 *x = SSL_SESSION_get0_peer(session);
  X509_up_ref(x);
  PUSH_OBJECT(x, "openssl.x509");
  return 1;
}
#endif

static int openssl_ssl_session_id(lua_State*L)
{
  CONSTIFY_OPENSSL
  SSL_SESSION* session = CHECK_OBJECT(1, SSL_SESSION, "openssl.ssl_session");

  if (lua_isnone(L, 2))
  {
    unsigned int len;
    const unsigned char* id = SSL_SESSION_get_id(session, &len);
    lua_pushlstring(L, (const char*)id, len);
    return 1;
  }
  else
  {
#if OPENSSL_VERSION_NUMBER > 0x10100000L
    size_t len;
    const char* id = luaL_checklstring(L, 2, &len);
    int ret = SSL_SESSION_set1_id((SSL_SESSION*)session, (const unsigned char*)id, len);
    lua_pushboolean(L, ret);
#else
    lua_pushnil(L);
#endif
    return 1;
  }
}

#if OPENSSL_VERSION_NUMBER > 0x10000000L
static int openssl_ssl_session_compress_id(lua_State*L)
{
  SSL_SESSION* session = CHECK_OBJECT(1, SSL_SESSION, "openssl.ssl_session");
  unsigned int id  = SSL_SESSION_get_compress_id(session);
  lua_pushinteger(L, id);
  return 1;
}
#endif

static int openssl_ssl_session_export(lua_State*L)
{
  SSL_SESSION* session = CHECK_OBJECT(1, SSL_SESSION, "openssl.ssl_session");
  int pem = lua_isnone(L, 2) ? 1 : auxiliar_checkboolean(L, 2);
  BIO* bio = BIO_new(BIO_s_mem());
  BUF_MEM *bio_buf;
  if (pem)
  {
    PEM_write_bio_SSL_SESSION(bio, session);
  }
  else
  {
    i2d_SSL_SESSION_bio(bio, session);
  }

  BIO_get_mem_ptr(bio, &bio_buf);
  lua_pushlstring(L, bio_buf->data, bio_buf->length);
  BIO_free(bio);
  return 1;
}

#if OPENSSL_VERSION_NUMBER > 0x10101000L && !defined(LIBRESSL_VERSION_NUMBER)
static int openssl_ssl_session_is_resumable(lua_State*L)
{
  SSL_SESSION* session = CHECK_OBJECT(1, SSL_SESSION, "openssl.ssl_session");
  int ret = SSL_SESSION_is_resumable(session);
  lua_pushboolean(L, ret);
  return 1;
}
#endif

#if OPENSSL_VERSION_NUMBER > 0x10100000L
static int openssl_ssl_session_has_ticket(lua_State*L)
{
  SSL_SESSION* session = CHECK_OBJECT(1, SSL_SESSION, "openssl.ssl_session");
  int ret = SSL_SESSION_has_ticket(session);
  lua_pushboolean(L, ret);
  return 1;
}
#endif

static luaL_Reg ssl_session_funcs[] =
{
  {"id",            openssl_ssl_session_id},
  {"time",          openssl_ssl_session_time},
  {"timeout",       openssl_ssl_session_timeout},
#if OPENSSL_VERSION_NUMBER > 0x10000000L
  {"compress_id",   openssl_ssl_session_compress_id},
  {"peer",          openssl_ssl_session_peer},
#endif
  {"export",        openssl_ssl_session_export},
#if OPENSSL_VERSION_NUMBER > 0x10101000L && !defined(LIBRESSL_VERSION_NUMBER)
  {"is_resumable",  openssl_ssl_session_is_resumable},
#endif
#if OPENSSL_VERSION_NUMBER > 0x10100000L
  {"has_ticket",    openssl_ssl_session_has_ticket},
#endif

  {"__gc",          openssl_ssl_session_gc},
  {"__tostring",    auxiliar_tostring},

  {NULL,      NULL},
};


/***************************SSL**********************************/
/***
openssl.ssl object
All SSL object IO operation methods(connect, accept, handshake, read,
peek or write) return nil or false when fail or error.
When nil returned, it followed by 'ssl' or 'syscall', means SSL layer or
system layer error. When false returned, it followed by number 0,
'want_read','want_write','want_x509_lookup','want_connect','want_accept'.
Numnber 0 means SSL connection closed, others means you should do some
SSL operation.
@type ssl
*/

/***
reset ssl object to allow another connection
@function clear
@treturn boolean result true for success
*/
static int openssl_ssl_clear(lua_State*L)
{
  SSL* s = CHECK_OBJECT(1, SSL, "openssl.ssl");
  lua_pushboolean(L, SSL_clear(s));
  return 1;
}

/***
tell ssl use private key and certificate, and check private key
@function use
@tparam evp_pkey pkey
@tparam[opt] x509 cert
@treturn boolean result return true for ok, or nil followed by errmsg and errval
*/
static int openssl_ssl_use(lua_State*L)
{
  SSL* s = CHECK_OBJECT(1, SSL, "openssl.ssl");
  X509* x = CHECK_OBJECT(2, X509, "openssl.x509");
  EVP_PKEY* pkey = CHECK_OBJECT(3, EVP_PKEY, "openssl.evp_pkey");
  int ret;

  ret = SSL_use_PrivateKey(s, pkey);
  if (ret == 1)
  {
    ret = SSL_use_certificate(s, x);
    if (ret == 1)
    {
      ret = SSL_check_private_key(s);
    }
  }
  return openssl_pushresult(L, ret);
}

/***
get peer certificate and certificate chains
@function peer
@treturn[1] x509 certificate
@treturn[1] sk_of_x509 chains of peer
*/
static int openssl_ssl_peer(lua_State*L)
{
  SSL* s = CHECK_OBJECT(1, SSL, "openssl.ssl");
  X509* x = SSL_get_peer_certificate(s);
  STACK_OF(X509) *sk = SSL_get_peer_cert_chain(s);
  PUSH_OBJECT(x, "openssl.x509");
  if (sk)
  {
    openssl_sk_x509_totable(L, sk);
    return 2;
  }
  return 1;
}

static int openssl_ssl_gc(lua_State*L)
{
  SSL* s = CHECK_OBJECT(1, SSL, "openssl.ssl");
  SSL_free(s);
  openssl_freevalue(L, s);

  return 0;
}

/***
get want to do
@function want
@treturn[1] string 'nothing', 'reading', 'writing', 'x509_lookup'
@treturn[1] number state want
*/
static int openssl_ssl_want(lua_State*L)
{
  SSL* s = CHECK_OBJECT(1, SSL, "openssl.ssl");
  int st = SSL_want(s);
  const char* state = NULL;
  if (st == SSL_NOTHING)
    state = "nothing";
  else if (st == SSL_READING)
    state = "reading";
  else if (st == SSL_WRITING)
    state = "writing";
  else if (st == SSL_X509_LOOKUP)
    state = "x509_lookup";

  lua_pushstring(L, state);
  lua_pushinteger(L, st);
  return 2;
}
#if !defined(OPENSSL_NO_COMP)
/***
get current compression name
@function current_compression
@treturn string
*/
static int openssl_ssl_current_compression(lua_State *L)
{
  SSL* s = CHECK_OBJECT(1, SSL, "openssl.ssl");
  const COMP_METHOD *comp = SSL_get_current_compression(s);
  if (comp)
    lua_pushstring(L, SSL_COMP_get_name(comp));
  else
    lua_pushnil(L);
  return 1;
}
#endif

/***
get current cipher info
@function current_cipher
@treturn table include name,version,id,bits,algbits and description
*/
static int openssl_ssl_current_cipher(lua_State *L)
{
  SSL* s = CHECK_OBJECT(1, SSL, "openssl.ssl");
  const SSL_CIPHER* c = SSL_get_current_cipher(s);
  if (c)
  {
    int bits, algbits;
    char err[LUAL_BUFFERSIZE] = {0};

    lua_newtable(L);

    AUXILIAR_SET(L, -1, "name",     SSL_CIPHER_get_name(c), string);
    AUXILIAR_SET(L, -1, "version",  SSL_CIPHER_get_version(c), string);

#if OPENSSL_VERSION_NUMBER > 0x10000000L
    AUXILIAR_SET(L, -1, "id", SSL_CIPHER_get_id(c), integer);
#endif
    bits = SSL_CIPHER_get_bits(c, &algbits);
    AUXILIAR_SET(L, -1, "bits", bits, integer);
    AUXILIAR_SET(L, -1, "algbits", algbits, integer);

    AUXILIAR_SET(L, -1, "description", SSL_CIPHER_description((SSL_CIPHER*)c, err, sizeof(err)), string);

    return 1;
  }
  return 0;
}

/***
get number of bytes available inside SSL fro immediate read
@function pending
@treturn number
*/
static int openssl_ssl_pending(lua_State*L)
{
  SSL* s = CHECK_OBJECT(1, SSL, "openssl.ssl");
  lua_pushinteger(L, SSL_pending(s));
  return 1;
}

/*********************************************/
static int openssl_ssl_pushresult(lua_State* L, SSL*ssl, int ret_code)
{
  int err = SSL_get_error(ssl, ret_code);
  switch (err)
  {
  case SSL_ERROR_NONE:
    lua_pushboolean(L, 1);
    lua_pushinteger(L, ret_code);
    break;
  case SSL_ERROR_ZERO_RETURN:
    lua_pushboolean(L, 0);
    lua_pushinteger(L, 0);
    break;
  case SSL_ERROR_SSL:
    lua_pushnil(L);
    lua_pushstring(L, "ssl");
    break;
  case SSL_ERROR_WANT_READ:
    lua_pushboolean(L, 0);
    lua_pushstring(L, "want_read");
    break;
  case SSL_ERROR_WANT_WRITE:
    lua_pushboolean(L, 0);
    lua_pushstring(L, "want_write");
    break;
  case SSL_ERROR_WANT_X509_LOOKUP:
    lua_pushboolean(L, 0);
    lua_pushstring(L, "want_x509_lookup");
    break;
  case SSL_ERROR_SYSCALL:
    lua_pushnil(L);
    lua_pushstring(L, "syscall");
    break;
  case SSL_ERROR_WANT_CONNECT:
    lua_pushboolean(L, 0);
    lua_pushstring(L, "want_connect");
    break;
  case SSL_ERROR_WANT_ACCEPT:
    lua_pushboolean(L, 0);
    lua_pushstring(L, "want_accept");
    break;
  default:
    return 0;
  }
  return 2;
}

/***
get socket fd of ssl
@function getfd
@treturn number fd
*/
static int openssl_ssl_getfd(lua_State*L)
{
  SSL* s = CHECK_OBJECT(1, SSL, "openssl.ssl");
  lua_pushinteger(L, SSL_get_fd(s));
  return 1;
}

/***
check SSL is a server
@function is_server
@treturn boolean is_server
*/
static int openssl_ssl_is_server(lua_State*L)
{
  SSL* s = CHECK_OBJECT(1, SSL, "openssl.ssl");
  lua_pushboolean(L, SSL_is_server(s));
  return 1;
}

/***
get value according to arg
@function get
@tparam string arg
 <br/>certificate:  return SSL certificates
 <br/>fd: return file or network connect fd
 <br/>rfd:
 <br/>wfd:
 <br/>client_CA_list
 <br/>read_ahead: -> boolean
 <br/>shared_ciphers: string
 <br/>cipher_list -> string
 <br/>verify_mode: number
 <br/>verify_depth
 <br/>state_string
 <br/>state_string_long
 <br/>rstate_string
 <br/>rstate_string_long
 <br/>iversion
 <br/>version
 <br/>default_timeout,
 <br/>certificate
 <br/>verify_result
 <br/>state
 <br/>hostname
 <br/>state_string
 <br/>side
@return according to arg
*/
static int openssl_ssl_get(lua_State*L)
{
  SSL* s = CHECK_OBJECT(1, SSL, "openssl.ssl");
  int i;
  int top = lua_gettop(L);
  for (i = 2; i <= top; i++)
  {
    const char* what = luaL_checklstring(L, i, NULL);
    if (strcmp(what, "fd") == 0)
    {
      lua_pushinteger(L, SSL_get_fd(s));
    }
    else if (strcmp(what, "rfd") == 0)
    {
      lua_pushinteger(L, SSL_get_rfd(s));
    }
    else if (strcmp(what, "wfd") == 0)
    {
      lua_pushinteger(L, SSL_get_wfd(s));
    }
    else if (strcmp(what, "client_CA_list") == 0)
    {
      STACK_OF(X509_NAME)* sn = SSL_get_client_CA_list(s);
      openssl_sk_x509_name_totable(L, sn);
    }
    else if (strcmp(what, "read_ahead") == 0)
    {
      lua_pushboolean(L, SSL_get_read_ahead(s));
    }
    else if (strcmp(what, "shared_ciphers") == 0)
    {
      char buf[LUAL_BUFFERSIZE] = {0};
      lua_pushstring(L, SSL_get_shared_ciphers(s, buf, sizeof(buf)));
    }
    else if (strcmp(what, "cipher_list") == 0)
    {
      lua_pushstring(L, SSL_get_cipher_list(s, 0));
    }
    else if (strcmp(what, "verify_mode") == 0)
    {
      lua_pushinteger(L, SSL_get_verify_mode(s));
    }
    else if (strcmp(what, "verify_depth") == 0)
    {
      lua_pushinteger(L, SSL_get_verify_depth(s));
    }
    else if (strcmp(what, "state_string") == 0)
    {
      lua_pushstring(L, SSL_state_string(s));
    }
    else if (strcmp(what, "state_string_long") == 0)
    {
      lua_pushstring(L, SSL_state_string_long(s));
    }
    else if (strcmp(what, "rstate_string") == 0)
    {
      lua_pushstring(L, SSL_rstate_string(s));
    }
    else if (strcmp(what, "rstate_string_long") == 0)
    {
      lua_pushstring(L, SSL_rstate_string_long(s));
    }
    else if (strcmp(what, "version") == 0)
    {
      lua_pushstring(L, SSL_get_version(s));
    }
    else if (strcmp(what, "iversion") == 0)
    {
      lua_pushinteger(L, SSL_version(s));
    }
    else if (strcmp(what, "default_timeout") == 0)
    {
      lua_pushinteger(L, SSL_get_default_timeout(s));
    }
    else if (strcmp(what, "certificate") == 0)
    {
      X509* cert = SSL_get_certificate(s);
      if (cert)
      {
        X509_up_ref(cert);
        PUSH_OBJECT(cert, "openssl.x509");
      }
      else
        lua_pushnil(L);
    }
    else if (strcmp(what, "verify_result") == 0)
    {
      long l = SSL_get_verify_result(s);
      lua_pushinteger(L, l);
    }
    else if (strcmp(what, "state") == 0)
    {
      lua_pushinteger(L, SSL_get_state(s));
    }
    else if (strcmp(what, "hostname") == 0)
    {
      lua_pushstring(L, SSL_get_servername(s, TLSEXT_NAMETYPE_host_name));
    }
    else if (strcmp(what, "side") == 0)
    {
      lua_pushstring(L, SSL_is_server(s) ? "server" : "client");
    }
    else
      luaL_argerror(L, i, "can't understant");
  }
  return top - 1;
}

/***
set value according to arg
@function set
@tparam string arg
 <br/>certificate:  return SSL certificates
 <br/>fd: return file or network connect fd
 <br/>rfd:
 <br/>wfd:
 <br/>client_CA:
 <br/>read_ahead:
 <br/>cipher_list:
 <br/>verify_depth:
 <br/>purpose:
 <br/>trust:
 <br/>verify_result:
 <br/>hostname:
@param value val type accroding to arg
@return value
*/
static int openssl_ssl_set(lua_State*L)
{
  SSL* s = CHECK_OBJECT(1, SSL, "openssl.ssl");
  int i;
  int top = lua_gettop(L);
  int ret = 1;
  for (i = 2; i <= top; i += 2)
  {
    const char* what = luaL_checklstring(L, i, NULL);
    if (strcmp(what, "fd") == 0)
    {
      ret = SSL_set_fd(s, luaL_checkint(L, i + 1));
    }
    else if (strcmp(what, "rfd") == 0)
    {
      ret = SSL_set_wfd(s, luaL_checkint(L, i + 1));
    }
    else if (strcmp(what, "wfd") == 0)
    {
      ret = SSL_set_wfd(s, luaL_checkint(L, i + 1));
    }
    else if (strcmp(what, "client_CA") == 0)
    {
      X509* x = CHECK_OBJECT(i + 1, X509, "openssl.x509");
      ret = SSL_add_client_CA(s, x);
    }
    else if (strcmp(what, "read_ahead") == 0)
    {
      int yes = auxiliar_checkboolean(L, i + 1);
      SSL_set_read_ahead(s, yes);
    }
    else if (strcmp(what, "cipher_list") == 0)
    {
      const char* list = lua_tostring(L, i + 1);
      ret = SSL_set_cipher_list(s, list);
    }
    else if (strcmp(what, "verify_depth") == 0)
    {
      int depth = luaL_checkint(L, i + 1);
      SSL_set_verify_depth(s, depth);
    }
    else if (strcmp(what, "purpose") == 0)
    {
      int purpose = luaL_checkint(L, i + 1);
      ret = SSL_set_purpose(s, purpose);
    }
    else if (strcmp(what, "trust") == 0)
    {
      int trust = luaL_checkint(L, i + 1);
      ret = SSL_set_trust(s, trust);
    }
    else if (strcmp(what, "verify_result") == 0)
    {
      int result = luaL_checkint(L, i + 1);
      SSL_set_verify_result(s, result);
    }
    else if (strcmp(what, "hostname") == 0)
    {
      const char* hostname = luaL_checkstring(L, i + 1);
      SSL_set_tlsext_host_name(s, hostname);
    }
    else
      luaL_argerror(L, i, "don't understand");

    if (ret != 1)
      return openssl_pushresult(L, ret);
  }
  return 0;
}

/***
do ssl server accept
@function accept
@treturn boolean true for success
@treturn string fail reason
*/
static int openssl_ssl_accept(lua_State*L)
{
  SSL* s = CHECK_OBJECT(1, SSL, "openssl.ssl");
  int ret = SSL_accept(s);
  return openssl_ssl_pushresult(L, s, ret);
}

/***
do ssl client connect
@function connect
@treturn boolean true for success
@treturn string fail reasion
*/
static int openssl_ssl_connect(lua_State*L)
{
  SSL* s = CHECK_OBJECT(1, SSL, "openssl.ssl");
  int ret = SSL_connect(s);
  return openssl_ssl_pushresult(L, s, ret);
}

/***
do ssl read
@function read
@tparam[opt=4096] number length to read
@treturn string data, nil or false for fail
@treturn string fail reason
*/
static int openssl_ssl_read(lua_State*L)
{
  SSL* s = CHECK_OBJECT(1, SSL, "openssl.ssl");
  int num = luaL_optint(L, 2, SSL_pending(s));
  void* buf;
  int ret;
  num = num ? num : 4096;
  buf = malloc(num);
  ret = SSL_read(s, buf, num);
  if (ret > 0)
  {
    lua_pushlstring(L, buf, ret);
    ret =  1;
  }
  else
  {
    ret = openssl_ssl_pushresult(L, s, ret);
  }
  free(buf);
  return ret;
}

/***
do ssl peak, data can be read again
@function peek
@tparam[opt=4096] number length to read
@treturn string data, nil or false for fail
@treturn string fail reason
*/
static int openssl_ssl_peek(lua_State*L)
{
  SSL* s = CHECK_OBJECT(1, SSL, "openssl.ssl");
  int num = luaL_optint(L, 2, SSL_pending(s));
  void* buf;
  int ret;

  num = num ? num : 4096;
  buf = malloc(num);
  ret = SSL_peek(s, buf, num);
  if (ret > 0)
  {
    lua_pushlstring(L, buf, ret);
    ret = 1;
  }
  else
  {
    ret = openssl_ssl_pushresult(L, s, ret);
  }
  free(buf);
  return ret;
}

/***
do ssl write
@function write
@tparam string data
@treturn number count of bytes write successfully
@treturn string fail reason
*/
static int openssl_ssl_write(lua_State*L)
{
  SSL* s = CHECK_OBJECT(1, SSL, "openssl.ssl");
  size_t size;
  const char* buf = luaL_checklstring(L, 2, &size);
  int ret = SSL_write(s, buf, size);
  if (ret > 0)
  {
    lua_pushinteger(L, ret);
    return 1;
  }
  else
  {
    return openssl_ssl_pushresult(L, s, ret);
  }
}

/***
do ssl handshake, support both server and client side
@function handshake
@treturn boolean true for success
@treturn string fail reasion
*/
static int openssl_ssl_do_handshake(lua_State*L)
{
  SSL* s = CHECK_OBJECT(1, SSL, "openssl.ssl");
  int ret = SSL_do_handshake(s);
  return openssl_ssl_pushresult(L, s, ret);
}

/***
do ssl renegotiate
@function renegotiate
@treturn boolean true for success
@treturn string fail reasion
*/
static int openssl_ssl_renegotiate(lua_State*L)
{
  SSL* s = CHECK_OBJECT(1, SSL, "openssl.ssl");
  int ret = SSL_renegotiate(s);
  return openssl_ssl_pushresult(L, s, ret);
}

#if OPENSSL_VERSION_NUMBER > 0x10000000L
static int openssl_ssl_renegotiate_abbreviated(lua_State*L)
{
  SSL* s = CHECK_OBJECT(1, SSL, "openssl.ssl");
  int ret = SSL_renegotiate_abbreviated(s);
  return openssl_ssl_pushresult(L, s, ret);
}
#endif

/***
get ssl renegotiate_pending
@function renegotiate_pending
@treturn boolean true for success
@treturn string fail reasion
*/
/***
do ssl renegotiate_pending
@function renegotiate_pending
@treturn boolean true for success
@treturn string fail reasion
*/
static int openssl_ssl_renegotiate_pending(lua_State*L)
{
  SSL* s = CHECK_OBJECT(1, SSL, "openssl.ssl");
  int ret = SSL_renegotiate_pending(s);
  return openssl_ssl_pushresult(L, s, ret);
}

/***
shutdown ssl connection with quite or noquite mode
@function shutdown
@tparam boolean mode
@treturn boolean if mode is true, return true or false for quite
@treturn string if mode is false, return 'read' or 'write' for shutdown direction
*/
/***
shutdown SSL connection
@function shutdown
*/
/***
shutdown ssl connect with special mode, disable read or write,
enable or disable quite shutdown
@function shutdown
@tparam string mode support 'read','write', 'quite', 'noquite'
*/
static int openssl_ssl_shutdown(lua_State*L)
{
  SSL* s = CHECK_OBJECT(1, SSL, "openssl.ssl");
  if (lua_isnone(L, 2))
  {
    int ret = SSL_shutdown(s);
    return openssl_ssl_pushresult(L, s, ret);
  }
  else if (lua_isstring(L, 2))
  {
    const static char* sMode[]  = {"read", "write", "quiet", "noquiet", NULL};
    int mode = luaL_checkoption(L, 2, NULL, sMode);
    if (mode == 0)
      SSL_set_shutdown(s, SSL_RECEIVED_SHUTDOWN);
    else if (mode == 1)
      SSL_set_shutdown(s, SSL_SENT_SHUTDOWN);
    else if (mode == 2)
      SSL_set_quiet_shutdown(s, 1);
    else if (mode == 3)
      SSL_set_quiet_shutdown(s, 0);
  }
  else if (lua_isboolean(L, 2))
  {
    int quiet = lua_toboolean(L, 2);
    if (quiet)
      lua_pushboolean(L, SSL_get_quiet_shutdown(s));
    else
    {
      int shut = SSL_get_shutdown(s);
      if (shut == SSL_RECEIVED_SHUTDOWN)
        lua_pushstring(L, "read");
      else if (shut == SSL_SENT_SHUTDOWN)
        lua_pushstring(L, "write");
      else if (shut == 0)
        lua_pushnil(L);
      else
        luaL_error(L, "Can't understand SSL_get_shutdown result");
    }
    return 1;
  }
  else
    luaL_argerror(L, 2, "should be boolean or string[read|write|quiet|noquite]");

  return 0;
};

/***
make ssl to client mode
@function set_connect_state
*/
static int openssl_ssl_set_connect_state(lua_State*L)
{
  SSL* s = CHECK_OBJECT(1, SSL, "openssl.ssl");
  SSL_set_connect_state(s);
  return 0;
}

/***
make ssl to server mode
@function set_accept_state
*/
static int openssl_ssl_set_accept_state(lua_State*L)
{
  SSL* s = CHECK_OBJECT(1, SSL, "openssl.ssl");
  SSL_set_accept_state(s);
  return 0;
}

/***
duplicate ssl object
@treturn ssl
@function dup
*/
static int openssl_ssl_dup(lua_State*L)
{
  SSL* s = CHECK_OBJECT(1, SSL, "openssl.ssl");
  BIO *rio = SSL_get_rbio(s);
  BIO *wio = SSL_get_wbio(s);
  if (rio != NULL || wio != NULL)
  {
    lua_pushnil(L);
    lua_pushliteral(L, "invalid state: rbio or wbio already set");
    return 2;
  }

  s = SSL_dup(s);
  if (s)
  {
    PUSH_OBJECT(s, "openssl.ssl");
    openssl_newvalue(L, s);
    return 1;
  }
  return openssl_pushresult(L, 0);
}

/***
get ssl session resused
@function session_reused
*/
static int openssl_ssl_session_reused(lua_State*L)
{
  SSL* s = CHECK_OBJECT(1, SSL, "openssl.ssl");
  int ret = SSL_session_reused(s);
  lua_pushboolean(L, ret);
  return 1;
}

#if OPENSSL_VERSION_NUMBER > 0x10000000L
static int openssl_ssl_cache_hit(lua_State*L)
{
  SSL* s = CHECK_OBJECT(1, SSL, "openssl.ssl");
  int ret = SSL_session_reused(s);
  lua_pushboolean(L, ret == 0);
  return 1;
}
#if OPENSSL_VERSION_NUMBER < 0x10100000L
static int openssl_ssl_set_debug(lua_State*L)
{
  SSL* s = CHECK_OBJECT(1, SSL, "openssl.ssl");
  int debug = luaL_checkint(L, 2);
  SSL_set_debug(s, debug);
  return 0;
}
#endif
#endif

/***
get ssl_ctx associate with current ssl
@function ctx
@treturn ssl_ctx
*/
/***
set ssl_ctx associate to current ssl
@function ctx
@tparam ssl_ctx ctx
@treturn ssl_ctx orgine ssl_ctx object
*/
static int openssl_ssl_ctx(lua_State*L)
{
  SSL* s = CHECK_OBJECT(1, SSL, "openssl.ssl");
  if (!lua_isnone(L, 2))
  {
    SSL_CTX *ctx = CHECK_OBJECT(2, SSL_CTX, "openssl.ssl_ctx");
    ctx = SSL_set_SSL_CTX(s, ctx);
    lua_pushvalue(L, 2);
    openssl_valueset(L, s, "ctx");
  }
  openssl_valueget(L, s, "ctx");
  return 1;
}

/***
get ssl session
@treturn ssl_session session object
@function session
*/
/***
set ssl session
@function session
@tparam string|ssl_session sesion
 reuse session would speed up ssl handshake
@treturn boolean result
*/
static int openssl_ssl_session(lua_State*L)
{
  SSL* s = CHECK_OBJECT(1, SSL, "openssl.ssl");
  SSL_SESSION*ss;

  if (lua_isnone(L, 2))
  {
    ss = SSL_get1_session(s);
    PUSH_OBJECT(ss, "openssl.ssl_session");
  }
  else
  {
    if (lua_isstring(L, 3))
    {
      size_t sz;
      const char* sid_ctx = luaL_checklstring(L, 2, &sz);
      int ret = SSL_set_session_id_context(s, (unsigned char*)sid_ctx, sz);
      lua_pushboolean(L, ret);
    }
    else
    {
      ss = CHECK_OBJECT(2, SSL_SESSION, "openssl.ssl_session");
      if (lua_isnone(L, 3))
      {
        int ret = SSL_set_session(s, ss);
        lua_pushboolean(L, ret);
      }
      else
      {
#ifdef SSL_add_session
        int add = auxiliar_checkboolean(L, 3);
        if (add)
          add = SSL_add_session(s, ss);
        else
          add = SSL_remove_session(s, ss);
        lua_pushboolean(L, add);
#endif
      }
    }
  }
  return 1;
}

static int openssl_ssl_tostring(lua_State*L)
{
  SSL* s = CHECK_OBJECT(1, SSL, "openssl.ssl");
  lua_pushfstring(L, "openssl.ssl %p", s);
  return 1;
}

static luaL_Reg ssl_funcs[] =
{
  {"set",       openssl_ssl_set},
  {"get",       openssl_ssl_get},
  {"use",       openssl_ssl_use},
  {"peer",      openssl_ssl_peer},
  {"getfd",     openssl_ssl_getfd},
  {"is_server", openssl_ssl_is_server},

  {"current_cipher",        openssl_ssl_current_cipher},
#if !defined(OPENSSL_NO_COMP)
  {"current_compression",   openssl_ssl_current_compression},
#endif
  {"getpeerverification",   openssl_ssl_getpeerverification},

  {"session",    openssl_ssl_session},

  {"dup",       openssl_ssl_dup},
  {"ctx",       openssl_ssl_ctx},
  {"clear",     openssl_ssl_clear},
  {"want",      openssl_ssl_want},
  {"pending",   openssl_ssl_pending},
  {"accept",    openssl_ssl_accept},
  {"connect",   openssl_ssl_connect},
  {"read",      openssl_ssl_read},
  {"peek",      openssl_ssl_peek},
  {"write",     openssl_ssl_write},

  {"renegotiate",   openssl_ssl_renegotiate},
  {"handshake",     openssl_ssl_do_handshake},
  {"shutdown",      openssl_ssl_shutdown},

  {"session_reused", openssl_ssl_session_reused},
#if OPENSSL_VERSION_NUMBER > 0x10000000L
#if OPENSSL_VERSION_NUMBER < 0x10100000L
  {"set_debug",   openssl_ssl_set_debug},
#endif
  {"cache_hit",   openssl_ssl_cache_hit},
  {"renegotiate_abbreviated", openssl_ssl_renegotiate_abbreviated},
#endif
  {"renegotiate_pending",   openssl_ssl_renegotiate_pending},
  {"set_connect_state",     openssl_ssl_set_connect_state},
  {"set_accept_state",      openssl_ssl_set_accept_state},

  {"__gc",          openssl_ssl_gc},
  {"__tostring",    openssl_ssl_tostring},

  {NULL,      NULL},
};

int luaopen_ssl(lua_State *L)
{
  int i;

  auxiliar_newclass(L, "openssl.ssl_ctx",       ssl_ctx_funcs);
  auxiliar_newclass(L, "openssl.ssl_session",   ssl_session_funcs);
  auxiliar_newclass(L, "openssl.ssl",           ssl_funcs);

  lua_newtable(L);
  luaL_setfuncs(L, R, 0);

  auxiliar_enumerate(L, -1, ssl_options);
  for (i = 0; sVerifyMode_Options[i]; i++)
  {
    lua_pushinteger(L, iVerifyMode_Options[i]);
    lua_setfield(L, -2, sVerifyMode_Options[i]);
  }
  lua_pushstring(L, DEFAULT_PROTOCOL);
  lua_setfield(L, -2, "default");

  return 1;
}
