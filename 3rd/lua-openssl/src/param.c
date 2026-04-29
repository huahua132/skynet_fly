/***
param module for OpenSSL 3.x parameter handling

This module provides functionality for handling OpenSSL 3.x parameters
used in cryptographic operations. It supports various parameter types
including integers, strings, and big numbers.

@module param
@usage
  param = require('openssl').param
*/
#include "lua.h"
#include "openssl.h"
#include "private.h"

#if (OPENSSL_VERSION_NUMBER >= 0x30000000L)
#include <openssl/core_names.h>
#include <openssl/kdf.h>

typedef enum
{
  PARAM_T_INT = 1,
  PARAM_T_UINT,
  PARAM_T_LONG,
  PARAM_T_ULONG,
  PARAM_T_INT32,
  PARAM_T_UINT32,
  PARAM_T_INT64,
  PARAM_T_UINT64,
  PARAM_T_SIZE_T,
  PARAM_T_TIME_T,
  PARAM_T_BN,
  PARAM_T_DOUBLE,
} PARAM_NUMBER_TYPE;

struct param_info
{
  const char       *name;
  int               data_type;
  PARAM_NUMBER_TYPE number_type;
};

/* KDF / PRF parameters */
static struct param_info kdf_params[] = {
  { OSSL_KDF_PARAM_SECRET,              OSSL_PARAM_OCTET_STRING,     0              },
  { OSSL_KDF_PARAM_KEY,                 OSSL_PARAM_OCTET_STRING,     0              },
  { OSSL_KDF_PARAM_SALT,                OSSL_PARAM_OCTET_STRING,     0              },
  { OSSL_KDF_PARAM_PASSWORD,            OSSL_PARAM_OCTET_STRING,     0              },
  { OSSL_KDF_PARAM_PREFIX,              OSSL_PARAM_OCTET_STRING,     0              },
  { OSSL_KDF_PARAM_LABEL,               OSSL_PARAM_OCTET_STRING,     0              },
  { OSSL_KDF_PARAM_DATA,                OSSL_PARAM_OCTET_STRING,     0              },
  { OSSL_KDF_PARAM_UKM,                 OSSL_PARAM_OCTET_STRING,     0              },

  { OSSL_KDF_PARAM_INFO,                OSSL_PARAM_OCTET_STRING,     0              },
  { OSSL_KDF_PARAM_SEED,                OSSL_PARAM_OCTET_STRING,     0              },
  { OSSL_KDF_PARAM_SSHKDF_XCGHASH,      OSSL_PARAM_OCTET_STRING,     0              },
  { OSSL_KDF_PARAM_SSHKDF_SESSION_ID,   OSSL_PARAM_OCTET_STRING,     0              },
  { OSSL_KDF_PARAM_CONSTANT,            OSSL_PARAM_OCTET_STRING,     0              },

  { OSSL_KDF_PARAM_DIGEST,              OSSL_PARAM_UTF8_STRING,      0              },
  { OSSL_KDF_PARAM_CIPHER,              OSSL_PARAM_UTF8_STRING,      0              },
  { OSSL_KDF_PARAM_MAC,                 OSSL_PARAM_UTF8_STRING,      0              },
  { OSSL_KDF_PARAM_PROPERTIES,          OSSL_PARAM_UTF8_STRING,      0              },
  { OSSL_KDF_PARAM_MODE,                OSSL_PARAM_UTF8_STRING,      0              },
  { OSSL_KDF_PARAM_CEK_ALG,             OSSL_PARAM_UTF8_STRING,      0              },

  { OSSL_KDF_PARAM_MAC_SIZE,            OSSL_PARAM_UNSIGNED_INTEGER, PARAM_T_SIZE_T },
  { OSSL_KDF_PARAM_ITER,                OSSL_PARAM_UNSIGNED_INTEGER, PARAM_T_UINT   },
  { OSSL_KDF_PARAM_SCRYPT_N,            OSSL_PARAM_UNSIGNED_INTEGER, PARAM_T_UINT32 },
  { OSSL_KDF_PARAM_SCRYPT_R,            OSSL_PARAM_UNSIGNED_INTEGER, PARAM_T_UINT32 },
  { OSSL_KDF_PARAM_SCRYPT_P,            OSSL_PARAM_UNSIGNED_INTEGER, PARAM_T_UINT32 },

  { OSSL_KDF_PARAM_SCRYPT_MAXMEM,       OSSL_PARAM_UNSIGNED_INTEGER, PARAM_T_UINT64 },
  { OSSL_KDF_PARAM_PKCS5,               OSSL_PARAM_INTEGER,          PARAM_T_INT    },
  { OSSL_KDF_PARAM_SSHKDF_TYPE,         OSSL_PARAM_INTEGER,          PARAM_T_INT    },
  { OSSL_KDF_PARAM_PKCS12_ID,           OSSL_PARAM_INTEGER,          PARAM_T_INT    },
  { OSSL_KDF_PARAM_KBKDF_USE_L,         OSSL_PARAM_INTEGER,          PARAM_T_INT    },
  { OSSL_KDF_PARAM_KBKDF_USE_SEPARATOR, OSSL_PARAM_INTEGER,          PARAM_T_INT    },

#if defined(OSSL_KDF_PARAM_KBKDF_R)
  { OSSL_KDF_PARAM_KBKDF_R,             OSSL_PARAM_INTEGER,          PARAM_T_INT    },
#endif

  { OSSL_KDF_PARAM_SIZE,                OSSL_PARAM_UNSIGNED_INTEGER, PARAM_T_SIZE_T },

/* Argon2 parameters (OpenSSL 3.2+) */
#if defined(OSSL_KDF_PARAM_ARGON2_AD)
  { OSSL_KDF_PARAM_ARGON2_AD,           OSSL_PARAM_OCTET_STRING,     0              },
#endif
#if defined(OSSL_KDF_PARAM_ARGON2_LANES)
  { OSSL_KDF_PARAM_ARGON2_LANES,        OSSL_PARAM_UNSIGNED_INTEGER, PARAM_T_UINT32 },
#endif
#if defined(OSSL_KDF_PARAM_ARGON2_MEMCOST)
  { OSSL_KDF_PARAM_ARGON2_MEMCOST,      OSSL_PARAM_UNSIGNED_INTEGER, PARAM_T_UINT32 },
#endif
#if defined(OSSL_KDF_PARAM_ARGON2_VERSION)
  { OSSL_KDF_PARAM_ARGON2_VERSION,      OSSL_PARAM_UNSIGNED_INTEGER, PARAM_T_UINT32 },
#endif
#if defined(OSSL_KDF_PARAM_THREADS)
  { OSSL_KDF_PARAM_THREADS,             OSSL_PARAM_UNSIGNED_INTEGER, PARAM_T_UINT32 },
#endif

  { NULL,                               0,                           0              }
};

/* RSA key parameters */
static struct param_info rsa_params[] = {
  { OSSL_PKEY_PARAM_RSA_N,              OSSL_PARAM_UNSIGNED_INTEGER, PARAM_T_BN     },
  { OSSL_PKEY_PARAM_RSA_E,              OSSL_PARAM_UNSIGNED_INTEGER, PARAM_T_BN     },
  { OSSL_PKEY_PARAM_RSA_D,              OSSL_PARAM_UNSIGNED_INTEGER, PARAM_T_BN     },
  { OSSL_PKEY_PARAM_RSA_FACTOR1,        OSSL_PARAM_UNSIGNED_INTEGER, PARAM_T_BN     },
  { OSSL_PKEY_PARAM_RSA_FACTOR2,        OSSL_PARAM_UNSIGNED_INTEGER, PARAM_T_BN     },
  { OSSL_PKEY_PARAM_RSA_EXPONENT1,      OSSL_PARAM_UNSIGNED_INTEGER, PARAM_T_BN     },
  { OSSL_PKEY_PARAM_RSA_EXPONENT2,      OSSL_PARAM_UNSIGNED_INTEGER, PARAM_T_BN     },
  { OSSL_PKEY_PARAM_RSA_COEFFICIENT1,   OSSL_PARAM_UNSIGNED_INTEGER, PARAM_T_BN     },
  { NULL,                               0,                           0              }
};

static int
get_param_type(const char *name, PARAM_NUMBER_TYPE *nt)
{
  int i;

  /* Try KDF parameters first */
  for (i = 0; i < sizeof(kdf_params) / sizeof(kdf_params[0]); i++) {
    struct param_info *p = &kdf_params[i];
    if (p->name && strcmp(p->name, name) == 0) {
      *nt = p->number_type;
      return p->data_type;
    }
  }

  /* Try RSA parameters */
  for (i = 0; i < sizeof(rsa_params) / sizeof(rsa_params[0]); i++) {
    struct param_info *p = &rsa_params[i];
    if (p->name && strcmp(p->name, name) == 0) {
      *nt = p->number_type;
      return p->data_type;
    }
  }

  return 0;
}

int
openssl_pushparams(lua_State *L, const OSSL_PARAM *params)
{
  int               i = 0;
  const OSSL_PARAM *p = params;

  lua_newtable(L);
  while (p->key) {
    lua_newtable(L);
    lua_pushliteral(L, "name");
    lua_pushstring(L, p->key);
    lua_rawset(L, -3);

    lua_pushliteral(L, "data_type");
    lua_pushinteger(L, p->data_type);
    lua_rawset(L, -3);

    if (p->data) {
      lua_pushliteral(L, "data");
      switch (p->data_type) {
      case OSSL_PARAM_INTEGER:
      case OSSL_PARAM_UNSIGNED_INTEGER:
        lua_pushinteger(L, (lua_Integer)p->data);
        break;
      case OSSL_PARAM_REAL:
        lua_pushnumber(L, (lua_Number)p->data_type);
        break;
      case OSSL_PARAM_UTF8_STRING:
      case OSSL_PARAM_OCTET_STRING:
        lua_pushlstring(L, (const char *)p->data, p->return_size);
        break;
      case OSSL_PARAM_UTF8_PTR:
      case OSSL_PARAM_OCTET_PTR:
        lua_pushlightuserdata(L, p->data);
        break;
      default:
        lua_pushnil(L);
      }
      lua_rawset(L, -3);
    }
    lua_rawseti(L, -2, ++i);
    p++;
  }

  return 1;
}

OSSL_PARAM *
openssl_toparams(lua_State *L, int idx)
{
  OSSL_PARAM *params;
  lua_Number *values;

  size_t i, len = lua_rawlen(L, idx);

  luaL_checktype(L, idx, LUA_TTABLE);
  luaL_argcheck(L, len > 0, idx, "empty paramaters table");

  params = OPENSSL_malloc((sizeof(OSSL_PARAM) + sizeof(lua_Number)) * (len + 1));
  memset(params, 0, sizeof(OSSL_PARAM) + sizeof(lua_Number) * (len + 1));
  values = (lua_Number *)((char *)params + sizeof(OSSL_PARAM) * (len + 1));

  for (i = 0; i < len; i++) {
    size_t            sz = 0;
    int               type = 0;
    PARAM_NUMBER_TYPE nt = 0;
    const char       *name;
    const char       *str;

    /* get paramater node */
    lua_rawgeti(L, idx, i + 1);

    /* get paramater name */
    lua_pushliteral(L, "name");
    lua_rawget(L, -2);
    name = luaL_checkstring(L, -1);
    lua_pop(L, 1);

    type = get_param_type(name, &nt);

    /* get paramater data */
    lua_pushliteral(L, "data");
    lua_rawget(L, -2);
    if (!lua_isnil(L, -1)) {
      switch (type) {
      case OSSL_PARAM_INTEGER:
      case OSSL_PARAM_UNSIGNED_INTEGER: {
        values[i] = luaL_checknumber(L, -1);
        switch ((int)nt) {
        case PARAM_T_INT: {
          *(int *)&values[i] = (int)(values[i]);
          params[i] = OSSL_PARAM_construct_int(name, (int *)&values[i]);
          break;
        }
        case PARAM_T_UINT: {
          *(unsigned int *)&values[i] = (unsigned int)(values[i]);
          params[i] = OSSL_PARAM_construct_uint(name, (unsigned int *)&values[i]);
          break;
        }
        case PARAM_T_LONG: {
          *(long *)&values[i] = (long)(values[i]);
          params[i] = OSSL_PARAM_construct_long(name, (long *)&values[i]);
          break;
        }
        case PARAM_T_ULONG: {
          *(unsigned long *)&values[i] = (unsigned long)(values[i]);
          params[i] = OSSL_PARAM_construct_ulong(name, (unsigned long *)&values[i]);
          break;
        }
        case PARAM_T_INT32: {
          *(int32_t *)&values[i] = (int32_t)(values[i]);
          params[i] = OSSL_PARAM_construct_int32(name, (int32_t *)&values[i]);
          break;
        }
        case PARAM_T_UINT32: {
          *(uint32_t *)&values[i] = (uint32_t)(values[i]);
          params[i] = OSSL_PARAM_construct_uint32(name, (uint32_t *)&values[i]);
          break;
        }
        case PARAM_T_INT64: {
          *(int64_t *)&values[i] = (int64_t)(values[i]);
          params[i] = OSSL_PARAM_construct_int64(name, (int64_t *)&values[i]);
          break;
        }
        case PARAM_T_UINT64: {
          *(uint64_t *)&values[i] = (uint64_t)(values[i]);
          params[i] = OSSL_PARAM_construct_uint64(name, (uint64_t *)&values[i]);
          break;
        }
        case PARAM_T_TIME_T: {
          *(time_t *)&values[i] = (time_t)(values[i]);
          params[i] = OSSL_PARAM_construct_time_t(name, (time_t *)&values[i]);
          break;
        }
        case PARAM_T_SIZE_T: {
          *(size_t *)&values[i] = (size_t)(values[i]);
          params[i] = OSSL_PARAM_construct_size_t(name, (size_t *)&values[i]);
          break;
        }
        case PARAM_T_DOUBLE: {
          *(double *)&values[i] = (double)(values[i]);
          params[i] = OSSL_PARAM_construct_double(name, (double *)&values[i]);
          break;
        }
        default:
          fprintf(stderr, "%s:%d in %s: Error NYI\n", __FILE__, __LINE__, __FUNCTION__);
          lua_pop(L, 2);
          goto done;
        }
      } break;
      case OSSL_PARAM_UTF8_STRING:
        str = luaL_checklstring(L, -1, &sz);
        params[i] = OSSL_PARAM_construct_utf8_string(name, (void *)str, sz);
        break;
      case OSSL_PARAM_OCTET_STRING:
        str = luaL_checklstring(L, -1, &sz);
        params[i] = OSSL_PARAM_construct_octet_string(name, (void *)str, sz);
        break;
      default:
        fprintf(stderr, "%s:%d in %s: Error NYI\n", __FILE__, __LINE__, __FUNCTION__);
        lua_pop(L, 2);
        goto done;
      }
    }
    lua_pop(L, 1);
    lua_pop(L, 1);
  }

done:

  params[i] = OSSL_PARAM_construct_end();
  return params;
}

int
luaopen_param(lua_State *L)
{
  int i;

  lua_newtable(L);

  /* Export KDF parameters */
  lua_pushliteral(L, "kdf");
  lua_newtable(L);

  for (i = 0; i < sizeof(kdf_params) / sizeof(kdf_params[0]); i++) {
    struct param_info *p = &kdf_params[i];
    if (p->name) {
      lua_pushstring(L, p->name);
      lua_newtable(L);
      lua_pushliteral(L, "type");
      lua_pushinteger(L, p->data_type);
      lua_rawset(L, -3);
      if (p->number_type) {
        lua_pushliteral(L, "number_type");
        switch ((int)p->number_type) {
        case PARAM_T_INT:
          lua_pushliteral(L, "int");
          break;
        case PARAM_T_UINT:
          lua_pushliteral(L, "unsinged int");
          break;
        case PARAM_T_LONG:
          lua_pushliteral(L, "long");
          break;
        case PARAM_T_ULONG:
          lua_pushliteral(L, "unsinged long");
          break;
        case PARAM_T_INT32:
          lua_pushliteral(L, "int32");
          break;
        case PARAM_T_UINT32:
          lua_pushliteral(L, "uint32");
          break;
        case PARAM_T_INT64:
          lua_pushliteral(L, "int64");
          break;
        case PARAM_T_UINT64:
          lua_pushliteral(L, "uint64");
          break;
        case PARAM_T_SIZE_T:
          lua_pushliteral(L, "size_t");
          break;
        case PARAM_T_TIME_T:
          lua_pushliteral(L, "time_t");
          break;
        case PARAM_T_BN:
          lua_pushliteral(L, "BIGNUM");
          break;
        case PARAM_T_DOUBLE:
          lua_pushliteral(L, "double");
          break;
        default:
          lua_pushliteral(L, "unknown");
        }
        lua_rawset(L, -3);
      }
      lua_rawset(L, -3);
    }
  }

  lua_rawset(L, -3);

  /* Export RSA parameters */
  lua_pushliteral(L, "rsa");
  lua_newtable(L);

  for (i = 0; i < sizeof(rsa_params) / sizeof(rsa_params[0]); i++) {
    struct param_info *p = &rsa_params[i];
    if (p->name) {
      lua_pushstring(L, p->name);
      lua_newtable(L);
      lua_pushliteral(L, "type");
      lua_pushinteger(L, p->data_type);
      lua_rawset(L, -3);
      if (p->number_type) {
        lua_pushliteral(L, "number_type");
        switch ((int)p->number_type) {
        case PARAM_T_INT:
          lua_pushliteral(L, "int");
          break;
        case PARAM_T_UINT:
          lua_pushliteral(L, "unsinged int");
          break;
        case PARAM_T_LONG:
          lua_pushliteral(L, "long");
          break;
        case PARAM_T_ULONG:
          lua_pushliteral(L, "unsinged long");
          break;
        case PARAM_T_INT32:
          lua_pushliteral(L, "int32");
          break;
        case PARAM_T_UINT32:
          lua_pushliteral(L, "uint32");
          break;
        case PARAM_T_INT64:
          lua_pushliteral(L, "int64");
          break;
        case PARAM_T_UINT64:
          lua_pushliteral(L, "uint64");
          break;
        case PARAM_T_SIZE_T:
          lua_pushliteral(L, "size_t");
          break;
        case PARAM_T_TIME_T:
          lua_pushliteral(L, "time_t");
          break;
        case PARAM_T_BN:
          lua_pushliteral(L, "BIGNUM");
          break;
        case PARAM_T_DOUBLE:
          lua_pushliteral(L, "double");
          break;
        default:
          lua_pushliteral(L, "unknown");
        }
        lua_rawset(L, -3);
      }
      lua_rawset(L, -3);
    }
  }

  lua_rawset(L, -3);

  return 1;
}

#endif
