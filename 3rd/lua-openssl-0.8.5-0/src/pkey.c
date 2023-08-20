/***
pkey module to create and process public or private key, do asymmetric key operations.

@module pkey
@usage
  pkey = require'openssl'.pkey
*/
#include "openssl.h"
#include "private.h"
#include <openssl/rsa.h>
#include <openssl/dh.h>
#include <openssl/dsa.h>
#include <openssl/engine.h>

static int evp_pkey_name2type(const char *name);
static const char *evp_pkey_type2name(int type);

int openssl_pkey_is_private(EVP_PKEY* pkey)
{
  int ret = 0;
  int typ;
  assert(pkey != NULL);
  typ = EVP_PKEY_type(EVP_PKEY_id(pkey));
  switch (typ)
  {
#ifndef OPENSSL_NO_RSA
  case EVP_PKEY_RSA:
  {
    RSA *rsa = (RSA*) EVP_PKEY_get0_RSA(pkey);
    const BIGNUM *d = NULL;

    RSA_get0_key(rsa, NULL, NULL, &d);
    ret = d != NULL;
    break;
  }
#endif
#ifndef OPENSSL_NO_DSA
  case EVP_PKEY_DSA:
  {
    DSA *dsa = (DSA*) EVP_PKEY_get0_DSA(pkey);
    const BIGNUM *p = NULL;
    DSA_get0_key(dsa, NULL, &p);
    ret = p != NULL;
    break;
  }
#endif
#ifndef OPENSSL_NO_DH
  case EVP_PKEY_DH:
  {
    DH *dh = (DH*) EVP_PKEY_get0_DH(pkey);
    const BIGNUM *p = NULL;
    DH_get0_key(dh, NULL, &p);
    ret = p != NULL;
    break;
  }
#endif
#ifndef OPENSSL_NO_EC
  case EVP_PKEY_EC:
#ifdef EVP_PKEY_SM2
  case EVP_PKEY_SM2:
#endif
  {
    EC_KEY *ec = (EC_KEY*) EVP_PKEY_get0_EC_KEY(pkey);
    const BIGNUM *p = EC_KEY_get0_private_key(ec);
    ret = p != NULL;
    break;
  }
#endif
  default:
    break;
  }

  return ret;
}

#if defined(OPENSSL_SUPPORT_SM2)
static int openssl_pkey_is_sm2(const EVP_PKEY *pkey)
{
  int id;
#if OPENSSL_VERSION_NUMBER > 0x30000000
  id = EVP_PKEY_get_id(pkey);
  if (id == NID_sm2)
    return 1;
#else
  id = EVP_PKEY_id(pkey);
  if (id == EVP_PKEY_SM2)
    return 1;
#endif

  id = EVP_PKEY_base_id(pkey);
  if(id==EVP_PKEY_EC)
  {
    const EC_KEY *ec = EVP_PKEY_get0_EC_KEY((EVP_PKEY*)pkey);
    const EC_GROUP *grp = EC_KEY_get0_group(ec);
    int curve = EC_GROUP_get_curve_name(grp);
    return curve==NID_sm2;
  }
  return 0;
}
#endif

/***
read public/private key from data
@function read
@tparam string|openssl.bio input string data or bio object
@tparam[opt=false] boolean priv prikey set true when input is private key
@tparam[opt='auto'] string format or encoding of input, support 'auto','pem','der'
@tparam[opt] string passhprase when input is private key, or key types 'ec','rsa','dsa','dh'
@treturn evp_pkey public key
@see evp_pkey
*/
static int openssl_pkey_read(lua_State*L)
{
  EVP_PKEY * key = NULL;
  BIO* in = load_bio_object(L, 1);
  int priv = lua_isnone(L, 2) ? 0 : auxiliar_checkboolean(L, 2);
  int fmt = luaL_checkoption(L, 3, "auto", format);
  const char* passphrase = luaL_optstring(L, 4, NULL);
  int type = passphrase != NULL ? evp_pkey_name2type(passphrase) : -1;

  if (fmt == FORMAT_AUTO)
  {
    fmt = bio_is_der(in) ? FORMAT_DER : FORMAT_PEM;
  }

  if (!priv)
  {
    if (fmt == FORMAT_PEM)
    {
      switch (type)
      {
#ifndef OPENSSL_NO_RSA
      case EVP_PKEY_RSA:
      {
        RSA* rsa = PEM_read_bio_RSAPublicKey(in, NULL, NULL, NULL);
        if (rsa)
        {
          key = EVP_PKEY_new();
          EVP_PKEY_assign_RSA(key, rsa);
        }
        break;
      }
#endif
#ifndef OPENSSL_NO_DSA
      case EVP_PKEY_DSA:
      {
        DSA* dsa = PEM_read_bio_DSA_PUBKEY(in, NULL, NULL, NULL);
        if (dsa)
        {
          key = EVP_PKEY_new();
          EVP_PKEY_assign_DSA(key, dsa);
        }
        break;
      }
#endif
#ifndef OPENSSL_NO_EC
      case EVP_PKEY_EC:
      {
        EC_KEY *ec = PEM_read_bio_EC_PUBKEY(in, NULL, NULL, NULL);
        if (ec)
        {
          key = EVP_PKEY_new();
          EVP_PKEY_assign_EC_KEY(key, ec);
        }
        break;
      }
#endif
      default:
      {
        key = PEM_read_bio_PUBKEY(in, NULL, NULL, NULL);
        break;
      }
      }
      (void)BIO_reset(in);
    }
    else if (fmt == FORMAT_DER)
    {
      switch (type)
      {
#ifndef OPENSSL_NO_RSA
      case EVP_PKEY_RSA:
      {
        RSA *rsa = d2i_RSAPublicKey_bio(in, NULL);
        if (rsa)
        {
          key = EVP_PKEY_new();
          EVP_PKEY_assign_RSA(key, rsa);
        }
        break;
      }
#endif
#ifndef OPENSSL_NO_DSA
      case EVP_PKEY_DSA:
      {
        DSA *dsa = d2i_DSA_PUBKEY_bio(in, NULL);
        if (dsa)
        {
          key = EVP_PKEY_new();
          EVP_PKEY_assign_DSA(key, dsa);
        }
        break;
      }
#endif
#ifndef OPENSSL_NO_EC
      case EVP_PKEY_EC:
      {
        EC_KEY *ec = d2i_EC_PUBKEY_bio(in, NULL);
        if (ec)
        {
          key = EVP_PKEY_new();
          EVP_PKEY_assign_EC_KEY(key, ec);
        }
        break;
      }
#endif
      default:
        key = d2i_PUBKEY_bio(in, NULL);
        break;
      }
      (void)BIO_reset(in);
    }
  }
  else
  {
    if (fmt == FORMAT_PEM)
    {
      key = PEM_read_bio_PrivateKey(in, NULL, NULL, (void*)passphrase);
      (void)BIO_reset(in);
    }
    else if (fmt == FORMAT_DER)
    {
      switch (type)
      {
#ifndef OPENSSL_NO_RSA
      case EVP_PKEY_RSA:
      {
        RSA *rsa = d2i_RSAPrivateKey_bio(in, NULL);
        if (rsa)
        {
          key = EVP_PKEY_new();
          EVP_PKEY_assign_RSA(key, rsa);
        }
        break;
      }
#endif
#ifndef OPENSSL_NO_DSA
      case EVP_PKEY_DSA:
      {
        DSA *dsa = d2i_DSAPrivateKey_bio(in, NULL);
        if (dsa)
        {
          key = EVP_PKEY_new();
          EVP_PKEY_assign_DSA(key, dsa);
        }
        break;
      }
#endif
#ifndef OPENSSL_NO_EC
      case EVP_PKEY_EC:
      {
        EC_KEY *ec = d2i_ECPrivateKey_bio(in, NULL);
        if (ec)
        {
          key = EVP_PKEY_new();
          EVP_PKEY_assign_EC_KEY(key, ec);
        }
        break;
      }
#endif
      default:
      {
        if (passphrase)
          key = d2i_PKCS8PrivateKey_bio(in, NULL, NULL, (void*)passphrase);
        else
          key = d2i_PrivateKey_bio(in, NULL);
        break;
      }
      }
      (void)BIO_reset(in);
    }
  }
  BIO_free(in);
  if (key)
    PUSH_OBJECT(key, "openssl.evp_pkey");

  return key ? 1 : openssl_pushresult(L, 0);
}

#ifndef OPENSSL_NO_EC
static int EC_KEY_generate_key_part(EC_KEY *eckey)
{
  int ok = 0;
  BN_CTX  *ctx = NULL;
  BIGNUM  *priv_key = NULL, *order = NULL;
  EC_POINT *pub_key = NULL;
  const EC_GROUP *group;

  group = EC_KEY_get0_group(eckey);

  if ((order = BN_new()) == NULL) goto err;
  if ((ctx = BN_CTX_new()) == NULL) goto err;
  priv_key = (BIGNUM*)EC_KEY_get0_private_key(eckey);

  if (priv_key == NULL) goto err;

  if (!EC_GROUP_get_order(group, order, ctx)) goto err;

  if (BN_is_zero(priv_key)) goto err;

  pub_key = (EC_POINT *)EC_KEY_get0_public_key(eckey);

  if (pub_key == NULL)
  {
    pub_key = EC_POINT_new(group);
    if (pub_key == NULL) goto err;
    EC_KEY_set_public_key(eckey, pub_key);
    EC_POINT_free(pub_key);
    pub_key = (EC_POINT *)EC_KEY_get0_public_key(eckey);
  }

  if (!EC_POINT_mul(group, pub_key, priv_key, NULL, NULL, ctx)) goto err;

  EC_POINT_make_affine(EC_KEY_get0_group(eckey), pub_key, NULL);

  ok = 1;

err:
  if (order) BN_free(order);
  if (ctx != NULL) BN_CTX_free(ctx);

  return (ok);
}
#endif

#define EC_GET_FIELD(_name)        {                                                  \
  lua_getfield(L, -1, #_name);                                                        \
  if (lua_isstring(L, -1)) {                                                          \
    size_t l = 0; const char* bn = luaL_checklstring(L, -1, &l);                      \
    if (_name == NULL)  _name = BN_new();                                             \
    BN_bin2bn((const unsigned char *)bn, l, _name);                                   \
  } else if (auxiliar_getclassudata(L, "openssl.bn", -1)) {                                 \
    const BIGNUM* bn = CHECK_OBJECT(-1, BIGNUM, "openssl.bn");                        \
    if (_name == NULL)  _name = BN_new();                                             \
    BN_copy(_name, bn);                                                               \
  } else if (!lua_isnil(L, -1))                                                       \
    luaL_error(L, "parameters must have \"%s\" field string or openssl.bn", #_name);  \
  lua_pop(L, 1);                                                                      \
}

/***
generate a new ec keypair
@function new
@tparam string alg, alg must be 'ec'
@tparam string|number curvename this can be integer as curvename NID
@tparam[opt] integer flags when alg is ec need this.
@treturn evp_pkey object with mapping to EVP_PKEY in openssl
*/
/***
generate a new keypair
@function new
@tparam[opt='rsa'] string alg, accept `rsa`,`dsa`,`dh`
@tparam[opt=2048|512] integer bits, `rsa` with 2048, `dh` or `dsa` with 1024
@tparam[opt] integer e, when alg is `rsa` give e value default is 0x10001,
 when alg is `dh` give generator value default is 2,
 when alg is `dsa` give string type seed value default is none.
@tparam[opt] engine eng
@treturn evp_pkey object with mapping to EVP_PKEY in openssl
*/
/***
create a new keypair by factors of keypair or get public key only
@function new
@tparam table factors to create private/public key, key alg only accept accept 'rsa','dsa','dh','ec' and must exist</br>
 when arg is rsa, table may with key n,e,d,p,q,dmp1,dmq1,iqmp, both are binary string or openssl.bn<br>
 when arg is dsa, table may with key p,q,g,priv_key,pub_key, both are binary string or openssl.bn<br>
 when arg is dh, table may with key p,g,priv_key,pub_key, both are binary string or openssl.bn<br>
 when arg is ec, table may with D,X,Y,Z,both are binary string or openssl.bn<br>
@treturn evp_pkey object with mapping to EVP_PKEY in openssl
@usage
 --create rsa public key
   pubkey = new({alg='rsa',n=...,e=...}
 --create new rsa
   rsa = new({alg='rsa',n=...,q=...,e=...,...}
*/
static LUA_FUNCTION(openssl_pkey_new)
{
  EVP_PKEY *pkey = NULL;
  const char* alg = "rsa";

  if (lua_isnoneornil(L, 1) || lua_isstring(L, 1))
  {
    alg = luaL_optstring(L, 1, alg);
#ifndef OPENSSL_NO_RSA
    if (strcasecmp(alg, "rsa") == 0)
    {
      int bits = luaL_optint(L, 2, 2048);
      int e = luaL_optint(L, 3, 65537);
      ENGINE *eng = lua_isnoneornil(L, 4) ? NULL : CHECK_OBJECT(4, ENGINE, "openssl.engine");
      BIGNUM *E = BN_new();
      BN_set_word(E, e);

      RSA *rsa = eng ? RSA_new_method(eng) : RSA_new();
      if (RSA_generate_key_ex(rsa, bits, E, NULL))
      {
        pkey = EVP_PKEY_new();
        EVP_PKEY_assign_RSA(pkey, rsa);
      }
      else
        RSA_free(rsa);

      BN_free(E);
    }
    else
#endif
#ifndef OPENSSL_NO_DSA
    if (strcasecmp(alg, "dsa") == 0)
    {
      int bits = luaL_optint(L, 2, 1024);
      size_t seed_len = 0;
      const char* seed = luaL_optlstring(L, 3, NULL, &seed_len);
      ENGINE *eng = lua_isnoneornil(L, 4) ? NULL : CHECK_OBJECT(4, ENGINE, "openssl.engine");

      DSA *dsa = eng ? DSA_new_method(eng) : DSA_new();
      if (DSA_generate_parameters_ex(dsa, bits, (byte*)seed, seed_len, NULL, NULL, NULL)
          && DSA_generate_key(dsa))
      {
        pkey = EVP_PKEY_new();
        EVP_PKEY_assign_DSA(pkey, dsa);
      }
      else
        DSA_free(dsa);
    }
    else
#endif
#ifndef OPENSSL_NO_DH
    if (strcasecmp(alg, "dh") == 0)
    {
      int bits = luaL_optint(L, 2, 1024);
      int generator = luaL_optint(L, 3, 2);
      ENGINE *eng = lua_isnoneornil(L, 4) ? NULL : CHECK_OBJECT(4, ENGINE, "openssl.engine");

#if (OPENSSL_VERSION_NUMBER >= 0x30000000L)
      EVP_PKEY_CTX *ctx = EVP_PKEY_CTX_new_from_name(NULL, "DH", NULL);
      if (ctx)
      {
        int ret = EVP_PKEY_paramgen_init(ctx);
        if (ret == 1)
        {
          ret = EVP_PKEY_keygen_init(ctx);
          if ( ret == 1)
          {
            ret = EVP_PKEY_CTX_set_dh_paramgen_prime_len(ctx, bits);
            if ( ret == 1)
            {
              ret = EVP_PKEY_CTX_set_dh_paramgen_generator(ctx, generator);
              if(ret == 1)
              {
                ret = EVP_PKEY_keygen(ctx, &pkey);
                if (ret == 1)
                  EVP_PKEY_set_type(pkey, EVP_PKEY_DH);
              }
            }
          }
        }
        EVP_PKEY_CTX_free(ctx);
      }
#else
      DH* dh = eng ? DH_new_method(eng) : DH_new();
      if (DH_generate_parameters_ex(dh, bits, generator, NULL))
      {
        if (DH_generate_key(dh))
        {
          pkey = EVP_PKEY_new();
          EVP_PKEY_assign_DH(pkey, dh);
        }
        else
          DH_free(dh);
      }
      else
        DH_free(dh);
#endif
    }
    else
#endif
#ifndef OPENSSL_NO_EC
    if (strcasecmp(alg, "ec") == 0)
    {
      EC_GROUP *group = openssl_get_ec_group(L, 2, 3, 4);
      if (!group) luaL_error(L, "failed to get ec_group object");

      EC_KEY *ec = NULL;
      ec = EC_KEY_new();
      if (ec)
      {
        EC_KEY_set_group(ec, group);
        EC_GROUP_free(group);
        if (EC_KEY_generate_key(ec))
        {
          pkey = EVP_PKEY_new();
          EVP_PKEY_assign_EC_KEY(pkey, ec);
        }
        else
          EC_KEY_free(ec);
      }
      else
        EC_GROUP_free(group);
    }
#endif
    else
    {
      luaL_error(L, "not support %s!!!!", alg);
    }
  }
  else if (lua_istable(L, 1))
  {
    lua_getfield(L, 1, "alg");
    alg = luaL_optstring(L, -1, alg);
    lua_pop(L, 1);
#ifndef OPENSSL_NO_RSA
    if (strcasecmp(alg, "rsa") == 0)
    {
      pkey = EVP_PKEY_new();
      if (pkey)
      {
        RSA *rsa = RSA_new();
        if (rsa)
        {
          BIGNUM *n = NULL, *e = NULL, *d = NULL;
          BIGNUM *p = NULL, *q = NULL;
          BIGNUM *dmp1 = NULL, *dmq1 = NULL, *iqmp = NULL;

          lua_getfield(L, 1, "n");
          n = BN_get(L, -1);
          lua_pop(L, 1);

          lua_getfield(L, 1, "e");
          e = BN_get(L, -1);
          lua_pop(L, 1);

          lua_getfield(L, 1, "d");
          d = BN_get(L, -1);
          lua_pop(L, 1);

          lua_getfield(L, 1, "p");
          p = BN_get(L, -1);
          lua_pop(L, 1);

          lua_getfield(L, 1, "q");
          q = BN_get(L, -1);
          lua_pop(L, 1);

          lua_getfield(L, 1, "dmp1");
          dmp1 = BN_get(L, -1);
          lua_pop(L, 1);
          lua_getfield(L, 1, "dmq1");
          dmq1 = BN_get(L, -1);
          lua_pop(L, 1);
          lua_getfield(L, 1, "iqmp");
          iqmp = BN_get(L, -1);
          lua_pop(L, 1);

          if (RSA_set0_key(rsa, n, e, d) == 1
              && (p == NULL || RSA_set0_factors(rsa, p, q) == 1)
              && (dmp1 == NULL || RSA_set0_crt_params(rsa, dmp1, dmq1, iqmp) == 1) )
          {
            if (!EVP_PKEY_assign_RSA(pkey, rsa))
            {
              RSA_free(rsa);
              rsa = NULL;
              EVP_PKEY_free(pkey);
              pkey = NULL;
            }
          }
          else
          {
            RSA_free(rsa);
            rsa = NULL;
            EVP_PKEY_free(pkey);
            pkey = NULL;
          }
        }
      }
    }
    else
#endif
#ifndef OPENSSL_NO_DSA
    if (strcasecmp(alg, "dsa") == 0)
    {
      pkey = EVP_PKEY_new();
      if (pkey)
      {
        DSA *dsa = DSA_new();
        if (dsa)
        {
          BIGNUM *p = NULL, *q = NULL, *g = NULL;
          BIGNUM *priv_key = NULL, *pub_key = NULL;

          lua_getfield(L, 1, "p");
          p = BN_get(L, -1);
          lua_pop(L, 1);

          lua_getfield(L, 1, "q");
          q = BN_get(L, -1);
          lua_pop(L, 1);

          lua_getfield(L, 1, "g");
          g = BN_get(L, -1);
          lua_pop(L, 1);

          lua_getfield(L, 1, "priv_key");
          priv_key = BN_get(L, -1);
          lua_pop(L, 1);

          lua_getfield(L, 1, "pub_key");
          pub_key = BN_get(L, -1);
          lua_pop(L, 1);

          if (DSA_set0_key(dsa, pub_key, priv_key) == 1
              && DSA_set0_pqg(dsa, p, q, g))
          {
            if (!EVP_PKEY_assign_DSA(pkey, dsa))
            {
              DSA_free(dsa);
              EVP_PKEY_free(pkey);
              pkey = NULL;
            }
          }
          else
          {
            DSA_free(dsa);
            dsa = NULL;
            EVP_PKEY_free(pkey);
            pkey = NULL;
          }
        }
      }
    }
    else
#endif
#ifndef OPENSSL_NO_DH
    if (strcasecmp(alg, "dh") == 0)
    {
      pkey = EVP_PKEY_new();
      if (pkey)
      {
        DH *dh = DH_new();
        if (dh)
        {
          BIGNUM *p = NULL, *q = NULL, *g = NULL;
          BIGNUM *priv_key = NULL, *pub_key = NULL;

          lua_getfield(L, 1, "p");
          p = BN_get(L, -1);
          lua_pop(L, 1);

          lua_getfield(L, 1, "q");
          q = BN_get(L, -1);
          lua_pop(L, 1);

          lua_getfield(L, 1, "g");
          g = BN_get(L, -1);
          lua_pop(L, 1);

          lua_getfield(L, 1, "priv_key");
          priv_key = BN_get(L, -1);
          lua_pop(L, 1);

          lua_getfield(L, 1, "pub_key");
          pub_key = BN_get(L, -1);
          lua_pop(L, 1);

          if (DH_set0_key(dh, pub_key, priv_key) == 1
              && DH_set0_pqg(dh, p, q, g))
          {
            if (!EVP_PKEY_assign_DH(pkey, dh))
            {
              DH_free(dh);
              dh = NULL;
              EVP_PKEY_free(pkey);
              pkey = NULL;
            }
          }
          else
          {
            DH_free(dh);
            dh = NULL;
            EVP_PKEY_free(pkey);
            pkey = NULL;
          }
        }
      }
    }
    else
#endif
#ifndef OPENSSL_NO_EC
    if (strcasecmp(alg, "ec") == 0)
    {
      BIGNUM *d = NULL;
      BIGNUM *x = NULL;
      BIGNUM *y = NULL;
      BIGNUM *z = NULL;
      EC_GROUP *group = NULL;

      lua_getfield(L, -1, "ec_name");
      lua_getfield(L, -2, "param_enc");
      lua_getfield(L, -3, "conv_form");
      group = openssl_get_ec_group(L, -3, -2, -1);
      lua_pop(L, 3);
      if (!group) luaL_error(L, "get openssl.ec_group fail");

      EC_GET_FIELD(d);
      EC_GET_FIELD(x);
      EC_GET_FIELD(y);
      EC_GET_FIELD(z);
      if (z) luaL_error(L, "only accpet affine co-ordinates");

      pkey = EVP_PKEY_new();
      if (pkey)
      {
        EC_KEY *ec = EC_KEY_new();
        if (ec)
        {
          EC_KEY_set_group(ec, group);
          if (d)
            EC_KEY_set_private_key(ec, d);
          if (x != NULL && y != NULL)
          {
            EC_POINT *pnt = EC_POINT_new(group);
            EC_POINT_set_affine_coordinates(group, pnt, x, y, NULL);

            EC_KEY_set_public_key(ec, pnt);
            EC_POINT_free(pnt);
          }
          else
            EC_KEY_generate_key_part(ec);

          if (EC_KEY_check_key(ec) == 0 || EVP_PKEY_assign_EC_KEY(pkey, ec) == 0)
          {
            EC_KEY_free(ec);
            EVP_PKEY_free(pkey);
            pkey = NULL;
          }

          BN_free(d);
          BN_free(x);
          BN_free(y);
          BN_free(z);
        }
      }
      EC_GROUP_free(group);
    }
#endif
  }
  else
#ifndef OPENSSL_NO_RSA
  if (auxiliar_getclassudata(L, "openssl.rsa", 1))
  {
    RSA* rsa = CHECK_OBJECT(1, RSA, "openssl.rsa");
    pkey = EVP_PKEY_new();
    EVP_PKEY_set1_RSA(pkey, rsa);
  }
  else
#endif
#ifndef OPENSSL_NO_EC
  if (auxiliar_getclassudata(L, "openssl.ec_key", 1))
  {
    EC_KEY* ec = CHECK_OBJECT(1, EC_KEY, "openssl.ec_key");
    pkey = EVP_PKEY_new();
    EVP_PKEY_set1_EC_KEY(pkey, ec);
  }
  else
#endif
#ifndef OPENSSL_NO_DH
  if (auxiliar_getclassudata(L, "openssl.dh", 1))
  {
    DH *dh= CHECK_OBJECT(1, DH, "openssl.dh");
    pkey = EVP_PKEY_new();
    EVP_PKEY_set1_DH(pkey, dh);
  }
  else
#endif
#ifndef OPENSSL_NO_DSA
  if (auxiliar_getclassudata(L, "openssl.dsa", 1))
  {
    DSA *dsa = CHECK_OBJECT(1, DSA, "openssl.dsa");
    pkey = EVP_PKEY_new();
    EVP_PKEY_set1_DSA(pkey, dsa);
  }
#endif

  if (pkey && EVP_PKEY_id(pkey) != NID_undef)
  {
    PUSH_OBJECT(pkey, "openssl.evp_pkey");
    return 1;
  }
  else
    EVP_PKEY_free(pkey);
  return 0;
}

/***
openssl.evp_pkey object
@type evp_pkey
*/
/***
export evp_pkey as pem/der string
@function export
@tparam[opt='pem'] string support export as 'pem' or 'der' format, default is 'pem'
@tparam[opt=false] boolean raw true for export low layer key just rsa,dsa,ec
@tparam[opt] string passphrase if given, export key will encrypt with aes-128-cbc,
only need when export private key
@treturn string
*/
static LUA_FUNCTION(openssl_pkey_export)
{
  EVP_PKEY * key;
  int ispriv = 0;
  int exraw = 0;
  int fmt = FORMAT_AUTO;
  size_t passphrase_len = 0;
  BIO * bio_out = NULL;
  int ret = 0;
  const EVP_CIPHER * cipher;
  const char * passphrase = NULL;

  key = CHECK_OBJECT(1, EVP_PKEY, "openssl.evp_pkey");
  ispriv = openssl_pkey_is_private(key);

  fmt = lua_type(L, 2);
  luaL_argcheck(L, fmt == LUA_TSTRING || fmt == LUA_TNONE, 2,
                "only accept 'pem','der' or none");
  fmt = luaL_checkoption(L, 2, "pem", format);
  luaL_argcheck(L, fmt == FORMAT_PEM || fmt == FORMAT_DER, 2,
                "only accept pem or der, default is pem");

  if (!lua_isnone(L, 3))
    exraw = lua_toboolean(L, 3);
  passphrase = luaL_optlstring(L, 4, NULL, &passphrase_len);

  if (passphrase)
  {
    cipher = (EVP_CIPHER *) EVP_aes_128_cbc();
  }
  else
  {
    cipher = NULL;
  }

  bio_out = BIO_new(BIO_s_mem());
  if (fmt == FORMAT_PEM)
  {
    if (exraw == 0)
    {
      ret = ispriv ? PEM_write_bio_PrivateKey(bio_out,
                                              key,
                                              cipher,
                                              (unsigned char *)passphrase,
                                              passphrase_len,
                                              NULL,
                                              NULL)
                  : PEM_write_bio_PUBKEY(bio_out, key);
    }
    else
    {
      /* export raw key format */
      switch (EVP_PKEY_type(EVP_PKEY_id(key)))
      {
#ifndef OPENSSL_NO_RSA
      case EVP_PKEY_RSA:
        ret = ispriv
            ? PEM_write_bio_RSAPrivateKey(bio_out,
                                          EVP_PKEY_get0_RSA(key),
                                          cipher,
                                          (unsigned char *)passphrase,
                                          passphrase_len,
                                          NULL,
                                          NULL)
            : PEM_write_bio_RSAPublicKey(bio_out, EVP_PKEY_get0_RSA(key));
        break;
#endif
#ifndef OPENSSL_NO_DSA
      case EVP_PKEY_DSA:
      {
        ret = ispriv
            ? PEM_write_bio_DSAPrivateKey(bio_out,
                                          EVP_PKEY_get0_DSA(key),
                                          cipher,
                                          (unsigned char *)passphrase,
                                          passphrase_len,
                                          NULL,
                                          NULL)
            : PEM_write_bio_DSA_PUBKEY(bio_out, EVP_PKEY_get0_DSA(key));
      }
      break;
#endif
#ifndef OPENSSL_NO_EC
      case EVP_PKEY_EC:
        ret = ispriv
            ? PEM_write_bio_ECPrivateKey(bio_out,
                                         EVP_PKEY_get0_EC_KEY(key),
                                         cipher,
                                         (unsigned char *)passphrase,
                                         passphrase_len,
                                         NULL,
                                         NULL)
            : PEM_write_bio_EC_PUBKEY(bio_out, EVP_PKEY_get0_EC_KEY(key));
        break;
#endif
      default:
        break;
      }
    }
  }
  else
  {
    /* out put der */
    if (exraw == 0)
    {
      ret = ispriv ? ( passphrase == NULL
                     ? i2d_PrivateKey_bio(bio_out, key)
                     : i2d_PKCS8PrivateKey_bio(bio_out, key,
                                               cipher,
                                               (char *)passphrase,
                                               passphrase_len,
                                               NULL,
                                               NULL)
                    )
                  : i2d_PUBKEY_bio(bio_out, key);
    }
    else
    {
      /* output raw key, rsa, ec, dh, dsa */
      switch (EVP_PKEY_type(EVP_PKEY_id(key)))
      {
#ifndef OPENSSL_NO_RSA
      case EVP_PKEY_RSA:
        ret = ispriv ? i2d_RSAPrivateKey_bio(bio_out, EVP_PKEY_get0_RSA(key))
                     : i2d_RSAPublicKey_bio(bio_out, EVP_PKEY_get0_RSA(key));
        break;
#endif
#ifndef OPENSSL_NO_DSA
      case EVP_PKEY_DSA:
      {
        ret = ispriv ? i2d_DSAPrivateKey_bio(bio_out, EVP_PKEY_get0_DSA(key))
                     : i2d_DSA_PUBKEY_bio(bio_out, EVP_PKEY_get0_DSA(key));
      }
      break;
#endif
#ifndef OPENSSL_NO_EC
      case EVP_PKEY_EC:
        ret = ispriv ? i2d_ECPrivateKey_bio(bio_out, EVP_PKEY_get0_EC_KEY(key))
                     : i2d_EC_PUBKEY_bio(bio_out, EVP_PKEY_get0_EC_KEY(key));
        break;
#endif
      default:
        ret = ispriv ? i2d_PrivateKey_bio(bio_out, key)
                     : i2d_PUBKEY_bio(bio_out, key);
      }
    }
  }

  if (ret)
  {
    char * bio_mem_ptr;
    long bio_mem_len;

    bio_mem_len = BIO_get_mem_data(bio_out, &bio_mem_ptr);

    lua_pushlstring(L, bio_mem_ptr, bio_mem_len);
    ret  = 1;
  }

  if (bio_out) BIO_free(bio_out);

  return ret;
}

static LUA_FUNCTION(openssl_pkey_free)
{
  EVP_PKEY *pkey = CHECK_OBJECT(1, EVP_PKEY, "openssl.evp_pkey");
  EVP_PKEY_free(pkey);
  return 0;
}

/* copy from openssl v3 crypto/evp/p_lib.c */
/*
 * These hard coded cases are pure hackery to get around the fact
 * that names in crypto/objects/objects.txt are a mess.  There is
 * no "EC", and "RSA" leads to the NID for 2.5.8.1.1, an OID that's
 * fallen out in favor of { pkcs-1 1 }, i.e. 1.2.840.113549.1.1.1,
 * the NID of which is used for EVP_PKEY_RSA.  Strangely enough,
 * "DSA" is accurate...  but still, better be safe and hard-code
 * names that we know.
 * On a similar topic, EVP_PKEY_type(EVP_PKEY_SM2) will result in
 * EVP_PKEY_EC, because of aliasing.
 * This should be cleaned away along with all other #legacy support.
 */

#if OPENSSL_VERSION_NUMBER < 0x30000000L
typedef struct ossl_item_st
{
  unsigned int id;
  void *ptr;
} OSSL_ITEM;
#endif
static const OSSL_ITEM standard_name2type[] =
{
#ifdef EVP_PKEY_RSA
  { EVP_PKEY_RSA,     "RSA" },
#endif
#ifdef EVP_PKEY_RSA_PSS
  { EVP_PKEY_RSA_PSS, "RSA-PSS" },
#endif
#ifdef EVP_PKEY_EC
  { EVP_PKEY_EC,      "EC" },
#endif
#ifdef EVP_PKEY_ED25519
  { EVP_PKEY_ED25519, "ED25519" },
#endif
#ifdef EVP_PKEY_ED448
  { EVP_PKEY_ED448,   "ED448" },
#endif
#ifdef EVP_PKEY_X25519
  { EVP_PKEY_X25519,  "X25519" },
#endif
#ifdef EVP_PKEY_X448
  { EVP_PKEY_X448,    "X448" },
#endif
#ifdef EVP_PKEY_SM2
  { EVP_PKEY_SM2,     "SM2" },
#endif
#ifdef EVP_PKEY_DH
  { EVP_PKEY_DH,      "DH" },
#endif
#ifdef EVP_PKEY_DHX
  { EVP_PKEY_DHX,     "X9.42 DH" },
#endif
#ifdef EVP_PKEY_DHX
  { EVP_PKEY_DHX,     "DHX" },
#endif
#ifdef EVP_PKEY_DSA
  { EVP_PKEY_DSA,     "DSA" },
#endif
};

#define OSSL_NELEM(ary) (sizeof(ary)/sizeof(ary[0]))

static int evp_pkey_name2type(const char *name)
{
  size_t i;

  for (i = 0; i < OSSL_NELEM(standard_name2type); i++)
  {
    if (strcasecmp(name, standard_name2type[i].ptr) == 0)
      return (int)standard_name2type[i].id;
  }

  return -1;
}

static const char *evp_pkey_type2name(int type)
{
  size_t i;
  const char *ret = NULL;

  for (i = 0; i < OSSL_NELEM(standard_name2type); i++)
  {
    if (type == (int)standard_name2type[i].id)
    {
      ret = standard_name2type[i].ptr;
      break;
    }
  }

  return ret;
}

/***
get key details as table
@function parse
@treturn table infos with key bits,pkey,type, pkey may be rsa,dh,dsa, show as table with factor hex encoded bignum
*/
static LUA_FUNCTION(openssl_pkey_parse)
{
  EVP_PKEY *pkey = CHECK_OBJECT(1, EVP_PKEY, "openssl.evp_pkey");
  int typ = EVP_PKEY_id(pkey);

  lua_newtable(L);

  AUXILIAR_SET(L, -1, "bits", EVP_PKEY_bits(pkey), integer);
  AUXILIAR_SET(L, -1, "size", EVP_PKEY_size(pkey), integer);
  AUXILIAR_SET(L, -1, "type", evp_pkey_type2name(typ), string);

  switch (typ)
  {
#ifndef OPENSSL_NO_RSA
  case EVP_PKEY_RSA:
  {
    RSA* rsa = EVP_PKEY_get1_RSA(pkey);
    PUSH_OBJECT(rsa, "openssl.rsa");
    lua_setfield(L, -2, "rsa");
  }
  break;
#endif
#ifndef OPENSSL_NO_DSA
  case EVP_PKEY_DSA:
  {
    DSA* dsa = EVP_PKEY_get1_DSA(pkey);
    PUSH_OBJECT(dsa, "openssl.dsa");
    lua_setfield(L, -2, "dsa");
  }
  break;
#endif
#ifndef OPENSSL_NO_DH
  case EVP_PKEY_DH:
  {
    DH* dh = EVP_PKEY_get1_DH(pkey);
    PUSH_OBJECT(dh, "openssl.dh");
    lua_setfield(L, -2, "dh");
  }
  break;
#endif
#if OPENSSL_VERSION_NUMBER > 0x30000000
#ifndef OPENSSL_NO_SM2
  case EVP_PKEY_SM2:
  {
    const EC_KEY* ec = EVP_PKEY_get1_EC_KEY(pkey);
    PUSH_OBJECT(ec, "openssl.ec_key");
    lua_setfield(L, -2, "sm2");
  }
  break;
#endif
#endif
#ifndef OPENSSL_NO_EC
  case EVP_PKEY_EC:
#if OPENSSL_VERSION_NUMBER < 0x30000000
#ifdef EVP_PKEY_SM2
  case EVP_PKEY_SM2:
#endif
#endif
  {
    const EC_KEY* ec = EVP_PKEY_get1_EC_KEY(pkey);
    PUSH_OBJECT(ec, "openssl.ec_key");
    lua_setfield(L, -2, "ec");
  }
  break;
#endif

  default:
  break;
  };
  return 1;
};

/***
encrypt message with public key
encrypt length of message must not longer than key size, if shorter will do padding,currently supports 6 padding modes.
They are: pkcs1, sslv23, no, oaep, x931, pss.
@function encrypt
@tparam string data data to be encrypted
@tparam string[opt='pkcs1'] string padding padding mode
@treturn string encrypted message
*/
static LUA_FUNCTION(openssl_pkey_encrypt)
{
  size_t dlen = 0;
  EVP_PKEY *pkey = CHECK_OBJECT(1, EVP_PKEY, "openssl.evp_pkey");
  const char *data = luaL_checklstring(L, 2, &dlen);
  int padding = openssl_get_padding(L, 3, "pkcs1");
  ENGINE *engine = lua_isnoneornil(L, 4) ? NULL : CHECK_OBJECT(4, ENGINE, "openssl.engine");
  size_t clen = EVP_PKEY_size(pkey);
  EVP_PKEY_CTX *ctx = NULL;
  int ret = 0;
  int typ = EVP_PKEY_type(EVP_PKEY_id(pkey));

  luaL_argcheck(L,
                typ == EVP_PKEY_RSA || typ == EVP_PKEY_RSA2,
                1,
                "EVP_PKEY must be of type RSA or RSA2");

  ctx = EVP_PKEY_CTX_new(pkey, engine);
  if (EVP_PKEY_encrypt_init(ctx) == 1)
  {
    if (EVP_PKEY_CTX_set_rsa_padding(ctx, padding) == 1)
    {
      byte* buf = malloc(clen);
      if (EVP_PKEY_encrypt(ctx, buf, &clen, (const unsigned char*)data, dlen) == 1)
      {
        lua_pushlstring(L, (const char*)buf, clen);
        ret = 1;
      }
      free(buf);
    }
  }
  EVP_PKEY_CTX_free(ctx);

  return ret;
}

/***
decrypt message with private key
pair with encrypt
@function decrypt
@tparam string data data to be decrypted
@tparam string[opt='pkcs1'] string padding padding mode
@treturn[1] string result
@treturn[2] nil
*/
static LUA_FUNCTION(openssl_pkey_decrypt)
{
  size_t dlen = 0;
  EVP_PKEY *pkey = CHECK_OBJECT(1, EVP_PKEY, "openssl.evp_pkey");
  const char *data = luaL_checklstring(L, 2, &dlen);
  int padding = openssl_get_padding(L, 3, "pkcs1");
  ENGINE *engine = lua_isnoneornil(L, 4) ? NULL : CHECK_OBJECT(4, ENGINE, "openssl.engine");
  size_t clen = EVP_PKEY_size(pkey);
  EVP_PKEY_CTX *ctx = NULL;
  int ret = 0;
  int type = EVP_PKEY_type(EVP_PKEY_id(pkey));

  luaL_argcheck(L,
                type == EVP_PKEY_RSA || type == EVP_PKEY_RSA2,
                1,
                "EVP_PKEY must be of type RSA or RSA2");

  ctx = EVP_PKEY_CTX_new(pkey, engine);
  if (EVP_PKEY_decrypt_init(ctx) == 1)
  {
    if (EVP_PKEY_CTX_set_rsa_padding(ctx, padding) == 1)
    {
      byte* buf = malloc(clen);

      if (EVP_PKEY_decrypt(ctx, buf, &clen, (const unsigned char*)data, dlen) == 1)
      {
        lua_pushlstring(L, (const char*)buf, clen);
        ret = 1;
      }
      free(buf);
    }
  }
  EVP_PKEY_CTX_free(ctx);

  return ret;
}

/***
return key is private or not
@function is_private
@treturn boolean ture is private or public key
*/
LUA_FUNCTION(openssl_pkey_is_private1)
{
  EVP_PKEY *pkey = CHECK_OBJECT(1, EVP_PKEY, "openssl.evp_pkey");
  int private = openssl_pkey_is_private(pkey);
  luaL_argcheck(L,
                private == 0 || private == 1,
                1,
                "not support");

  lua_pushboolean(L, private);
  return 1;
}

/***
return public key
@function get_public
@treturn evp_pkey pub
*/
static LUA_FUNCTION(openssl_pkey_get_public)
{
  EVP_PKEY *pkey = CHECK_OBJECT(1, EVP_PKEY, "openssl.evp_pkey");
  int ret = 0;

  size_t len = i2d_PUBKEY(pkey, NULL);
  if (len > 0)
  {
    unsigned char *buf = OPENSSL_malloc(len);
    if (buf != NULL)
    {
      unsigned char *p = buf;
      EVP_PKEY *pub;
      len = i2d_PUBKEY(pkey, &p);
      p = buf;
      pub = d2i_PUBKEY(NULL, (const unsigned char **)&p, len);
      if (pub)
      {
        PUSH_OBJECT(pub, "openssl.evp_pkey");
        ret = 1;
      }
      OPENSSL_free(buf);
    }
  }

  return ret;
}

static LUA_FUNCTION(openssl_pkey_ctx)
{
  EVP_PKEY *pkey = CHECK_OBJECT(1, EVP_PKEY, "openssl.evp_pkey");
  ENGINE *engine = lua_isnoneornil(L, 2) ? NULL : CHECK_OBJECT(2, ENGINE, "openssl.engine");
  EVP_PKEY_CTX *ctx = NULL;
  int typ = EVP_PKEY_type(EVP_PKEY_id(pkey));

  luaL_argcheck(L,
                typ == EVP_PKEY_RSA || typ == EVP_PKEY_RSA2,
                1,
                "EVP_PKEY must be of type RSA or RSA2");

  ctx = EVP_PKEY_CTX_new(pkey, engine);
  PUSH_OBJECT(ctx, "openssl.evp_pkey_ctx");
  return 1;
}

static LUA_FUNCTION(openssl_pkey_ctx_new)
{
  int nid = lua_isnumber(L, 1) ? lua_tointeger(L, 1) : OBJ_txt2nid(luaL_checkstring(L, 1));
  ENGINE *eng = lua_isnoneornil(L, 2) ? NULL : CHECK_OBJECT(2, ENGINE, "openssl.engine");
  EVP_PKEY_CTX *pctx;

  luaL_argcheck(L, nid > 0, 1, "invalid public key algorithm");

  pctx = EVP_PKEY_CTX_new_id(nid, eng);
  if (pctx)
  {
    PUSH_OBJECT(pctx, "openssl.evp_pkey_ctx");
    return 1;
  }
  return openssl_pushresult(L, 0);
}

static LUA_FUNCTION(openssl_pkey_ctx_free)
{
  EVP_PKEY_CTX *ctx = CHECK_OBJECT(1, EVP_PKEY_CTX, "openssl.evp_pkey_ctx");
  EVP_PKEY_CTX_free(ctx);
  return 0;
}

static LUA_FUNCTION(openssl_pkey_ctx_keygen)
{
  EVP_PKEY_CTX *ctx = CHECK_OBJECT(1, EVP_PKEY_CTX, "openssl.evp_pkey_ctx");
  int bits = luaL_optinteger(L, 2, 0);
  EVP_PKEY *pkey = NULL;

  int ret = EVP_PKEY_keygen_init(ctx);
  if (ret==1)
  {
    ret = EVP_PKEY_keygen(ctx, &pkey);
  }
  if (ret==1)
  {
    PUSH_OBJECT(pkey, "openssl.evp_pkey");
  }
  else if (ret==-2)
  {
    lua_pushnil(L);
    lua_pushstring(L, "NOT_SUPPORT");
    ret = 2;
  }
  else
    ret = openssl_pushresult(L, ret);

  (void)bits;
  return ret;
}

static LUA_FUNCTION(openssl_pkey_ctx_ctrl)
{
  EVP_PKEY_CTX *ctx = CHECK_OBJECT(1, EVP_PKEY_CTX, "openssl.evp_pkey_ctx");
  size_t dlen = 0;
  const char *name = luaL_checklstring(L, 2, &dlen);
  const char *value = luaL_checklstring(L, 3, &dlen);
  const int res = EVP_PKEY_CTX_ctrl_str(ctx, name, value);
  lua_pushboolean(L, res > 0);

  return 1;
}

static LUA_FUNCTION(openssl_pkey_ctx_decrypt_init)
{
  EVP_PKEY_CTX *ctx = CHECK_OBJECT(1, EVP_PKEY_CTX, "openssl.evp_pkey_ctx");

  if (EVP_PKEY_decrypt_init(ctx) <= 0)
    return openssl_pushresult(L, 0);

  lua_pushvalue(L, 1);
  return 1;
}

static LUA_FUNCTION(openssl_pkey_ctx_encrypt_init)
{
  EVP_PKEY_CTX *ctx = CHECK_OBJECT(1, EVP_PKEY_CTX, "openssl.evp_pkey_ctx");

  if (EVP_PKEY_encrypt_init(ctx) <= 0)
    return openssl_pushresult(L, 0);

  lua_pushvalue(L, 1);
  return 1;
}

static LUA_FUNCTION(openssl_pkey_ctx_verify_init)
{
  EVP_PKEY_CTX *ctx = CHECK_OBJECT(1, EVP_PKEY_CTX, "openssl.evp_pkey_ctx");

  if (EVP_PKEY_verify_init(ctx) <= 0)
    return openssl_pushresult(L, 0);

  lua_pushvalue(L, 1);
  return 1;
}

static LUA_FUNCTION(openssl_pkey_ctx_sign_init)
{
  EVP_PKEY_CTX *ctx = CHECK_OBJECT(1, EVP_PKEY_CTX, "openssl.evp_pkey_ctx");

  if (EVP_PKEY_sign_init(ctx) <= 0)
    return openssl_pushresult(L, 0);

  lua_pushvalue(L, 1);
  return 1;
}

static LUA_FUNCTION(openssl_pkey_ctx_decrypt)
{
  EVP_PKEY_CTX *ctx = CHECK_OBJECT(1, EVP_PKEY_CTX, "openssl.evp_pkey_ctx");
  size_t dlen = 0;
  const char *data = luaL_checklstring(L, 2, &dlen);
  int ret = 0;

  size_t clen = dlen;
  byte* buf = malloc(clen);
  if (EVP_PKEY_decrypt(ctx, buf, &clen, (const unsigned char*)data, dlen) == 1)
  {
    lua_pushlstring(L, (const char*)buf, clen);
    ret = 1;
  }
  free(buf);

  return ret;
}

static LUA_FUNCTION(openssl_pkey_ctx_encrypt)
{
  EVP_PKEY_CTX *ctx = CHECK_OBJECT(1, EVP_PKEY_CTX, "openssl.evp_pkey_ctx");
  size_t in_len = 0;
  const char *in = luaL_checklstring(L, 2, &in_len);
  int ret = 0;
  size_t buf_len = 0;
  byte* buf = NULL;

  if (EVP_PKEY_encrypt(ctx, NULL, &buf_len, (const unsigned char*)in, in_len) > 0)
  {
    buf = malloc(buf_len);
    if (EVP_PKEY_encrypt(ctx, buf, &buf_len, (const unsigned char*)in, in_len) > 0)
    {
      lua_pushlstring(L, (const char*)buf, buf_len);
      ret = 1;
    }
    free(buf);
  }

  return ret;
}

static LUA_FUNCTION(openssl_pkey_ctx_verify)
{
  EVP_PKEY_CTX *pCtx = CHECK_OBJECT(1, EVP_PKEY_CTX, "openssl.evp_pkey_ctx");
  size_t dlen = 0;
  const char *data = luaL_checklstring(L, 2, &dlen);
  size_t slen = 0;
  const char *sign = luaL_checklstring(L, 3, &slen);

  int ret = EVP_PKEY_verify(pCtx,
                            (const unsigned char*)data, dlen,
                            (const unsigned char*)sign, slen);
  lua_pushboolean(L, ret > 0);

  return 1;
}


static LUA_FUNCTION(openssl_pkey_ctx_sign)
{
  EVP_PKEY_CTX *pCtx = CHECK_OBJECT(1, EVP_PKEY_CTX, "openssl.evp_pkey_ctx");
  size_t digest_len = 0;
  const char *digest = luaL_checklstring(L, 2, &digest_len);
  size_t sig_len = 0;
  unsigned char* sig = NULL;
  int ret = 0;

  if (EVP_PKEY_sign(pCtx, NULL, &sig_len, (const unsigned char*)digest, digest_len) > 0)
  {
    sig = malloc(sig_len);
    if (EVP_PKEY_sign(pCtx, sig, &sig_len, (const unsigned char*)digest, digest_len) > 0)
    {
      lua_pushlstring(L, (const char*)sig, sig_len);
      ret = 1;
    }
    free(sig);
  }

  return ret;
}

/***
Derive public key algorithm shared secret

@function derive
@tparam evp_pkey pkey private key
@tparam evp_pkey peer public key
@tparam[opt] engine eng
@treturn string
*/
static LUA_FUNCTION(openssl_derive)
{
  int ret = 0;

  EVP_PKEY* pkey = CHECK_OBJECT(1, EVP_PKEY, "openssl.evp_pkey");
  EVP_PKEY* peer = CHECK_OBJECT(2, EVP_PKEY, "openssl.evp_pkey");
  ENGINE *eng = lua_isnoneornil(L, 3) ? NULL : CHECK_OBJECT(3, ENGINE, "openssl.engine");
  EVP_PKEY_CTX *ctx;
  int ptype = EVP_PKEY_type(EVP_PKEY_id(pkey));

#if !defined(OPENSSL_NO_DH) && !defined(OPENSSL_NO_EC)
  luaL_argcheck(L,
                (ptype == EVP_PKEY_DH && EVP_PKEY_get0_DH(pkey)!=NULL) ||
                (ptype == EVP_PKEY_EC && EVP_PKEY_get0_EC_KEY(pkey)!=NULL),
                1,
                "only support DH or EC private key");
#elif !defined(OPENSSL_NO_DH)
  luaL_argcheck(L,
                ptype == EVP_PKEY_DH && EVP_PKEY_get0_DH(pkey)!=NULL,
                1,
                "only support DH or EC private key");
#elif !defined(OPENSSL_NO_EC)
  luaL_argcheck(L,
                ptype == EVP_PKEY_EC && EVP_PKEY_get0_EC_KEY(pkey)!=NULL,
                1,
                "only support DH or EC private key");
#endif

  luaL_argcheck(L,
                ptype == EVP_PKEY_type(EVP_PKEY_id(peer)),
                2,
                "mismatch key type");

  ctx = EVP_PKEY_CTX_new(pkey, eng);
  if (ctx)
  {
    ret = EVP_PKEY_derive_init(ctx);
    if (ret==1)
    {
      ret = EVP_PKEY_derive_set_peer(ctx, peer);
      if (ret==1)
      {
        size_t skeylen;
        ret = EVP_PKEY_derive(ctx, NULL, &skeylen);
        if (ret==1)
        {
          unsigned char *skey = OPENSSL_malloc(skeylen);
          if (skey)
          {
            ret = EVP_PKEY_derive(ctx, skey, &skeylen);
            if (ret==1)
            {
              lua_pushlstring(L, (const char*)skey, skeylen);
              OPENSSL_free(skey);
            }
          }
        }
      }
    }
    EVP_PKEY_CTX_free(ctx);
  }

  return ret==1 ? 1 : openssl_pushresult(L, ret);
}

/***
sign message with private key
@function sign
@tparam string data data be signed
@tparam[opt] string|env_digest md_alg default use sha256 or sm3 when pkey is SM2 type
@tparam[opt='1234567812345678'] string userId used when pkey is SM2 type
@treturn string signed message
*/
static LUA_FUNCTION(openssl_sign)
{
  int ret = 0;
  size_t data_len;
  const char *data;
  const char *md_alg;
  EVP_PKEY *pkey;
  const EVP_MD *md;
  EVP_MD_CTX *ctx;

#if defined(OPENSSL_SUPPORT_SM2)
  int is_SM2 = 0;
  EVP_PKEY_CTX* pctx = NULL;
#endif

  pkey = CHECK_OBJECT(1, EVP_PKEY, "openssl.evp_pkey");
  data = luaL_checklstring(L, 2, &data_len);

  md_alg = "sha256";
#if defined(OPENSSL_SUPPORT_SM2)
  is_SM2 = openssl_pkey_is_sm2(pkey);
  if (is_SM2)
    md_alg = "sm3";
#endif

  md = get_digest(L, 3, md_alg);
#if defined(OPENSSL_SUPPORT_SM2)
  if (is_SM2)
    is_SM2 = EVP_MD_type(md) == NID_sm3;
#endif

  ctx = EVP_MD_CTX_create();
#if defined(OPENSSL_SUPPORT_SM2)
  if (is_SM2)
  {
    size_t idlen = 0;

    const char* userId = luaL_optlstring (L, 4, SM2_DEFAULT_USERID, &idlen);
#if OPENSSL_VERSION_NUMBER > 0x30000000
    pctx = EVP_PKEY_CTX_new_from_name(NULL, "sm2", NULL);
#else
    pctx = EVP_PKEY_CTX_new(pkey, NULL);
#endif
    EVP_PKEY_CTX_set1_id(pctx, userId, idlen);
    EVP_MD_CTX_set_pkey_ctx(ctx, pctx);
  }
#endif

  ret = EVP_DigestSignInit(ctx, NULL, md, NULL, pkey);
  if (ret == 1)
  {
    ret = EVP_DigestSignUpdate(ctx, data, data_len);
    if (ret == 1)
    {
      size_t siglen = 0;
      unsigned char *sigbuf = NULL;
      ret = EVP_DigestSignFinal(ctx, NULL, &siglen);
      if (ret == 1)
      {
        siglen += 2;
        sigbuf = OPENSSL_malloc(siglen);
        ret = EVP_DigestSignFinal(ctx, sigbuf, &siglen);
        if (ret == 1)
        {
          lua_pushlstring(L, (char *)sigbuf, siglen);
        }
        OPENSSL_free(sigbuf);
      }
    }
  }

  EVP_MD_CTX_destroy(ctx);
#if defined(OPENSSL_SUPPORT_SM2)
  if (pctx)
    EVP_PKEY_CTX_free(pctx);
#endif

  return ret==1 ? 1 : openssl_pushresult(L, ret);
}

/***
verify signed message with public key
@function verify
@tparam string data data be signed
@tparam string signature signed result
@tparam[opt] string|env_digest md_alg default use sha256 or sm3 when pkey is SM2 type
@tparam[opt='1234567812345678'] string userId used when pkey is SM2 type
@treturn boolean true for pass verify
*/
static LUA_FUNCTION(openssl_verify)
{
  int ret = 0;
  size_t data_len, signature_len;
  const char *data, *signature;
  const char *md_alg;
  EVP_PKEY *pkey;
  const EVP_MD *md;
  EVP_MD_CTX *ctx;

#if defined(OPENSSL_SUPPORT_SM2)
  int is_SM2 = 0;
  EVP_PKEY_CTX* pctx = NULL;
#endif

  pkey = CHECK_OBJECT(1, EVP_PKEY, "openssl.evp_pkey");
  data = luaL_checklstring(L, 2, &data_len);
  signature = luaL_checklstring(L, 3, &signature_len);

  md_alg = "sha256";
#if defined(OPENSSL_SUPPORT_SM2)
  is_SM2 = openssl_pkey_is_sm2(pkey);
  if (is_SM2)
    md_alg = "sm3";
#endif

  md = get_digest(L, 4, md_alg);

  ctx = EVP_MD_CTX_create();
#if defined(OPENSSL_SUPPORT_SM2)
  if (is_SM2)
  {
    size_t idlen = 0;

    const char* userId = luaL_optlstring (L, 5, SM2_DEFAULT_USERID, &idlen);

#if OPENSSL_VERSION_NUMBER > 0x30000000
    pctx = EVP_PKEY_CTX_new_from_name(NULL, "sm2", NULL);
#else
    pctx = EVP_PKEY_CTX_new(pkey, NULL);
#endif
    EVP_PKEY_CTX_set1_id(pctx, userId, idlen);
    EVP_MD_CTX_set_pkey_ctx(ctx, pctx);
  }
#endif

  ret = EVP_DigestVerifyInit(ctx, NULL, md, NULL, pkey);
  if (ret == 1)
  {
    ret = EVP_DigestVerifyUpdate(ctx, data, data_len);
    if (ret == 1)
    {
      ret = EVP_DigestVerifyFinal(ctx, (unsigned char *)signature, signature_len);
      if (ret == 1)
      {
        lua_pushboolean(L, ret == 1);
      }
    }
  }

  EVP_MD_CTX_destroy(ctx);
#if defined(OPENSSL_SUPPORT_SM2)
  if (pctx)
    EVP_PKEY_CTX_free(pctx);
#endif

  return ret==1 ? 1 : openssl_pushresult(L, ret);
}

/***
seal and encrypt message with one public key
data be encrypt with secret key, secret key be encrypt with public key
@function seal
@tparam string data data to be encrypted
@tparam[opt='RC4'] cipher|string alg
@treturn string data encrypted
@treturn string skey secret key encrypted by public key
@treturn string iv
*/
static LUA_FUNCTION(openssl_seal)
{
  int i, ret = 0, nkeys = 0;
  size_t data_len;
  const char *data = NULL;

  EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
  EVP_PKEY **pkeys;
  unsigned char **eks;
  int *eksl;
  int len1, len2;
  unsigned char *buf;
  char iv[EVP_MAX_MD_SIZE] = {0};
  const EVP_CIPHER *cipher = NULL;

  luaL_argcheck(L,
                lua_istable(L, 1) || auxiliar_getclassudata(L, "openssl.evp_pkey", 1),
                1,
                "must be openssl.evp_pkey or array");

  if (lua_istable(L, 1))
  {
    nkeys = lua_rawlen(L, 1);
    luaL_argcheck(L, nkeys!=0, 1, "empty array");
  }
  else if (auxiliar_getclassudata(L, "openssl.evp_pkey", 1))
  {
    nkeys = 1;
  }

  data = luaL_checklstring(L, 2, &data_len);
  cipher = get_cipher(L, 3, "aes-128-cbc");

  pkeys = malloc(nkeys * sizeof(EVP_PKEY *));
  eksl = malloc(nkeys * sizeof(int));
  eks = malloc(nkeys * sizeof(char*));

  memset(eks, 0, sizeof(char*) * nkeys);

  /* get the public keys we are using to seal this data */
  if (lua_istable(L, 1))
  {
    for (i = 0; i < nkeys; i++)
    {
      lua_rawgeti(L, 1, i + 1);

      pkeys[i] =  CHECK_OBJECT(-1, EVP_PKEY, "openssl.evp_pkey");
      if (pkeys[i] == NULL)
      {
        luaL_argerror(L, 1, "table with gap");
      }
      eksl[i] = EVP_PKEY_size(pkeys[i]);
      eks[i] = malloc(eksl[i]);

      lua_pop(L, 1);
    }
  }
  else
  {
    pkeys[0] = CHECK_OBJECT(1, EVP_PKEY, "openssl.evp_pkey");
    eksl[0] = EVP_PKEY_size(pkeys[0]);
    eks[0] = malloc(eksl[0]);
  }
  EVP_CIPHER_CTX_reset(ctx);

  /* allocate one byte extra to make room for \0 */
  len1 = data_len + EVP_CIPHER_block_size(cipher) + 1;
  buf = malloc(len1);

  ret = EVP_SealInit(ctx, cipher, eks, eksl, (unsigned char*) iv, pkeys, nkeys);
  if (ret > 0)
  {
    ret = EVP_SealUpdate(ctx, buf, &len1, (unsigned char *)data, data_len);
    if (ret==1)
    {
      ret = EVP_SealFinal(ctx, buf + len1, &len2);
      if (ret==1)
        lua_pushlstring(L, (const char*)buf, len1 + len2);
    }
  }

  if (lua_istable(L, 1))
  {
    if (ret==1) lua_newtable(L);
    for (i = 0; i < nkeys; i++)
    {
      if (ret==1)
      {
        lua_pushlstring(L, (const char*)eks[i], eksl[i]);
        lua_rawseti(L, -2, i + 1);
      }
      free(eks[i]);
    }
  }
  else
  {
    if (ret==1)  lua_pushlstring(L, (const char*)eks[0], eksl[0]);
    free(eks[0]);
  }
  if (ret==1) lua_pushlstring(L, iv, EVP_CIPHER_CTX_iv_length(ctx));

  free(buf);
  free(eks);
  free(eksl);
  free(pkeys);
  EVP_CIPHER_CTX_free(ctx);

  return ret==1 ? 3 : 0;
}

/***
open and ecrypted seal data with private key
@function open
@tparam string ekey encrypted secret key
@tparam string string iv
@tparam[opt='RC4'] evp_cipher|string md_alg
@treturn string data decrypted message or nil on failure
*/
static LUA_FUNCTION(openssl_open)
{
  EVP_PKEY *pkey =  CHECK_OBJECT(1, EVP_PKEY, "openssl.evp_pkey");
  size_t data_len, ekey_len, iv_len;
  const char *data = luaL_checklstring(L, 2, &data_len);
  const char *ekey = luaL_checklstring(L, 3, &ekey_len);
  const char *iv = luaL_checklstring(L, 4, &iv_len);

  int ret = 0;
  int len1, len2 = 0;
  unsigned char *buf;

  const EVP_CIPHER *cipher = NULL;

  cipher = get_cipher(L, 5, "aes-128-cbc");

  if (cipher)
  {
    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    len1 = data_len + 1;
    buf = malloc(len1);

    EVP_CIPHER_CTX_reset(ctx);

    ret = EVP_OpenInit(ctx, cipher, (unsigned char *)ekey, ekey_len, (const unsigned char *)iv, pkey);
    if (ret>0)
    {
      ret = EVP_OpenUpdate(ctx, buf, &len1, (unsigned char *)data, data_len);
      if (ret==1)
      {
        len2 = data_len - len1;
        ret = EVP_OpenFinal(ctx, buf + len1, &len2);
        if (ret==1)
        {
          lua_pushlstring(L, (const char*)buf, len1 + len2);
        }
      }
    }
    EVP_CIPHER_CTX_free(ctx);
    free(buf);
    ret = 1;
  }

  return ret == 1 ? ret : openssl_pushresult(L, ret);
}

static LUA_FUNCTION(openssl_seal_init)
{
  int i, ret = 0, nkeys = 0;
  EVP_PKEY **pkeys;
  unsigned char **eks;
  int *eksl;
  EVP_CIPHER_CTX *ctx = NULL;

  char iv[EVP_MAX_MD_SIZE] = {0};
  const EVP_CIPHER *cipher = NULL;

  luaL_argcheck(L,
                lua_istable(L, 1) || auxiliar_getclassudata(L, "openssl.evp_pkey", 1),
                1,
                "must be openssl.evp_pkey or array");

  if (lua_istable(L, 1))
  {
    nkeys = lua_rawlen(L, 1);
    luaL_argcheck(L, nkeys!=0, 1, "empty array");
  }
  else if (auxiliar_getclassudata(L, "openssl.evp_pkey", 1))
  {
    nkeys = 1;
  }

  cipher = get_cipher(L, 2, "aes-128-cbc");

  pkeys = malloc(nkeys * sizeof(*pkeys));
  eksl = malloc(nkeys * sizeof(*eksl));
  eks = malloc(nkeys * sizeof(*eks));

  memset(eks, 0, sizeof(*eks) * nkeys);

  /* get the public keys we are using to seal this data */
  if (lua_istable(L, 1))
  {
    for (i = 0; i < nkeys; i++)
    {
      lua_rawgeti(L, 1, i + 1);

      pkeys[i] =  CHECK_OBJECT(-1, EVP_PKEY, "openssl.evp_pkey");
      if (pkeys[i] == NULL)
      {
        luaL_argerror(L, 1, "table with gap");
      }
      eksl[i] = EVP_PKEY_size(pkeys[i]);
      eks[i] = malloc(eksl[i]);

      lua_pop(L, 1);
    }
  }
  else
  {
    pkeys[0] = CHECK_OBJECT(1, EVP_PKEY, "openssl.evp_pkey");
    eksl[0] = EVP_PKEY_size(pkeys[0]);
    eks[0] = malloc(eksl[0]);
  }

  ctx = EVP_CIPHER_CTX_new();
  ret = EVP_SealInit(ctx, cipher, eks, eksl, (unsigned char*) iv, pkeys, nkeys);
  if (ret==1)
  {
    PUSH_OBJECT(ctx, "openssl.evp_cipher_ctx");
  }

  if (lua_istable(L, 1))
  {
    if (ret==1) lua_newtable(L);
    for (i = 0; i < nkeys; i++)
    {
      if (ret==1)
      {
        lua_pushlstring(L, (const char*)eks[i], eksl[i]);
        lua_rawseti(L, -2, i + 1);
      }
      free(eks[i]);
    }
  }
  else
  {
    if (ret==1) lua_pushlstring(L, (const char*)eks[0], eksl[0]);
    free(eks[0]);
  }
  if (ret==1) lua_pushlstring(L, iv, EVP_CIPHER_CTX_iv_length(ctx));

  free(eks);
  free(eksl);
  free(pkeys);

  return ret == 1 ? 3 : 0;
}

static LUA_FUNCTION(openssl_seal_update)
{
  EVP_CIPHER_CTX* ctx = CHECK_OBJECT(1, EVP_CIPHER_CTX, "openssl.evp_cipher_ctx");
  size_t data_len;
  const char *data = luaL_checklstring(L, 2, &data_len);
  int len = data_len + EVP_CIPHER_CTX_block_size(ctx);
  unsigned char *buf =  malloc(len);
  int ret = EVP_SealUpdate(ctx, buf, &len, (unsigned char *)data, data_len);

  if(ret==1)
  {
    lua_pushlstring(L, (const char*)buf, len);
  }

  free(buf);
  return ret == 1 ? ret : openssl_pushresult(L, ret);
}

static LUA_FUNCTION(openssl_seal_final)
{
  EVP_CIPHER_CTX* ctx = CHECK_OBJECT(1, EVP_CIPHER_CTX, "openssl.evp_cipher_ctx");
  int len = EVP_CIPHER_CTX_block_size(ctx);
  unsigned char *buf = malloc(len);
  int ret = EVP_SealFinal(ctx, buf, &len);
  if (ret==1)
  {
    lua_pushlstring(L, (const char*)buf, len);
  }

  free(buf);
  return ret == 1 ? ret : openssl_pushresult(L, ret);
}

static LUA_FUNCTION(openssl_open_init)
{
  EVP_PKEY *pkey =  CHECK_OBJECT(1, EVP_PKEY, "openssl.evp_pkey");
  size_t ekey_len, iv_len;
  const char *ekey = luaL_checklstring(L, 2, &ekey_len);
  const char *iv = luaL_checklstring(L, 3, &iv_len);

  const EVP_CIPHER *cipher = get_cipher(L, 4, "aes-128-cbc");
  int ret = 0;

  if (cipher)
  {
    EVP_CIPHER_CTX *ctx = EVP_CIPHER_CTX_new();
    EVP_CIPHER_CTX_reset(ctx);
    ret = EVP_OpenInit(ctx, cipher, (unsigned char *)ekey, ekey_len, (const unsigned char *)iv, pkey);
    if (ret>0)
    {
      PUSH_OBJECT(ctx, "openssl.evp_cipher_ctx");
      ret = 1;
    } else
      EVP_CIPHER_CTX_free(ctx);
  }
  return ret == 1 ? ret : openssl_pushresult(L, ret);
};

static LUA_FUNCTION(openssl_open_update)
{
  EVP_CIPHER_CTX* ctx = CHECK_OBJECT(1, EVP_CIPHER_CTX, "openssl.evp_cipher_ctx");
  size_t data_len;
  const char* data = luaL_checklstring(L, 2, &data_len);

  int len = EVP_CIPHER_CTX_block_size(ctx) + data_len;
  unsigned char *buf = malloc(len);

  int ret = EVP_OpenUpdate(ctx, buf, &len, (unsigned char *)data, data_len);
  if (ret == 1)
  {
    lua_pushlstring(L, (const char*)buf, len);
  }
  free(buf);
  return ret == 1 ? ret : openssl_pushresult(L, ret);
}

static LUA_FUNCTION(openssl_open_final)
{
  EVP_CIPHER_CTX* ctx = CHECK_OBJECT(1, EVP_CIPHER_CTX, "openssl.evp_cipher_ctx");
  int len = EVP_CIPHER_CTX_block_size(ctx);
  unsigned char *buf = malloc(len);
  int ret = EVP_OpenFinal(ctx, buf, &len);
  if (ret == 1)
  {
    lua_pushlstring(L, (const char*)buf, len);
  }
  free(buf);
  return ret == 1 ? ret : openssl_pushresult(L, ret);
}

static int openssl_pkey_bits(lua_State *L)
{
  EVP_PKEY *pkey = CHECK_OBJECT(1, EVP_PKEY, "openssl.evp_pkey");
  lua_Integer ret = EVP_PKEY_bits(pkey);
  lua_pushinteger(L, ret);
  return  1;
};

static int openssl_pkey_set_engine(lua_State *L)
{
  EVP_PKEY *pkey = CHECK_OBJECT(1, EVP_PKEY, "openssl.evp_pkey");
  ENGINE *eng = CHECK_OBJECT(2, ENGINE, "openssl.engine");

  int ret = 0;

  int typ = EVP_PKEY_type(EVP_PKEY_id(pkey));
  switch (typ)
  {
#ifndef OPENSSL_NO_RSA
  case EVP_PKEY_RSA:
  {
    RSA *rsa = (RSA*) EVP_PKEY_get0_RSA(pkey);
    const RSA_METHOD *m = ENGINE_get_RSA(eng);
    if (m!=NULL)
      ret = RSA_set_method(rsa, m);
    break;
  }
#endif
#ifndef OPENSSL_NO_DSA
  case EVP_PKEY_DSA:
  {
    DSA *dsa = (DSA*) EVP_PKEY_get0_DSA(pkey);
    const DSA_METHOD *m = ENGINE_get_DSA(eng);
    if (m!=NULL)
      ret = DSA_set_method(dsa, m);
    break;
  }
#endif
#ifndef OPENSSL_NO_DH
  case EVP_PKEY_DH:
  {
    DH *dh = (DH*) EVP_PKEY_get0_DH(pkey);
    const DH_METHOD *m = ENGINE_get_DH(eng);
    if (m!=NULL)
      ret = DH_set_method(dh, m);
    break;
  }
#endif
#ifndef OPENSSL_NO_EC
  case EVP_PKEY_EC:
  {
    EC_KEY *ec = (EC_KEY*) EVP_PKEY_get0_EC_KEY(pkey);
#if OPENSSL_VERSION_NUMBER < 0x10100000L || defined(LIBRESSL_VERSION_NUMBER)
    const ECDSA_METHOD *m = ENGINE_get_ECDSA(eng);
    if (m!=NULL)
      ret = ECDSA_set_method(ec, m);
#else
    const EC_KEY_METHOD *m = ENGINE_get_EC(eng);
    if (m!=NULL)
      ret = EC_KEY_set_method(ec, m);
#endif
    break;
  }
#endif
  default:
    break;
  }

  lua_pushboolean(L, ret==1);
  return 1;
}

#if defined(OPENSSL_SUPPORT_SM2) && OPENSSL_VERSION_NUMBER < 0x30000000
static int openssl_pkey_as_sm2(lua_State *L)
{
  EVP_PKEY *pkey = CHECK_OBJECT(1, EVP_PKEY, "openssl.evp_pkey");
  int type = EVP_PKEY_type(EVP_PKEY_id(pkey));
  int ret = 0;

  luaL_argcheck(L, type==EVP_PKEY_EC, 1, "must be EC key with SM2 curve");

  if(type==EVP_PKEY_EC)
  {
    const EC_KEY *ec = EVP_PKEY_get0_EC_KEY(pkey);
    const EC_GROUP *grp = EC_KEY_get0_group(ec);
    int curve = EC_GROUP_get_curve_name(grp);
    if (curve==NID_sm2)
    {
      EVP_PKEY_set_alias_type(pkey, EVP_PKEY_SM2);
      lua_pushboolean(L, 1);
      ret = 1;
    }
  }

  return ret;
}
#endif

static luaL_Reg pkey_funcs[] =
{
  {"is_private",    openssl_pkey_is_private1},
  {"get_public",    openssl_pkey_get_public},
  {"set_engine",    openssl_pkey_set_engine},

  {"export",        openssl_pkey_export},
  {"parse",         openssl_pkey_parse},
  {"bits",          openssl_pkey_bits},

  {"ctx",           openssl_pkey_ctx},
  {"encrypt",       openssl_pkey_encrypt},
  {"decrypt",       openssl_pkey_decrypt},
  {"sign",          openssl_sign},
  {"verify",        openssl_verify},

  {"seal",          openssl_seal},
  {"open",          openssl_open},

  {"derive",        openssl_derive},

#if defined(OPENSSL_SUPPORT_SM2) && OPENSSL_VERSION_NUMBER < 0x30000000
  {"as_sm2",        openssl_pkey_as_sm2},
#endif

  {"__gc",          openssl_pkey_free},
  {"__tostring",    auxiliar_tostring},

  {NULL,            NULL},
};

static luaL_Reg pkey_ctx_funcs[] =
{
  {"encrypt_init",  openssl_pkey_ctx_encrypt_init},
  {"decrypt_init",  openssl_pkey_ctx_decrypt_init},
  {"verify_init",   openssl_pkey_ctx_verify_init},
  {"sign_init",     openssl_pkey_ctx_sign_init},

  {"ctrl",          openssl_pkey_ctx_ctrl},

  {"keygen",        openssl_pkey_ctx_keygen},

  {"decrypt",       openssl_pkey_ctx_decrypt},
  {"encrypt",       openssl_pkey_ctx_encrypt},

  {"verify",        openssl_pkey_ctx_verify},
  {"sign",          openssl_pkey_ctx_sign},

  {"__gc",          openssl_pkey_ctx_free},
  {"__tostring",    auxiliar_tostring},

  {NULL,            NULL},
};


static const luaL_Reg R[] =
{
  {"read",          openssl_pkey_read},
  {"new",           openssl_pkey_new},
  {"ctx_new",       openssl_pkey_ctx_new},

  {"seal",          openssl_seal},
  {"seal_init",     openssl_seal_init},
  {"seal_update",   openssl_seal_update},
  {"seal_final",    openssl_seal_final},
  {"open",          openssl_open},
  {"open_init",     openssl_open_init},
  {"open_update",   openssl_open_update},
  {"open_final",    openssl_open_final},

  {"get_public",    openssl_pkey_get_public},
  {"set_engine",    openssl_pkey_set_engine},
  {"is_private",    openssl_pkey_is_private1},
  {"export",        openssl_pkey_export},
  {"parse",         openssl_pkey_parse},
  {"bits",          openssl_pkey_bits},

  {"encrypt",       openssl_pkey_encrypt},
  {"decrypt",       openssl_pkey_decrypt},
  {"sign",          openssl_sign},
  {"verify",        openssl_verify},
  {"derive",        openssl_derive},

#if defined(OPENSSL_SUPPORT_SM2) && OPENSSL_VERSION_NUMBER < 0x30000000
  {"as_sm2",        openssl_pkey_as_sm2},
#endif

  {NULL,  NULL}
};

int luaopen_pkey(lua_State *L)
{
  size_t i;

  auxiliar_newclass(L, "openssl.evp_pkey", pkey_funcs);
  auxiliar_newclass(L, "openssl.evp_pkey_ctx", pkey_ctx_funcs);

  lua_newtable(L);
  luaL_setfuncs(L, R, 0);

  for (i = 0; i < OSSL_NELEM(standard_name2type); i++)
  {
    lua_pushstring(L, standard_name2type[i].ptr);
    lua_pushinteger(L, standard_name2type[i].id);
    lua_rawset(L, -3);
  }

  return 1;
}
