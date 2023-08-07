/***
bio module to mapping a BIO in openssl to a lua object.

@module bio
@usage
  bio = require'openssl'.bio
*/

#include "openssl.h"
#include "private.h"
#include <openssl/bn.h>
#include <openssl/ssl.h>

/*
static const int* iMethods[] = {
  BIO_TYPE_NONE,
  BIO_TYPE_MEM,
  BIO_TYPE_SOCKET,
  BIO_TYPE_CONNECT,
  BIO_TYPE_ACCEPT,
  BIO_TYPE_FD,
  BIO_TYPE_BIO,
  BIO_TYPE_DGRAM,

  BIO_TYPE_BUFFER,

  -1
};
static const char* sMethods[] = {
  "none",
  "mem",
  "socket",
  "connect",
  "accept",
  "fd",
  "bio",
  "datagram",

  "buffer",
  NULL
};

static LUA_FUNCTION(openssl_bio_new) {

const char* f = luaL_checkstring(L,1);
const char* m = luaL_optstring(L,2,"r");
BIO *bio = BIO_new_file(f,m);
BIO_f_base64()
if(!bio)
luaL_error(L, "error opening the file(%s) for mode (%s)", f, m);
PUSH_OBJECT(bio,"openssl.bio");
return 1;
}
*/

/***
make string as bio object

@function mem
@tparam[opt=nil] string data, it will be memory buffer data
@treturn bio it can be input or output object
*/
static LUA_FUNCTION(openssl_bio_new_mem)
{
  size_t l = 0;
  BIO *bio = BIO_new(BIO_s_mem());
  if (lua_isnumber(L, 1))
  {
    l = lua_tointeger(L, 1);
    BIO_set_buffer_size(bio, l);
  }
  else if (lua_isstring(L, 1))
  {
    const char* d = (char*)luaL_checklstring(L, 1, &l);
    BIO_write(bio, d, l);
  }

  PUSH_OBJECT(bio, "openssl.bio");
  return 1;
}

static LUA_FUNCTION(openssl_bio_new_pair)
{
  size_t b1 = luaL_optint(L, 1, 0);
  size_t b2 = luaL_optint(L, 2, b1);
  BIO *B1 = NULL;
  BIO *B2 = NULL;

  int ret = BIO_new_bio_pair(&B1, b1, &B2, b2);
  if (ret==1)
  {
    PUSH_OBJECT(B1, "openssl.bio");
    PUSH_OBJECT(B2, "openssl.bio");
    ret = 2;
  }
  return ret > 0 ? ret : openssl_pushresult(L, ret);
}

static LUA_FUNCTION(openssl_bio_new_null)
{
  BIO *bio = BIO_new(BIO_s_null());

  PUSH_OBJECT(bio, "openssl.bio");
  return 1;
}

/***
make tcp bio from socket fd

@function socket
@tparam number fd
@tparam[opt='noclose'] flag support 'close' or 'noclose' when close or gc
@treturn bio
*/
static LUA_FUNCTION(openssl_bio_new_socket)
{
  int s = luaL_checkint(L, 1);
  int closeflag = luaL_optinteger(L, 2, 0);
  BIO *bio = BIO_new_socket(s, closeflag);

  PUSH_OBJECT(bio, "openssl.bio");
  return 1;
}

/***
make dgram bio from socket fd

@function dgram
@tparam number fd
@tparam[opt='noclose'] flag support 'close' or 'noclose' when close or gc
@treturn bio
*/
static LUA_FUNCTION(openssl_bio_new_dgram)
{
  int s = luaL_checkint(L, 1);
  int closeflag = luaL_optinteger(L, 2, 0);
  BIO *bio = BIO_new_dgram(s, closeflag);

  PUSH_OBJECT(bio, "openssl.bio");
  return 1;
}

/***
make socket or file bio with fd
@function fd
@tparam number fd
@tparam[opt='noclose'] flag support 'close' or 'noclose' when close or gc
@treturn bio
*/
static LUA_FUNCTION(openssl_bio_new_fd)
{
  int fd = luaL_checkint(L, 1);
  int closeflag = luaL_optinteger(L, 2, 0);
  BIO *bio = BIO_new_fd(fd, closeflag);

  PUSH_OBJECT(bio, "openssl.bio");
  return 1;
}

/***
make file object with file name or path
@function file
@tparam string file
@tparam[opt='r'] string mode
@treturn bio
*/
static LUA_FUNCTION(openssl_bio_new_file)
{
  const char* f = luaL_checkstring(L, 1);
  const char* m = luaL_optstring(L, 2, "r");
  BIO *bio = BIO_new_file(f, m);
  if (bio)
  {
    PUSH_OBJECT(bio, "openssl.bio");
  }

  return bio ? 1 : openssl_pushresult(L, 0);
}

/***
make tcp listen socket
@function accept
@tparam string host_port address like 'host:port'
@treturn bio
*/
static LUA_FUNCTION(openssl_bio_new_accept)
{
  const char* port = lua_tostring(L, 1);
  BIO* b = BIO_new_accept((char*)port);

  PUSH_OBJECT(b, "openssl.bio");
  return 1;
}

/***
make tcp client socket
@function connect
@tparam string host_addr addrees like 'host:port'
@tparam[opt=true] boolean connect default connect immediately
@treturn bio
*/

/***
make tcp client socket
@function connect
@tparam address table with hostname, ip, port filed
@tparam[opt=true] boolean connect default connect immediately
@treturn bio
*/
static int openssl_bio_new_connect(lua_State *L)
{
  BIO* bio = NULL;
  int doconn = 1;
  int ret = 1;

  if (lua_isstring(L, 1))
  {
    const char *host = luaL_checkstring(L, 1);
    bio = BIO_new_connect((char*)host);
  }
  else if (lua_istable(L, 1))
  {
    bio = BIO_new(BIO_s_connect());

    lua_getfield(L, 1, "hostname");
    if (!lua_isnil(L, -1)) {
      BIO_set_conn_hostname(bio, (char*) lua_tostring(L, -1));
    }
    lua_pop(L, 1);

    lua_getfield(L, 1, "port");
    if(!lua_isnil(L, -1)) {
      BIO_set_conn_port(bio, (char *)lua_tostring(L, -1));
    }
    lua_pop(L, 1);
  } else
  {
    bio = BIO_new(BIO_s_connect());
    doconn = 0;
  }

  doconn = lua_isnone(L, 2) ? doconn : lua_toboolean(L, 2);
  if (doconn)
    ret = BIO_do_connect(bio);

  if (ret == 1)
  {
    PUSH_OBJECT(bio, "openssl.bio");
  }
  else
    BIO_free(bio);
  return ret == 1 ? ret : openssl_pushresult(L, ret);
}

/***
make base64 or buffer bio, which can append to an io BIO object
@function filter
@tparam string mode support 'base64' or 'buffer'
@treturn bio
*/
/***
make digest bio, which can append to an io BIO object
@function filter
@tparam string mode must be 'digest'
@tparam evp_md|string md_alg
@treturn bio
*/
/***
make ssl bio
@function filter
@tparam string mode must be 'ssl'
@tparam ssl s
@tparam[opt='noclose'] flag support 'close' or 'noclose' when close or gc
@treturn bio
*/

/***
make cipher filter bio object
@function filter
@tparam string mode must be 'cipher'
@tparam string key
@tparam string iv
@tparam[opt=true] boolean encrypt
@treturn bio
*/
static LUA_FUNCTION(openssl_bio_new_filter)
{
  /* 0         1        2      3      4    5 */
  static const char* sType[] = {"base64", "buffer", "cipher", "md", "ssl", NULL};
  int type = luaL_checkoption(L, 1, NULL, sType);
  BIO* bio = NULL;
  int ret = 1;
  switch (type)
  {
  case 0:
    bio = BIO_new(BIO_f_base64());
    break;
  case 1:
    bio = BIO_new(BIO_f_buffer());
    break;
  case 2:
  {
    const EVP_CIPHER* c = get_cipher(L, 2, NULL);
    size_t kl, il;
    const char* k = luaL_checklstring(L, 3, &kl);
    const char* v = luaL_checklstring(L, 4, &il);
    int encrypt = auxiliar_checkboolean(L, 5);

    bio = BIO_new(BIO_f_cipher());
    BIO_set_cipher(bio, c, (const unsigned char*)k, (const unsigned char*)v, encrypt);
  }
  break;
  case 3:
  {
    const EVP_MD* md = get_digest(L, 2, NULL);

    bio = BIO_new(BIO_f_md());
    ret = BIO_set_md(bio, md);
  }
  break;
  case 4:
  {
    SSL* ssl = CHECK_OBJECT(2, SSL, "openssl.ssl");
    int closeflag = luaL_optinteger(L, 3, 0);

    bio = BIO_new(BIO_f_ssl());
    ret = BIO_set_ssl(bio, ssl, closeflag);
  }
  break;
  default:
    ret = 0;
  }
  if (ret == 1 && bio)
  {
    PUSH_OBJECT(bio, "openssl.bio");
    return 1;
  }
  else
  {
    if (bio)
      BIO_free_all(bio);
    return openssl_pushresult(L, ret);
  }
}

/* bio object method */
/***
openssl.bio object
@type bio
*/

/***
read data from bio object
@function read
@tparam number len
@treturn string string length may be less than param len
*/
static LUA_FUNCTION(openssl_bio_read)
{
  BIO* bio = CHECK_OBJECT(1, BIO, "openssl.bio");
  int len = luaL_optint(L, 2, BIO_pending(bio));
  char* buf = NULL;
  int ret = 1;

  len = len > 0 ? len : 4096;
  buf = malloc(len);
  len = BIO_read(bio, buf, len);

  if (len > 0)
  {
    lua_pushlstring(L, buf, len);
    ret = 1;
  }
  else if (BIO_should_retry(bio))
  {
    lua_pushlstring(L, buf, 0);
    ret = 1;
  }
  else
  {
    lua_pushnil(L);
    lua_pushinteger(L, len);
    ret = 2;
  };
  free(buf);
  return ret;
}

/***
get line from bio object
@function gets
@tparam[opt=256] number max line len
@treturn string string length may be less than param len
*/
static LUA_FUNCTION(openssl_bio_gets)
{
  BIO* bio = CHECK_OBJECT(1, BIO, "openssl.bio");
  int len = luaL_optint(L, 2, BIO_pending(bio));
  char* buf;
  int ret = 1;
  len = len > 0 ? len : 1024;

  buf = malloc(len);
  len = BIO_gets(bio, buf, len);
  if (len > 0)
  {
    lua_pushlstring(L, buf, len);
    ret = 1;
  }
  else if (BIO_should_retry(bio))
  {
    lua_pushstring(L, "");
    ret = 1;
  }
  else
  {
    lua_pushnil(L);
    lua_pushinteger(L, len);
    ret = 2;
  };
  free(buf);
  return ret;
}

/***
write data to bio object
@function write
@tparam string data
@treturn number length success write
*/
static LUA_FUNCTION(openssl_bio_write)
{
  BIO* bio = CHECK_OBJECT(1, BIO, "openssl.bio");
  size_t size = 0;
  const char* d = luaL_checklstring(L, 2, &size);
  int ret = 1;
  int len = luaL_optint(L, 3, size);

  len = BIO_write(bio, d, len);
  if (len > 0)
  {
    lua_pushinteger(L, len);
    ret = 1;
  }
  else if (BIO_should_retry(bio))
  {
    lua_pushinteger(L, 0);
    ret = 1;
  }
  else
  {
    lua_pushnil(L);
    lua_pushinteger(L, len);
    ret = 2;
  };
  return ret;
}

/***
put line to bio object
@function puts
@tparam string data
@treturn number length success write
*/
static LUA_FUNCTION(openssl_bio_puts)
{
  BIO* bio = CHECK_OBJECT(1, BIO, "openssl.bio");
  const char* s = luaL_checkstring(L, 2);
  int ret = 1;
  int len = BIO_puts(bio, s);

  if (len > 0)
  {
    lua_pushinteger(L, len);
    ret = 1;
  }
  else if (BIO_should_retry(bio))
  {
    lua_pushinteger(L, 0);
    ret = 1;
  }
  else
  {
    lua_pushnil(L);
    lua_pushinteger(L, len);
    ret = 2;
  };
  return ret;
}

/***
flush buffer of bio object
@function flush
@treturn boolean true for success, others for fail
*/
static LUA_FUNCTION(openssl_bio_flush)
{
  BIO* bio = CHECK_OBJECT(1, BIO, "openssl.bio");
  int ret = BIO_flush(bio);
  lua_pushinteger(L, ret);
  return 1;
}

static LUA_FUNCTION(openssl_bio_free)
{
  int flags;
  BIO* bio = CHECK_OBJECT(1, BIO, "openssl.bio");
  if (bio==NULL)
    return 0;

  flags = lua_toboolean(L, 2);
  if (flags)
    BIO_free_all(bio);
  else
    BIO_free(bio);

  *(void**)lua_touserdata(L, 1) = NULL;

  return 0;
}

/***
get type of bio
@function type
@treturn string
*/
static LUA_FUNCTION(openssl_bio_type)
{
  BIO* bio = CHECK_OBJECT(1, BIO, "openssl.bio");
  lua_pushstring(L, BIO_method_name(bio));
  return 1;
}

/***
set nonblock for bio object
@function nbio
@tparam boolean nonblock
@treturn boolean result, true for success, others for fail
*/
static LUA_FUNCTION(openssl_bio_nbio)
{
  BIO* bio = CHECK_OBJECT(1, BIO, "openssl.bio");
  int nbio = lua_toboolean(L, 2);
  int ret = BIO_set_nbio(bio, nbio);
  return openssl_pushresult(L, ret);
}

static LUA_FUNCTION(openssl_bio_retry)
{
  BIO* bio = CHECK_OBJECT(1, BIO, "openssl.bio");
  int retry = BIO_should_retry(bio);
  if (retry)
  {
    lua_pushboolean(L, 1);
    lua_pushboolean(L, BIO_should_read(bio));
    lua_pushboolean(L, BIO_should_write(bio));
    lua_pushboolean(L, BIO_should_io_special(bio));
    return 4;
  }
  else
    lua_pushboolean(L, 0);
  return 1;
}

/***
reset bio
@function reset
*/
static LUA_FUNCTION(openssl_bio_reset)
{
  BIO* bio = CHECK_OBJECT(1, BIO, "openssl.bio");
  (void)BIO_reset(bio);
  return 0;
}

/* filter bio object */
/***
push bio append to chain of bio, if want to free a chain use free_all()
@function push
@tparam bio append
@treturn bio
*/
static LUA_FUNCTION(openssl_bio_push)
{
  BIO* bio = CHECK_OBJECT(1, BIO, "openssl.bio");
  BIO* append = CHECK_OBJECT(2, BIO, "openssl.bio");
  bio = BIO_push(bio, append);
  if (bio)
  {
    lua_pushvalue(L, 1);
  }
  else
    lua_pushnil(L);
  return 1;
}

/***
remove bio from chain
@function pop
@tparam bio toremove
*/
static LUA_FUNCTION(openssl_bio_pop)
{
  BIO* bio = CHECK_OBJECT(1, BIO, "openssl.bio");
  BIO* end = BIO_pop(bio);
  if (end == NULL)
  {
    lua_pushnil(L);
  }
  else
  {
    BIO_up_ref(end);
    PUSH_OBJECT(end, "openssl.bio");
  }
  return 1;
}

/* mem */
/***
get mem data, only support mem bio object
@function get_mem
@treturn string
*/
static LUA_FUNCTION(openssl_bio_get_mem)
{
  BUF_MEM* mem;
  BIO* bio = CHECK_OBJECT(1, BIO, "openssl.bio");
  int ret = BIO_get_mem_ptr(bio, &mem);
  if (ret == 1)
  {
    lua_pushlstring(L, mem->data, mem->length);
  }
  return ret == 1 ? 1 : openssl_pushresult(L, ret);
}

static LUA_FUNCTION(openssl_bio_get_md)
{
  BIO* bio = CHECK_OBJECT(1, BIO, "openssl.bio");
  bio = BIO_find_type(bio, BIO_TYPE_MD);
  int ret = 0;

  if (bio)
  {
    EVP_MD *md;
    BIO_get_md(bio, &md);
    PUSH_OBJECT(bio, "openssl.bio");
    BIO_up_ref(bio);
    PUSH_OBJECT(md, "openssl.evp_digest");
    ret = 2;
  }
  return ret;
}

static LUA_FUNCTION(openssl_bio_next)
{
  BIO* bio = CHECK_OBJECT(1, BIO, "openssl.bio");
  bio = BIO_next(bio);
  if (bio)
  {
    PUSH_OBJECT(bio, "openssl.bio");
    BIO_up_ref(bio);
  }
  return bio ? 1 : 0;
}

static LUA_FUNCTION(openssl_bio_cipher_status)
{
  BIO* bio = CHECK_OBJECT(1, BIO, "openssl.bio");
  lua_pushboolean(L, BIO_get_cipher_status(bio));
  return 1;
}


/* network socket */
/***
setup ready and accept client connect
@function accept
@tparam[opt=false] boolean setup true for setup accept bio, false or none will accept client connect
@treturn[1] boolean result only when setup is true
@treturn[2] bio accpeted bio object
*/
static LUA_FUNCTION(openssl_bio_accept)
{
  BIO* bio = CHECK_OBJECT(1, BIO, "openssl.bio");
  int first = lua_isnone(L, 2) ? 0 : lua_toboolean(L, 2);
  int ret = BIO_do_accept(bio);
  if (ret == 1)
  {
    if (!first)
    {
      BIO *nb = BIO_pop(bio);

      PUSH_OBJECT(nb, "openssl.bio");
      return 1;
    }
  }
  return openssl_pushresult(L, ret);
}

/***
shutdown SSL or TCP connection
@function shutdown
*/
static LUA_FUNCTION(openssl_bio_shutdown)
{
  BIO* bio = CHECK_OBJECT(1, BIO, "openssl.bio");

  luaL_argcheck(L,
                BIO_method_type(bio) & (BIO_TYPE_SSL | BIO_TYPE_SOCKET | BIO_TYPE_FD),
                1,
                "don't know howto shutdown");

  if (BIO_method_type(bio) & BIO_TYPE_SSL)
  {
    BIO_ssl_shutdown(bio);
  }
  else if (BIO_method_type(bio) & (BIO_TYPE_SOCKET | BIO_TYPE_FD))
  {
    BIO_shutdown_wr(bio);
  }

  lua_pushvalue(L, 1);
  return 1;
}

/***
get ssl object assosited with bio object
@function get_ssl
@treturn ssl
*/
static LUA_FUNCTION(openssl_bio_get_ssl)
{
  BIO* bio = CHECK_OBJECT(1, BIO, "openssl.bio");
  SSL* ssl = NULL;
  int ret = BIO_get_ssl(bio, &ssl);
  if (ret == 1)
  {
    PUSH_OBJECT(ssl, "openssl.ssl");
    SSL_up_ref(ssl);
    openssl_newvalue(L, ssl);
  }
  return ret==1 ? ret : openssl_pushresult(L, ret);
}

/***
do TCP or SSL connect
@function connect
@treturn booolean result true for success and others for fail
*/
static LUA_FUNCTION(openssl_bio_connect)
{
  BIO* bio = CHECK_OBJECT(1, BIO, "openssl.bio");
  int ret = BIO_do_connect(bio);
  return openssl_pushresult(L, ret);
}

/***
do handshake of TCP or SSL connection
@function handshake
@treturn boolean result true for success, and others for fail
*/
static LUA_FUNCTION(openssl_bio_handshake)
{
  BIO* bio = CHECK_OBJECT(1, BIO, "openssl.bio");
  int ret = BIO_do_handshake(bio);
  return openssl_pushresult(L, ret);
}

/***
get fd of bio object
@function fd
@treturn number
*/
/***
set fd of bio object
@function fd
@tparam number fd
@treturn number fd
*/
static LUA_FUNCTION(openssl_bio_fd)
{
  BIO* bio = CHECK_OBJECT(1, BIO, "openssl.bio");
  int type = BIO_method_type(bio);
  luaL_argcheck(L,
                type & (BIO_TYPE_FD
                       |BIO_TYPE_CONNECT
                       |BIO_TYPE_ACCEPT
                       |BIO_TYPE_DGRAM
                       |BIO_TYPE_SOCKET),
                1,
                "not a supported BIO type");
  if (!lua_isnone(L, 2))
  {
    int fd = luaL_checkint(L, 2);
    BIO_set_fd(bio, fd, BIO_NOCLOSE);
  }
  lua_pushnumber(L, BIO_get_fd(bio, 0));
  return 1;
}

/* BIO_s_file() */
/*
# define BIO_set_fp(b,fp,c)      BIO_ctrl(b,BIO_C_SET_FILE_PTR,c,(char *)fp)
# define BIO_get_fp(b,fpp)       BIO_ctrl(b,BIO_C_GET_FILE_PTR,0,(char *)fpp)
*/

static LUA_FUNCTION(openssl_bio_seek)
{
  BIO* bio = CHECK_OBJECT(1, BIO, "openssl.bio");
  int type = BIO_method_type(bio);
  int ofs, ret;
  luaL_argcheck(L,
                type & (BIO_TYPE_FD|BIO_TYPE_FILE),
                1,
                "not a fd or file BIO type");
  ofs = luaL_checkint(L, 2);
  ret = BIO_seek(bio, ofs);
  if (ret<0) return openssl_pushresult(L, ret);
  lua_pushinteger(L, ret);
  return 1;
}

static LUA_FUNCTION(openssl_bio_tell)
{
  BIO* bio = CHECK_OBJECT(1, BIO, "openssl.bio");
  int type = BIO_method_type(bio);
  int ret;
  luaL_argcheck(L,
                type & (BIO_TYPE_FD
                       |BIO_TYPE_FILE),
                1,
                "not a fd or file BIO type");
  ret = BIO_tell(bio);
  if (ret<0) return openssl_pushresult(L, ret);
  lua_pushinteger(L, ret);
  return 1;
}

#if OPENSSL_VERSION_NUMBER < 0x10100000L \
    || defined(LIBRESSL_VERSION_NUMBER) && LIBRESSL_VERSION_NUMBER < 0x3050000fL
void BIO_info_callback(BIO *bio, int cmd, const char *argp,
                       int argi, long argl, long ret)
{
  BIO *b;
  char buf[256];
  char *p;
  size_t p_maxlen;
  (void) argl;
  (void) argp;

  snprintf(buf, sizeof buf, "BIO[%p]:", bio);
  p = &(buf[14]);
  p_maxlen = sizeof buf - 14;
  switch (cmd)
  {
  case BIO_CB_FREE:
    snprintf(p, p_maxlen, "Free - %s\n", BIO_method_name(bio));
    break;
  case BIO_CB_READ:
    if (BIO_method_type(bio) & BIO_TYPE_DESCRIPTOR)
      snprintf(p, p_maxlen, "read(%lu,%lu) - %s fd=%lu\n",
               (unsigned long)BIO_number_read(bio), (unsigned long)argi,
               BIO_method_name(bio), (unsigned long)BIO_number_read(bio));
    else
      snprintf(p, p_maxlen, "read(%lu,%lu) - %s\n",
               (unsigned long)BIO_number_read(bio), (unsigned long)argi,
               BIO_method_name(bio));
    break;
  case BIO_CB_WRITE:
    if (BIO_method_type(bio) & BIO_TYPE_DESCRIPTOR)
      snprintf(p, p_maxlen, "write(%lu,%lu) - %s fd=%lu\n",
               (unsigned long)BIO_number_written(bio), (unsigned long)argi,
               BIO_method_name(bio), (unsigned long)BIO_number_written(bio));
    else
      snprintf(p, p_maxlen, "write(%lu,%lu) - %s\n",
               (unsigned long)BIO_number_written(bio), (unsigned long)argi,
               BIO_method_name(bio));
    break;
  case BIO_CB_PUTS:
    snprintf(p, p_maxlen, "puts() - %s\n", BIO_method_name(bio));
    break;
  case BIO_CB_GETS:
    snprintf(p, p_maxlen, "gets(%lu) - %s\n", (unsigned long)argi, BIO_method_name(bio));
    break;
  case BIO_CB_CTRL:
    snprintf(p, p_maxlen, "ctrl(%lu) - %s\n", (unsigned long)argi, BIO_method_name(bio));
    break;
  case BIO_CB_RETURN|BIO_CB_READ:
    snprintf(p, p_maxlen, "read return %ld\n", ret);
    break;
  case BIO_CB_RETURN|BIO_CB_WRITE:
    snprintf(p, p_maxlen, "write return %ld\n", ret);
    break;
  case BIO_CB_RETURN|BIO_CB_GETS:
    snprintf(p, p_maxlen, "gets return %ld\n", ret);
    break;
  case BIO_CB_RETURN|BIO_CB_PUTS:
    snprintf(p, p_maxlen, "puts return %ld\n", ret);
    break;
  case BIO_CB_RETURN|BIO_CB_CTRL:
    snprintf(p, p_maxlen, "ctrl return %ld\n", ret);
    break;
  default:
    snprintf(p, p_maxlen, "bio callback - unknown type (%d)\n", cmd);
    break;
  }

  b = (BIO *)BIO_get_callback_arg(bio);
  if (b != NULL)
    BIO_write(b, buf, strlen(buf));
#if !defined(OPENSSL_NO_STDIO) && !defined(OPENSSL_SYS_WIN16)
  else
    fputs(buf, stderr);
#endif
}

/***
set callback function of bio information
@function set_callback
@tparam function callback
@treturn boolean result true for success, and others for fail
*/
static LUA_FUNCTION(openssl_bio_set_callback)
{
  BIO* bio = CHECK_OBJECT(1, BIO, "openssl.bio");
  int ret;
  luaL_checktype(L, 2, LUA_TFUNCTION);

  ret = BIO_set_info_callback(bio, BIO_info_callback);
  return openssl_pushresult(L, ret);
}
#endif

/***
return pending length of bytes to read and write
@function pending
@treturn number pending of read, followed by pending of write
*/
static LUA_FUNCTION(openssl_bio_pending)
{
  BIO* bio = CHECK_OBJECT(1, BIO, "openssl.bio");

  int pending = BIO_pending(bio);
  int wpending = BIO_wpending(bio);
  lua_pushinteger(L, pending);
  lua_pushinteger(L, wpending);
  return 2;
}

/***
close bio
@function close
*/

static luaL_Reg bio_funs[] =
{
  /* generate operation */
  {"read",  openssl_bio_read},
  {"gets",  openssl_bio_gets},
  {"write", openssl_bio_write},
  {"puts",  openssl_bio_puts},
  {"flush", openssl_bio_flush},
  {"close", openssl_bio_free},
  {"type",  openssl_bio_type},
  {"nbio",  openssl_bio_nbio},
  {"reset", openssl_bio_reset},
  {"retry", openssl_bio_retry},
  {"pending", openssl_bio_pending},

#if OPENSSL_VERSION_NUMBER < 0x10100000L \
    || defined(LIBRESSL_VERSION_NUMBER) && LIBRESSL_VERSION_NUMBER < 0x3050000fL
  {"set_callback", openssl_bio_set_callback},
#endif

  /* for filter bio */
  {"push",  openssl_bio_push},
  {"pop",   openssl_bio_pop},
  {"next",   openssl_bio_next},
  {"get_md", openssl_bio_get_md},
  {"cipher_status", openssl_bio_cipher_status},
  {"free",   openssl_bio_free},

  /* for mem */
  {"get_mem", openssl_bio_get_mem},

  /* network socket */
  {"accept",    openssl_bio_accept},
  {"connect",   openssl_bio_connect},
  {"handshake", openssl_bio_handshake},

  {"shutdown",  openssl_bio_shutdown},

  /* BIO_s_datagram(), BIO_s_fd(), BIO_s_socket(),
   * BIO_s_accept() and BIO_s_connect() */
  {"fd",        openssl_bio_fd},

  {"ssl",       openssl_bio_get_ssl},

  /* BIO_s_fd() and BIO_s_file() */
  {"seek",      openssl_bio_seek},
  {"tell",      openssl_bio_tell},

  {"__tostring",  auxiliar_tostring},
  {"__gc",  openssl_bio_free},

  {NULL,    NULL}
};

static luaL_Reg R[] =
{
  {"null",    openssl_bio_new_null},
  {"mem",     openssl_bio_new_mem},
  {"pair",    openssl_bio_new_pair},
  {"socket",  openssl_bio_new_socket},
  {"dgram",   openssl_bio_new_dgram},
  {"fd",      openssl_bio_new_fd},
  {"file",    openssl_bio_new_file},
  {"filter",  openssl_bio_new_filter},

  {"accept",    openssl_bio_new_accept},
  {"connect",   openssl_bio_new_connect},

  {NULL,    NULL}
};

int luaopen_bio(lua_State *L)
{
  auxiliar_newclass(L, "openssl.bio", bio_funs);

  lua_newtable(L);
  luaL_setfuncs(L, R, 0);

  lua_pushinteger(L, BIO_NOCLOSE);
  lua_setfield(L, -2, "NCLOSE");

  lua_pushinteger(L, BIO_CLOSE);
  lua_setfield(L, -2, "CLOSE");

  return 1;
}
