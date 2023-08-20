/*=========================================================================*\
* callback.c
* callback for lua-openssl binding
*
* Author:  george zhao <zhaozg(at)gmail.com>
\*=========================================================================*/
#include "openssl.h"
#include "private.h"
#include <stdint.h>
#include <openssl/ssl.h>

static int verify_cb(int preverify_ok, X509_STORE_CTX *xctx, lua_State*L, SSL* ssl, SSL_CTX* ctx)
{
  int err = X509_STORE_CTX_get_error(xctx);
  int depth = X509_STORE_CTX_get_error_depth(xctx);
  X509 *current = X509_STORE_CTX_get_current_cert(xctx);

  if (L)
  {
    /* get verify_cert state */
    openssl_valueget(L, ssl, "verify_cert");
    if (lua_isnil(L, -1))
    {
      lua_newtable(L);
      openssl_valueset(L, ssl, "verify_cert");
      openssl_valueget(L, ssl, "verify_cert");
    }

    /* create current verify state table */
    lua_newtable(L);
    if (preverify_ok != -1)
    {
      lua_pushboolean(L, preverify_ok);
      lua_setfield(L, -2, "preverify_ok");
    }
    lua_pushinteger(L, err);
    lua_setfield(L, -2, "error");
    lua_pushstring(L, X509_verify_cert_error_string(err));
    lua_setfield(L, -2, "error_string");
    lua_pushinteger(L, X509_STORE_CTX_get_error_depth(xctx));
    lua_setfield(L, -2, "error_depth");
    if (current)
    {
      PUSH_OBJECT(current, "openssl.x509");
      X509_up_ref(current);
      lua_setfield(L, -2, "current_cert");
    }

    openssl_valueget(L, ctx, preverify_ok == -1 ? "cert_verify_cb" : "verify_cb");
    if (lua_isfunction(L, -1))
    {
      /* this is set by  SSL_CTX_set_verify */
      lua_pushvalue(L, -2); /* current verify state */
      if (lua_pcall(L, 1, 1, 0) == 0)
      {
        preverify_ok = lua_toboolean(L, -1);
        lua_pop(L, 1);
      }
      else
        luaL_error(L, lua_tostring(L, -1));
    }
    else
    {
      int always_continue, verify_depth;
      openssl_valueget(L, ctx, "verify_cb_flags");
      /*
      int verify_depth;
      int always_continue;
      */
      if (lua_istable(L, -1))
      {
        lua_getfield(L, -1, "always_continue");
        always_continue = lua_toboolean(L, -1);
        lua_pop(L, 1);

        lua_getfield(L, -1, "verify_depth");
        verify_depth = lua_toboolean(L, -1);
        lua_pop(L, 1);

        if (depth > verify_depth)
        {
          preverify_ok = 0;
          X509_STORE_CTX_set_error(xctx, X509_V_ERR_CERT_CHAIN_TOO_LONG);
        }
        if (always_continue)
          preverify_ok = 1;
      }
      lua_pop(L, 1);
    }

    /* set current state to chain */
    lua_rawseti(L, -2, lua_rawlen(L, -2) + 1);

    /* balance lua stack */
    lua_pop(L, 1);
  }

  return preverify_ok;
}

int openssl_verify_cb(int preverify_ok, X509_STORE_CTX *xctx)
{
  SSL *ssl = X509_STORE_CTX_get_ex_data(xctx,
                                        SSL_get_ex_data_X509_STORE_CTX_idx());
  SSL_CTX *ctx = ssl ? SSL_get_SSL_CTX(ssl) : NULL;
  lua_State *L = ctx ? SSL_CTX_get_app_data(ctx) : NULL;
  if (ssl)
    openssl_newvalue(L, ssl);
  return ctx ? verify_cb(preverify_ok, xctx, L, ssl, ctx) : 0;
};

int openssl_cert_verify_cb(X509_STORE_CTX *xctx, void* u)
{
  int preverify_ok = 0;
  lua_State *L = (lua_State *)u;
  SSL *ssl = X509_STORE_CTX_get_ex_data(xctx,
                                        SSL_get_ex_data_X509_STORE_CTX_idx());
  SSL_CTX *ctx = ssl ? SSL_get_SSL_CTX(ssl) : NULL;
  if (ssl)
    openssl_newvalue(L, ssl);
  preverify_ok = ctx ? verify_cb(-1, xctx, L, ssl, ctx) : 0;
  return preverify_ok == -1 ? 0 : preverify_ok;
};

