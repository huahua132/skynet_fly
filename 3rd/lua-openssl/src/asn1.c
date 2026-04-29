/***
asn1 module to generate or parse ASN.1 data.
Provide asn1\_object, asn1\_string, asn1\_object as lua object.

@module asn1
@usage
  asn1 = require('openssl').asn1
*/

#include <openssl/asn1.h>

#include "openssl.h"
#include "private.h"

static LuaL_Enumeration asn1_const[] = {
  /* 0 */
  { "UNIVERSAL",         V_ASN1_UNIVERSAL         },
  { "APPLICATION",       V_ASN1_APPLICATION       },
  { "CONTEXT_SPECIFIC",  V_ASN1_CONTEXT_SPECIFIC  },
  { "PRIVATE",           V_ASN1_PRIVATE           },
  /* 4 */
  { "CONSTRUCTED",       V_ASN1_CONSTRUCTED       },
  { "PRIMITIVE_TAG",     V_ASN1_PRIMITIVE_TAG     },
  { "PRIMATIVE_TAG",     V_ASN1_PRIMATIVE_TAG     },
#ifdef V_ASN1_APP_CHOOSE
  { "APP_CHOOSE",        V_ASN1_APP_CHOOSE        },
#endif
  { "OTHER",             V_ASN1_OTHER             },
  { "ANY",               V_ASN1_ANY               },

  { "NEG",               V_ASN1_NEG               },
  /* 11 */

  { "UNDEF",             V_ASN1_UNDEF             },
  { "EOC",               V_ASN1_EOC               },
  { "BOOLEAN",           V_ASN1_BOOLEAN           },
  { "INTEGER",           V_ASN1_INTEGER           },
  { "NEG_INTEGER",       V_ASN1_NEG_INTEGER       },
  { "BIT_STRING",        V_ASN1_BIT_STRING        },
  { "OCTET_STRING",      V_ASN1_OCTET_STRING      },
  { "NULL",              V_ASN1_NULL              },
  { "OBJECT",            V_ASN1_OBJECT            },
  { "OBJECT_DESCRIPTOR", V_ASN1_OBJECT_DESCRIPTOR },
  { "EXTERNAL",          V_ASN1_EXTERNAL          },
  { "REAL",              V_ASN1_REAL              },
  { "ENUMERATED",        V_ASN1_ENUMERATED        },
  { "NEG_ENUMERATED",    V_ASN1_NEG_ENUMERATED    },
  { "UTF8STRING",        V_ASN1_UTF8STRING        },
  { "SEQUENCE",          V_ASN1_SEQUENCE          },
  { "SET",               V_ASN1_SET               },
  { "NUMERICSTRING",     V_ASN1_NUMERICSTRING     },
  { "PRINTABLESTRING",   V_ASN1_PRINTABLESTRING   },
  { "T61STRING",         V_ASN1_T61STRING         },
  { "TELETEXSTRING",     V_ASN1_TELETEXSTRING     },
  { "VIDEOTEXSTRING",    V_ASN1_VIDEOTEXSTRING    },
  { "IA5STRING",         V_ASN1_IA5STRING         },
  { "UTCTIME",           V_ASN1_UTCTIME           },
  { "GENERALIZEDTIME",   V_ASN1_GENERALIZEDTIME   },

  { "GRAPHICSTRING",     V_ASN1_GRAPHICSTRING     },
  { "ISO64STRING",       V_ASN1_ISO64STRING       },
  { "VISIBLESTRING",     V_ASN1_VISIBLESTRING     },
  { "GENERALSTRING",     V_ASN1_GENERALSTRING     },
  { "UNIVERSALSTRING",   V_ASN1_UNIVERSALSTRING   },
  { "BMPSTRING",         V_ASN1_BMPSTRING         },
  /* 43 */
  { NULL,                0                        }
};

#define CLS_IDX_OFFSET 0
#define CLS_IDX_LENGTH 4

#define TAG_IDX_OFFSET 11
#define TAG_IDX_LENGTH 31

/***
create asn1_type object
@function new_type
@tparam boolean|number|string|asn1_string value value to create ASN1_TYPE from
@treturn asn1_type|nil new ASN1_TYPE object or nil on error
*/
static int
openssl_asn1type_new(lua_State *L)
{
  ASN1_TYPE   *at = ASN1_TYPE_new();
  ASN1_STRING *s = NULL;
  int          ret = 0;
  int          type = lua_type(L, 1);

  luaL_argcheck(L,
                type == LUA_TBOOLEAN || type == LUA_TNUMBER || type == LUA_TSTRING
                  || (type == LUA_TUSERDATA && GET_GROUP(1, ASN1_STRING, "openssl.asn1group")),
                1,
                "only accept boolean, number, string or asn1_string");

  if (lua_isboolean(L, 1)) {
    int b = lua_toboolean(L, 1);
    ASN1_TYPE_set(at, V_ASN1_BOOLEAN, b ? &b : 0);
    ret = 1;
  } else if (lua_type(L, 1) == LUA_TNUMBER) {
    long          n = lua_tointeger(L, 1);
    ASN1_INTEGER *ai = ASN1_INTEGER_new();
    if (ASN1_INTEGER_set(ai, n) == 1) {
      ASN1_TYPE_set(at, V_ASN1_INTEGER, ai);
      ret = 1;
    } else {
      ASN1_INTEGER_free(ai);
    }
  } else if (lua_isstring(L, 1)) {
    size_t      size;
    const char *octet = luaL_checklstring(L, 1, &size);
    ret = ASN1_TYPE_set_octetstring(at, (unsigned char *)octet, size);
  } else if ((s = GET_GROUP(1, ASN1_STRING, "openssl.asn1group")) != NULL) {
    ret = ASN1_TYPE_set1(at, ASN1_STRING_type(s), s);
  }

  if (ret == 1)
    PUSH_OBJECT(at, "openssl.asn1_type");
  else
    ASN1_TYPE_free(at);
  return ret;
}

/***
parse der encoded string
@function get_object
@tparam string der string
@tparam[opt=1] number start offset to parse
@tparam[opt=-i] number stop offset to parse
 this like string.sub()
@treturn[1] number tag
@treturn[1] number class
@treturn[1] number parsed data start offset
@treturn[1] number parsed data stop offset
@treturn[1] boolean true for constructed data
@treturn[2] nil for fail
@treturn[2] string error msg
@treturn[2] number inner error code
*/
static int
openssl_get_object(lua_State *L)
{
  size_t      l = 0;
  const char *asn1s = luaL_checklstring(L, 1, &l);
  size_t      start = posrelat(luaL_optinteger(L, 2, 1), l);
  size_t      stop = posrelat(luaL_optinteger(L, 3, l), l);

  const unsigned char *p = (const unsigned char *)asn1s + start - 1;
  long                 len = 0;
  int                  tag = 0;
  int class = 0;
  int ret;

  luaL_argcheck(L, start > 0 && start < l, 2, "start out of length of asn1 string");
  luaL_argcheck(L, stop > start, 3, "stop must be greater than start");
  luaL_argcheck(L, stop <= l, 3, "stop out of length of asn1 string");

  p = (const unsigned char *)asn1s + start - 1;
  ret = ASN1_get_object(&p, &len, &tag, &class, stop - start + 1);
  if (ret & 0x80) {
    lua_pushnil(L);
    lua_pushstring(L, "arg #1 with error encoding");
    lua_pushinteger(L, ret);
    return 3;
  }
  lua_pushinteger(L, tag);
  lua_pushinteger(L, class);
  lua_pushinteger(L, p - (const unsigned char *)asn1s + 1);
  lua_pushinteger(L, p + len - (const unsigned char *)asn1s);

  lua_pushboolean(L, ret & V_ASN1_CONSTRUCTED);
  return 5;
}

/***
do der encode and return encoded string partly head or full
@function put_object
@tparam number tag
@tparam number class
@tparam[opt=nil] number|string val length or data to encode, defualt will make
indefinite length constructed
@tparam[opt=nil] boolean constructed or not
@treturn string der encoded string or head when not give data
*/
static int
openssl_put_object(lua_State *L)
{
  int            tag = luaL_checkint(L, 1);
  int            cls = luaL_checkint(L, 2);
  int            length = 0;
  int            constructed;
  unsigned char *p1, *p2;
  const char    *dat = NULL;
  luaL_Buffer    B;

  luaL_argcheck(L,
                lua_isnone(L, 3) || lua_type(L, 3) == LUA_TNUMBER || lua_isstring(L, 3),
                3,
                "if exist only accept string or number");
  luaL_argcheck(L, lua_isnone(L, 4) || lua_isboolean(L, 4), 4, "if exist must be boolean type");

  if (lua_isnone(L, 3)) {
    /* constructed == 2 for indefinite length constructed */
    constructed = 2;
    length = 0;
  } else {
    if (lua_type(L, 3) == LUA_TNUMBER) {
      length = lua_tointeger(L, 3);
    } else if (lua_isstring(L, 3)) {
      size_t l;
      dat = lua_tolstring(L, 3, &l);
      length = (int)l;
    }

    constructed = lua_isnone(L, 4) ? 0 : lua_toboolean(L, 4);
  }
  luaL_buffinit(L, &B);
  p1 = (unsigned char *)luaL_prepbuffer(&B);
  p2 = p1;

  ASN1_put_object(&p2, constructed, length, tag, cls);
  luaL_addsize(&B, p2 - p1);
  if (dat) {
    luaL_addlstring(&B, dat, length);
  }
  luaL_pushresult(&B);
  return 1;
};

/***
make tag, class number to string

@function tostring
@tparam number clsortag which to string
@tparam string range only accept 'class' or 'tag'
@treturn string result
*/
static int
openssl_asn1_tostring(lua_State *L)
{
  int         val = luaL_checkint(L, 1);
  const char *range = luaL_optstring(L, 2, NULL);
  int         i, ret = 0;

  if (range == NULL) {
    for (i = 0; i < sizeof(asn1_const) / sizeof(LuaL_Enumeration) - 1; i++) {
      if (asn1_const[i].val == val) {
        lua_pushstring(L, asn1_const[i + CLS_IDX_OFFSET].name);
        ret = 1;
      }
    }
  } else if (strcmp("tag", range) == 0) {
    for (i = 0; i < TAG_IDX_LENGTH; i++) {
      if (asn1_const[i + TAG_IDX_OFFSET].val == val) {
        lua_pushstring(L, asn1_const[i + TAG_IDX_OFFSET].name);
        ret = 1;
      }
    }
  } else if (strcmp("class", range) == 0) {
    for (i = 0; i < CLS_IDX_LENGTH; i++) {
      if (asn1_const[i + CLS_IDX_OFFSET].val == val) {
        lua_pushstring(L, asn1_const[i + CLS_IDX_OFFSET].name);
        ret = 1;
      }
    }
  }

  return ret;
}

/***
create asn1_string object

<br/><p> asn1_string object support types:   "integer", "enumerated", "bit",
"octet", "utf8", "numeric", "printable", "t61", "teletex", "videotex", "ia5",
"graphics", "iso64", "visible", "general", "unversal", "bmp", "utctime" </p>

@function new_string
@tparam string data create new asn1_string with data
@tparam[opt] string type asn1 string type, defult with 'utf8'
@treturn asn1_string
*/
static int
openssl_asn1string_new(lua_State *L)
{
  size_t       size = 0;
  const char  *data = luaL_checklstring(L, 1, &size);
  int          type = luaL_optint(L, 2, V_ASN1_UTF8STRING);
  ASN1_STRING *s = ASN1_STRING_type_new(type);
  ASN1_STRING_set(s, data, size);
  PUSH_OBJECT(s, "openssl.asn1_string");
  return 1;
}

/***
create asn1_integer object
@function new_integer
@tparam number|bn value integer value or bignum
@treturn openssl.asn1_integer new ASN1_INTEGER object
-- @see openssl/asn1.h:ASN1_INTEGER_
*/
static int
openssl_asn1int_new(lua_State *L)
{
  ASN1_INTEGER *ai = ASN1_INTEGER_new();
  if (lua_isinteger(L, 1)) {
    long v = luaL_checklong(L, 1);
    ASN1_INTEGER_set(ai, v);
  } else if (!lua_isnone(L, 1)) {
    BIGNUM *bn = BN_get(L, 1);
    if (bn != NULL) {
      ai = BN_to_ASN1_INTEGER(bn, ai);
      BN_free(bn);
    }
  }
  PUSH_OBJECT(ai, "openssl.asn1_integer");
  return 1;
}

/***
create asn1_time object using generalized time format

@function new_generalizedtime
@tparam none|number|string time
@treturn asn1_time
-- @see openssl/asn1.h:ASN1_STRING_
*/
static int
openssl_asn1generalizedtime_new(lua_State *L)
{
  ASN1_GENERALIZEDTIME *a = NULL;
  int                   ret = 0;
  luaL_argcheck(L,
                1,
                lua_isnone(L, 1) || lua_isnumber(L, 1) || lua_isstring(L, 1),
                "must be number, string or none");
  a = ASN1_GENERALIZEDTIME_new();
  if (lua_isnumber(L, 1)) {
    ASN1_GENERALIZEDTIME_set(a, luaL_checkinteger(L, 1));
    ret = 1;
  } else if (lua_isstring(L, 1))
    ret = ASN1_GENERALIZEDTIME_set_string(a, lua_tostring(L, 1));
  else
    ret = 1;

  if (ret == 1)
    PUSH_OBJECT(a, "openssl.asn1_time");
  else
    ASN1_GENERALIZEDTIME_free(a);

  return ret == 1 ? 1 : 0;
}

/***
create asn1_time object using UTC time format
@function new_utctime
@tparam none|number|string time
@treturn asn1_time
-- @see openssl/asn1.h:ASN1_STRING_
*/
static int
openssl_asn1utctime_new(lua_State *L)
{
  ASN1_UTCTIME *a = NULL;
  int           ret = 0;
  luaL_argcheck(L,
                1,
                lua_isnone(L, 1) || lua_isnumber(L, 1) || lua_isstring(L, 1),
                "must be number, string or none");
  a = ASN1_UTCTIME_new();
  if (lua_isnumber(L, 1)) {
    time_t t = luaL_checkinteger(L, 1);
    ASN1_TIME_set(a, t);
    ret = 1;
  } else if (lua_isstring(L, 1))
    ret = ASN1_TIME_set_string(a, lua_tostring(L, 1));
  else if (lua_isnone(L, 1)) {
    time_t t = time(NULL);
    ASN1_TIME_set(a, t);
    ret = 1;
  }

  if (ret == 1)
    PUSH_OBJECT(a, "openssl.asn1_time");
  else
    ASN1_UTCTIME_free(a);

  return ret == 1 ? 1 : 0;
}

/***
get nid for txt, which can be short name, long name, or numerical oid

@function txt2nid
@tparam string txt which get to nid
@treturn integer nid or nil on fail
*/
static int
openssl_txt2nid(lua_State *L)
{
  const char *txt = luaL_checkstring(L, 1);
  int         nid = OBJ_txt2nid(txt);
  int         ret = 1;
  if (nid != NID_undef) {
    lua_pushinteger(L, nid);
  } else
    ret = openssl_pushresult(L, 0);

  return ret;
}

/***
create asn1_object from string identifier

@function new_object
@tparam string name_or_oid short name (e.g., "C"), long name (e.g., "countryName"), or OID string (e.g., "2.5.4.6")
@tparam[opt=false] boolean no_name true for only oid string parsing, false to allow names
@treturn openssl.asn1_object|nil ASN1_OBJECT mapping or nil on error
-- @see openssl/asn1.h:ASN1_OBJECT_
@usage
  local obj1 = asn1.new_object("C")           -- short name
  local obj2 = asn1.new_object("countryName") -- long name
  local obj3 = asn1.new_object("2.5.4.6")     -- OID string
*/

/***
create asn1_object from NID

@function new_object
@tparam integer nid numeric identifier for the ASN1_OBJECT
@treturn openssl.asn1_object|nil ASN1_OBJECT mapping or nil on error
-- @see openssl/asn1.h:ASN1_OBJECT_
@usage
  local obj = asn1.new_object(14)  -- NID for countryName
*/

/***
create asn1_object from table definition

@function new_object
@tparam table options table with sn (short name), ln (long name), oid keys to create new asn1_object
@treturn openssl.asn1_object|nil ASN1_OBJECT mapping or nil on error
-- @see openssl/asn1.h:ASN1_OBJECT_
@usage
  local obj = asn1.new_object({
    oid = "1.2.3.4.5.6",
    sn = "myShortName",
    ln = "myLongName"
  })
*/
static int
openssl_asn1object_new(lua_State *L)
{
  int ret = 0;
  if (lua_type(L, 1) == LUA_TNUMBER) {
    int          nid = luaL_checkint(L, 1);
    ASN1_OBJECT *obj = OBJ_nid2obj(nid);
    if (obj) {
      PUSH_OBJECT(obj, "openssl.asn1_object");
      ret = 1;
    }
  } else if (lua_isstring(L, 1)) {
    const char *txt = luaL_checkstring(L, 1);
    int         no_name = lua_isnone(L, 2) ? 0 : lua_toboolean(L, 2);

    ASN1_OBJECT *obj = OBJ_txt2obj(txt, no_name);
    if (obj) {
      PUSH_OBJECT(obj, "openssl.asn1_object");
      ret = 1;
    }
  } else if (lua_istable(L, 1)) {
    const char  *oid, *sn, *ln;
    ASN1_OBJECT *obj;
    int          nid;

    lua_getfield(L, 1, "oid");
    luaL_argcheck(L, lua_isstring(L, -1), 1, "not have oid field or is not string");
    oid = luaL_checkstring(L, -1);
    lua_pop(L, 1);

    lua_getfield(L, 1, "sn");
    luaL_argcheck(L, lua_isstring(L, -1), 1, "not have sn field or is not string");
    sn = luaL_checkstring(L, -1);
    lua_pop(L, 1);

    lua_getfield(L, 1, "ln");
    luaL_argcheck(L, lua_isstring(L, -1), 1, "not have ln field or is not string");
    ln = luaL_checkstring(L, -1);
    lua_pop(L, 1);

    luaL_argcheck(L, OBJ_txt2nid(oid) == NID_undef, 1, "oid already exist");
    luaL_argcheck(L, OBJ_sn2nid(sn) == NID_undef, 1, "sn already exist");
    luaL_argcheck(L, OBJ_ln2nid(ln) == NID_undef, 1, "ln already exist");

    nid = OBJ_create(oid, sn, ln);
    if (nid != NID_undef) {
      obj = OBJ_nid2obj(nid);
      PUSH_OBJECT(obj, "openssl.asn1_object");
      ret = 1;
    }
  } else if (lua_isnone(L, 1)) {
    /* ASN1_OBJECT_new() is deprecated in OpenSSL 4.0,
     * but there's no direct replacement for creating an empty object.
     * We create an object from a dummy NID instead. */
    ASN1_OBJECT *obj = OBJ_nid2obj(NID_undef);
    if (obj == NULL) {
        /* Fallback: create from empty string */
        obj = OBJ_txt2obj("", 1);
    }
    PUSH_OBJECT(obj, "openssl.asn1_object");
    ret = 1;
  }

  return ret;
}

/***
convert der encoded asn1type string to object
@function asn1type_d2i
@tparam string der
@treturn asn1type object for success, and nil for fail
*/
static int
openssl_asn1type_d2i(lua_State *L)
{
  size_t               size;
  const unsigned char *data = (const unsigned char *)luaL_checklstring(L, 1, &size);
  ASN1_TYPE           *at = d2i_ASN1_TYPE(NULL, &data, size);
  int                  ret = 0;
  if (at) {
    PUSH_OBJECT(at, "openssl.asn1_type");
    ret = 1;
  }
  return ret;
}

static luaL_Reg R[] = {
  { "new_object",          openssl_asn1object_new          },

  { "new_integer",         openssl_asn1int_new             },
  { "new_string",          openssl_asn1string_new          },
  { "new_utctime",         openssl_asn1utctime_new         },
  { "new_generalizedtime", openssl_asn1generalizedtime_new },

  { "new_type",            openssl_asn1type_new            },
  { "d2i_asn1type",        openssl_asn1type_d2i            },

  { "get_object",          openssl_get_object              },
  { "put_object",          openssl_put_object              },

  { "tostring",            openssl_asn1_tostring           },
  { "txt2nid",             openssl_txt2nid                 },

  { NULL,                  NULL                            }
};

/***
get the ASN.1 type tag number
@function type
@treturn number the ASN.1 type tag number
*/
static int
openssl_asn1type_type(lua_State *L)
{
  ASN1_TYPE *at = CHECK_OBJECT(1, ASN1_TYPE, "openssl.asn1_type");
  lua_pushinteger(L, at->type);
  return 1;
}

/***
get or set octet string data for asn1_type object
@function octet
@tparam[opt] string data optional octet string data to set
@treturn string current octet string data when called without parameters
@treturn boolean true when setting data successfully
*/
static int
openssl_asn1type_octet(lua_State *L)
{
  ASN1_TYPE *at = CHECK_OBJECT(1, ASN1_TYPE, "openssl.asn1_type");
  if (lua_isnone(L, 2)) {
    unsigned char *octet;
    int            len = ASN1_TYPE_get_octetstring(at, NULL, 0);
    int            ret = 0;
    octet = OPENSSL_malloc(len + 1);
    len = ASN1_TYPE_get_octetstring(at, octet, len + 1);
    if (len >= 0) {
      lua_pushlstring(L, (const char *)octet, (size_t)len);
      ret = 1;
    }
    OPENSSL_free(octet);
    return ret;
  } else {
    size_t      size;
    const char *octet = luaL_checklstring(L, 2, &size);
    int         ret = ASN1_TYPE_set_octetstring(at, (unsigned char *)octet, size);
    return openssl_pushresult(L, ret);
  }
}

/***
compare two asn1_type objects
@function cmp
@tparam asn1_type other another asn1_type object to compare with
@treturn boolean true if both asn1_type objects are equal, false otherwise
*/
static int
openssl_asn1type_cmp(lua_State *L)
{
  ASN1_TYPE *at = CHECK_OBJECT(1, ASN1_TYPE, "openssl.asn1_type");
  ASN1_TYPE *ot = CHECK_OBJECT(2, ASN1_TYPE, "openssl.asn1_type");
  int        ret = ASN1_TYPE_cmp(at, ot);
  lua_pushboolean(L, ret == 0);
  return 1;
}

static int
openssl_asn1type_free(lua_State *L)
{
  ASN1_TYPE *at = CHECK_OBJECT(1, ASN1_TYPE, "openssl.asn1_type");
  ASN1_TYPE_free(at);
  return 0;
}

/***
convert asn1_type to asn1_string object
@function asn1string
@treturn openssl.asn1_string|nil asn1_string object or nil if conversion is not supported
*/
static int
openssl_asn1type_asn1string(lua_State *L)
{
  ASN1_TYPE *at = CHECK_OBJECT(1, ASN1_TYPE, "openssl.asn1_type");
  int        ret = 0;
  if (at->type != V_ASN1_BOOLEAN && at->type != V_ASN1_OBJECT) {
    ASN1_STRING *as = ASN1_STRING_dup(at->value.asn1_string);
    PUSH_OBJECT(as, "openssl.asn1_string");
    ret = 1;
  }
  return ret;
}

/***
serialize asn1_type object to DER encoded string
@function i2d
@treturn string DER encoded representation of the asn1_type object
*/
static int
openssl_asn1type_i2d(lua_State *L)
{
  ASN1_TYPE     *at = CHECK_OBJECT(1, ASN1_TYPE, "openssl.asn1_type");
  unsigned char *out = NULL;
  int            len = i2d_ASN1_TYPE(at, &out);
  int            ret = 0;
  if (len > 0) {
    lua_pushlstring(L, (const char *)out, (size_t)len);
    OPENSSL_free(out);
    ret = 1;
  }
  return ret;
}

int
openssl_push_asn1type(lua_State *L, const ASN1_TYPE *type)
{
  lua_newtable(L);

#define P(V, v)                                                  \
  case V_##V: {                                                  \
    V *s = (V *)type->value.ptr;                                 \
    AUXILIAR_SETLSTR(L, -1, "value",                             \
                     (const char *)ASN1_STRING_get0_data(s),     \
                     ASN1_STRING_length(s));                     \
    break;                                                       \
  }

  switch (type->type) {
  case V_ASN1_BOOLEAN:
    AUXILIAR_SET(L, -1, "value", type->value.boolean, boolean);
    break;
  case V_ASN1_OBJECT: {
    ASN1_OBJECT *o = OBJ_dup(type->value.object);

    lua_pushliteral(L, "value");
    PUSH_OBJECT(o, "openssl.asn1_object");
    lua_rawset(L, -3);

    break;
  }
    P(ASN1_INTEGER, integer);
    P(ASN1_ENUMERATED, enumerated);
    P(ASN1_BIT_STRING, bit_string);
    P(ASN1_OCTET_STRING, octet_string);
    P(ASN1_PRINTABLESTRING, printablestring);
    P(ASN1_T61STRING, t61string);
    P(ASN1_IA5STRING, ia5string);
    P(ASN1_GENERALSTRING, generalstring);
    P(ASN1_BMPSTRING, bmpstring);
    P(ASN1_UNIVERSALSTRING, universalstring);
    P(ASN1_UTCTIME, utctime);
    P(ASN1_GENERALIZEDTIME, generalizedtime);
    P(ASN1_VISIBLESTRING, visiblestring);
    P(ASN1_UTF8STRING, utf8string);

  default: {
    ASN1_STRING *s = (ASN1_STRING *)type->value.asn1_string;
    AUXILIAR_SETLSTR(L, -1, "value", ASN1_STRING_get0_data(s), ASN1_STRING_length(s));
    break;
  }
  }
#undef P

  {
    unsigned char *dat = NULL;
    int            i = i2d_ASN1_TYPE((ASN1_TYPE *)type, &dat);
    if (i > 0) {
      AUXILIAR_SETLSTR(L, -1, "der", (const char *)dat, i);
      OPENSSL_free(dat);
    }
  }

  lua_pushinteger(L, type->type);
  lua_setfield(L, -2, "type");
  return 1;
}

/***
get detailed information about asn1_type object
@function info
@treturn table containing type information and data
*/
static int
openssl_asn1type_info(lua_State *L)
{
  ASN1_TYPE *type = CHECK_OBJECT(1, ASN1_TYPE, "openssl.asn1_type");
  return openssl_push_asn1type(L, type);
}

static luaL_Reg asn1type_funcs[] = {
  { "type",       openssl_asn1type_type       },
  { "octet",      openssl_asn1type_octet      },
  { "cmp",        openssl_asn1type_cmp        },
  { "info",       openssl_asn1type_info       },

  { "i2d",        openssl_asn1type_i2d        },
  { "asn1string", openssl_asn1type_asn1string },

  { "__tostring", auxiliar_tostring           },
  { "__eq",       openssl_asn1type_cmp        },
  { "__gc",       openssl_asn1type_free       },

  { NULL,         NULL                        }
};

/***
openssl.asn1_object object
@type asn1_object
*/
/***
get nid of asn1_object.

@function nid
@treturn integer nid of asn1_object
*/
static int
openssl_asn1object_nid(lua_State *L)
{
  ASN1_OBJECT *o = CHECK_OBJECT(1, ASN1_OBJECT, "openssl.asn1_object");
  lua_pushinteger(L, OBJ_obj2nid(o));
  return 1;
}

/***
get name of asn1_object.

@function name
@treturn string short name and followed by long name of asn1_object
*/
static int
openssl_asn1object_name(lua_State *L)
{
  ASN1_OBJECT *o = CHECK_OBJECT(1, ASN1_OBJECT, "openssl.asn1_object");
  int          nid = OBJ_obj2nid(o);
  lua_pushstring(L, OBJ_nid2sn(nid));
  lua_pushstring(L, OBJ_nid2ln(nid));
  return 2;
}

/***
get long name of asn1_object.

@function ln
@treturn string long name of asn1_object
*/
static int
openssl_asn1object_ln(lua_State *L)
{
  ASN1_OBJECT *o = CHECK_OBJECT(1, ASN1_OBJECT, "openssl.asn1_object");
  const char  *s = OBJ_nid2ln(OBJ_obj2nid(o));
  int          ret = 0;
  if (s) {
    lua_pushstring(L, s);
    ret = 1;
  }
  return ret;
}

/***
get short name of asn1_object.
@function sn
@treturn string short name of asn1_object
*/
static int
openssl_asn1object_sn(lua_State *L)
{
  ASN1_OBJECT *o = CHECK_OBJECT(1, ASN1_OBJECT, "openssl.asn1_object");
  const char  *s = OBJ_nid2sn(OBJ_obj2nid(o));
  int          ret = 0;
  if (s) {
    lua_pushstring(L, s);
    ret = 1;
  }
  return ret;
}

/***
get text of asn1_object.

@function txt
@tparam[opt] boolean no_name true for only oid or name, default with false
@treturn string long or short name, even oid of asn1_object
*/
static int
openssl_asn1object_txt(lua_State *L)
{
  ASN1_OBJECT *o = CHECK_OBJECT(1, ASN1_OBJECT, "openssl.asn1_object");
  int          no_name = lua_isnone(L, 2) ? 0 : lua_toboolean(L, 2);

  luaL_Buffer B;
  luaL_buffinit(L, &B);

  luaL_addsize(&B, OBJ_obj2txt(luaL_prepbuffer(&B), LUAL_BUFFERSIZE, o, no_name));
  luaL_pushresult(&B);
  return 1;
}

/***
compare two asn1_objects, if equals return true

@function equals
@tparam openssl.asn1_object another to compre
@treturn boolean true if equals
*/
static int
openssl_asn1object_equals(lua_State *L)
{
  ASN1_OBJECT *o = CHECK_OBJECT(1, ASN1_OBJECT, "openssl.asn1_object");
  ASN1_OBJECT *a = CHECK_OBJECT(2, ASN1_OBJECT, "openssl.asn1_object");

  lua_pushboolean(L, OBJ_cmp(o, a) == 0);
  return 1;
}

/***
get data of asn1_object

@function data
@treturn string asn1_object data
*/
static int
openssl_asn1object_data(lua_State *L)
{
  ASN1_OBJECT *s = CHECK_OBJECT(1, ASN1_OBJECT, "openssl.asn1_object");
  BIO         *bio = BIO_new(BIO_s_mem());
  BUF_MEM     *buf;

  i2a_ASN1_OBJECT(bio, s);
  BIO_get_mem_ptr(bio, &buf);
  lua_pushlstring(L, buf->data, buf->length);
  BIO_free(bio);
  return 1;
}

static int
openssl_asn1object_free(lua_State *L)
{
  ASN1_OBJECT *s = CHECK_OBJECT(1, ASN1_OBJECT, "openssl.asn1_object");
  ASN1_OBJECT_free(s);
  return 0;
}

/***
make a clone of asn1_object

@function dup
@treturn openssl.asn1_object clone for self
*/
static int
openssl_asn1object_dup(lua_State *L)
{
  ASN1_OBJECT *o = CHECK_OBJECT(1, ASN1_OBJECT, "openssl.asn1_object");
  ASN1_OBJECT *a = OBJ_dup(o);

  PUSH_OBJECT(a, "openssl.asn1_object");
  return 1;
}

/***
read der in to asn1_object

@function d2i
@treturn boolean
*/
static int
openssl_asn1object_d2i(lua_State *L)
{
  size_t               l;
  ASN1_OBJECT         *o = CHECK_OBJECT(1, ASN1_OBJECT, "openssl.asn1_object");
  const unsigned char *p = (const unsigned char *)luaL_checklstring(L, 2, &l);
  ASN1_OBJECT         *no = d2i_ASN1_OBJECT(NULL, &p, l);
  if (no != NULL) {
    ASN1_OBJECT_free(o);
    void **ud = lua_touserdata(L, 1);
    *ud = no;
  }
  lua_pushboolean(L, no != NULL);
  return 1;
}

/***
get der encoded of asn1_object

@function i2d
@treturn string
*/
static int
openssl_asn1object_i2d(lua_State *L)
{
  ASN1_OBJECT *o = CHECK_OBJECT(1, ASN1_OBJECT, "openssl.asn1_object");
  int          ret = i2d_ASN1_OBJECT(o, NULL);
  if (ret > 0) {
    unsigned char *p, *O;
    p = O = OPENSSL_malloc(ret);
    ret = i2d_ASN1_OBJECT(o, &p);
    if (ret > 0) {
      lua_pushlstring(L, (const char *)O, ret);
      ret = 1;
    }
    OPENSSL_free(O);
  }
  return ret == 1 ? 1 : 0;
}

static luaL_Reg asn1obj_funcs[] = {
  { "nid",        openssl_asn1object_nid    },
  { "name",       openssl_asn1object_name   },
  { "ln",         openssl_asn1object_ln     },
  { "sn",         openssl_asn1object_sn     },
  { "txt",        openssl_asn1object_txt    },
  { "dup",        openssl_asn1object_dup    },
  { "data",       openssl_asn1object_data   },
  { "equals",     openssl_asn1object_equals },
  { "d2i",        openssl_asn1object_d2i    },
  { "i2d",        openssl_asn1object_i2d    },

  { "__eq",       openssl_asn1object_equals },
  { "__gc",       openssl_asn1object_free   },
  { "__tostring", auxiliar_tostring         },

  { NULL,         NULL                      }
};

/***
openssl.asn1_integer object
@type asn1_integer
*/
/***
convert ASN1 integer to/from big number
@function bn
@tparam[opt] openssl.bn number big number to set, or nil to get current value
@treturn openssl.bn big number representation if getting, or previous value if setting
*/
static int
openssl_asn1int_bn(lua_State *L)
{
  ASN1_INTEGER *ai = CHECK_OBJECT(1, ASN1_INTEGER, "openssl.asn1_integer");
  if (lua_isnone(L, 2)) {
    BIGNUM *B = ASN1_INTEGER_to_BN(ai, NULL);
    PUSH_OBJECT(B, "openssl.bn");
  } else {
    BIGNUM *B = BN_get(L, 2);
    BN_to_ASN1_INTEGER(B, ai);
    BN_free(B);
    lua_pushvalue(L, 1);
  }
  return 1;
}

/***
openssl.asn1_string object
@type asn1_string
*/

/***
set value of ASN1 object

@function set
@tparam number|string value value to set (number for integers/times, string for time strings)
@treturn boolean result true for success
*/
static int
openssl_asn1group_set(lua_State *L)
{
  ASN1_STRING *s = CHECK_GROUP(1, ASN1_STRING, "openssl.asn1group");
  int          ret = 1;
  int          type = ASN1_STRING_type(s);

  switch (type) {
  case V_ASN1_INTEGER: {
    ASN1_INTEGER *ai = CHECK_OBJECT(1, ASN1_INTEGER, "openssl.asn1_integer");
    long          v = luaL_checklong(L, 2);
    ret = ASN1_INTEGER_set(ai, v);
    return openssl_pushresult(L, ret);
  }
  case V_ASN1_UTCTIME: {
    ASN1_TIME *a = CHECK_OBJECT(1, ASN1_TIME, "openssl.asn1_time");
    if (lua_type(L, 2) == LUA_TNUMBER) {
      time_t t = luaL_checkinteger(L, 2);
      ASN1_UTCTIME_set(a, t);
    } else if (lua_isstring(L, 2)) {
      ret = ASN1_TIME_set_string(a, lua_tostring(L, 2));
    } else
      luaL_error(L, "only accpet number or string");
    return openssl_pushresult(L, ret);
  }
  case V_ASN1_GENERALIZEDTIME: {
    ASN1_TIME *a = CHECK_OBJECT(1, ASN1_TIME, "openssl.asn1_time");
    if (lua_type(L, 2) == LUA_TNUMBER) {
      time_t t = luaL_checkinteger(L, 2);
      ASN1_GENERALIZEDTIME_set(a, t);
    } else if (lua_isstring(L, 2)) {
      ret = ASN1_GENERALIZEDTIME_set_string(a, lua_tostring(L, 2));
    } else
      luaL_error(L, "only accpet number or string");
    return openssl_pushresult(L, ret);
  }
  default:
    break;
  }
  return 0;
}

static time_t
ASN1_TIME_get(ASN1_TIME *time, time_t off)
{
  struct tm   t;
  size_t      i = 0;
  const char *str = (const char *)ASN1_STRING_get0_data(time);
  size_t      len = ASN1_STRING_length(time);
  int         type = ASN1_STRING_type(time);

  if (len < 13) return 0;  /* Invalid time format */
  memset(&t, 0, sizeof(t));

  if (type == V_ASN1_UTCTIME) /* two digit year */ {
    t.tm_year = (str[i++] - '0') * 10;
    t.tm_year += (str[i++] - '0');
    if (t.tm_year < 70) t.tm_year += 100;
  } else if (type == V_ASN1_GENERALIZEDTIME) /* four digit year */ {
    t.tm_year = (str[i++] - '0') * 1000;
    t.tm_year += (str[i++] - '0') * 100;
    t.tm_year += (str[i++] - '0') * 10;
    t.tm_year += (str[i++] - '0');
    t.tm_year -= 1900;
  }
  t.tm_mon = (str[i++] - '0') * 10;
  t.tm_mon += (str[i++] - '0') - 1;  // -1 since January is 0 not 1.
  t.tm_mday = (str[i++] - '0') * 10;
  t.tm_mday += (str[i++] - '0');
  t.tm_hour = (str[i++] - '0') * 10;
  t.tm_hour += (str[i++] - '0');
  t.tm_min = (str[i++] - '0') * 10;
  t.tm_min += (str[i++] - '0');
  t.tm_sec = (str[i++] - '0') * 10;
  t.tm_sec += (str[i++] - '0');

  /* Note: we did not adjust the time based on time zone information */
  return mktime(&t) + off;
}

/***
get value from ASN1 object

@function get
@treturn number|bn value extracted from ASN1 object (bn for integers, number for times)
*/
static int
openssl_asn1group_get(lua_State *L)
{
  ASN1_STRING *s = CHECK_GROUP(1, ASN1_STRING, "openssl.asn1group");
  int          ret = 0;
  switch (ASN1_STRING_type(s)) {
  case V_ASN1_INTEGER: {
    ASN1_INTEGER *ai = CHECK_OBJECT(1, ASN1_INTEGER, "openssl.asn1_integer");
    BIGNUM       *bn = ASN1_INTEGER_to_BN(ai, NULL);
    PUSH_OBJECT(bn, "openssl.bn");
    ret = 1;
    break;
  }
  case V_ASN1_UTCTIME:
  case V_ASN1_GENERALIZEDTIME: {
    ASN1_TIME *at = CHECK_OBJECT(1, ASN1_TIME, "openssl.asn1_time");
    time_t     get = ASN1_TIME_get(at, 0);
    lua_pushnumber(L, (lua_Number)get);
    ret = 1;
    break;
  }
  default:
    break;
  }
  return ret;
}

/***
encode ASN1 object to DER format

@function i2d
@treturn string DER encoded string
*/
static int
openssl_asn1group_i2d(lua_State *L)
{
  ASN1_STRING   *s = CHECK_GROUP(1, ASN1_STRING, "openssl.asn1group");
  int            len = 0;
  unsigned char *out = NULL;

#define P(T)                                                                                       \
  case V_##T: {                                                                                    \
    T *v = (T *)s;                                                                                 \
    len = i2d_##T(v, &out);                                                                        \
    break;                                                                                         \
  }

  switch (ASN1_STRING_type(s)) {
    /*
    P(ASN1_BOOLEAN);
    case V_ASN1_BOOLEAN:
    {
      ASN1_BOOLEAN b = (ASN1_BOOLEAN)(intptr_t)s;
      len = i2d_ASN1_BOOLEAN(b, &out);
      break;
    }
    */
    P(ASN1_INTEGER);
    /*
    P(ASN1_NEG_INTEGER);
    */
    P(ASN1_BIT_STRING);
    P(ASN1_OCTET_STRING);
    P(ASN1_NULL);
    P(ASN1_OBJECT);
    /*
    P(ASN1_OBJECT_DESCRIPTOR);
    P(ASN1_EXTERNAL);
    P(ASN1_REAL);
    */
    P(ASN1_ENUMERATED);
    /*
    P(ASN1_NEG_ENUMERATED);
    */
    P(ASN1_UTF8STRING);
    /*
    P(ASN1_SEQUENCE);
    P(ASN1_SET);
    P(ASN1_NUMERICSTRING);
    */
    P(ASN1_PRINTABLESTRING);
    P(ASN1_T61STRING);
    /*
    P(ASN1_TELETEXSTRING);
    P(ASN1_VIDEOTEXSTRING);
    */
    P(ASN1_IA5STRING);
    P(ASN1_UTCTIME);
    P(ASN1_GENERALIZEDTIME);
    /*
    P(ASN1_GRAPHICSTRING);
    P(ASN1_ISO64STRING);
    */
    P(ASN1_VISIBLESTRING);
    P(ASN1_GENERALSTRING);
    P(ASN1_UNIVERSALSTRING);
    P(ASN1_BMPSTRING);
  default:
    break;
  }
#undef P

  if (len > 0) {
    lua_pushlstring(L, (const char *)out, len);
    OPENSSL_free(out);
    return 1;
  }
  return openssl_pushresult(L, len);
}

/***
decode DER encoded string to ASN1 object

@function d2i
@tparam string der DER encoded string
@treturn asn1group self on success
@treturn boolean result false on failure
*/
static int
openssl_asn1group_d2i(lua_State *L)
{
  size_t               len;
  ASN1_STRING         *s = CHECK_GROUP(1, ASN1_STRING, "openssl.asn1group");
  const unsigned char *der = (const unsigned char *)luaL_checklstring(L, 2, &len);

#define P(T)                                                                                       \
  case V_##T: {                                                                                    \
    T *v = d2i_##T(NULL, &der, (long)len);                                                         \
    if (v == NULL)                                                                                 \
      return openssl_pushresult(L, -1);                                                            \
    else {                                                                                         \
      ASN1_STRING_free(s);                                                                         \
      void **ud = lua_touserdata(L, 1);                                                            \
      *ud = v;                                                                                     \
      lua_pushvalue(L, 1);                                                                         \
    }                                                                                              \
    break;                                                                                         \
  }

  switch (ASN1_STRING_type(s)) {
    /*
    P(ASN1_BOOLEAN);
    case V_ASN1_BOOLEAN:
    {
      ASN1_BOOLEAN b = (ASN1_BOOLEAN)(intptr_t)s;
      b = d2i_ASN1_BOOLEAN(&b, &der, (long)len);
      lua_pushboolean(L, b);
      return 1;
    }
    */
    P(ASN1_INTEGER);
    /*
    P(ASN1_NEG_INTEGER);
    */
    P(ASN1_BIT_STRING);
    P(ASN1_OCTET_STRING);
    P(ASN1_NULL);
    P(ASN1_OBJECT);
    /*
    P(ASN1_OBJECT_DESCRIPTOR);
    P(ASN1_EXTERNAL);
    P(ASN1_REAL);
    */
    P(ASN1_ENUMERATED);
    /*
    P(ASN1_NEG_ENUMERATED);
    */
    P(ASN1_UTF8STRING);
    /*
    P(ASN1_SEQUENCE);
    P(ASN1_SET);
    P(ASN1_NUMERICSTRING);
    */
    P(ASN1_PRINTABLESTRING);
    P(ASN1_T61STRING);
    /*
    P(ASN1_TELETEXSTRING);
    P(ASN1_VIDEOTEXSTRING);
    */
    P(ASN1_IA5STRING);
    P(ASN1_UTCTIME);
    P(ASN1_GENERALIZEDTIME);
    /*
    P(ASN1_GRAPHICSTRING);
    P(ASN1_ISO64STRING);
    */
    P(ASN1_VISIBLESTRING);
    P(ASN1_GENERALSTRING);
    P(ASN1_UNIVERSALSTRING);
    P(ASN1_BMPSTRING);
  default:
    return 0;
  }
#undef P

  return 1;
}

/***
get type of asn1_string

@function type
@treturn string type of asn1_string
-- @see OpenSSL function: ASN1_STRING_new
*/
static int
openssl_asn1group_type(lua_State *L)
{
  ASN1_STRING *s = CHECK_GROUP(1, ASN1_STRING, "openssl.asn1group");
  int          type = ASN1_STRING_type(s);
  int          i, ret = 1;
  lua_pushinteger(L, type);
  for (i = 0; i < TAG_IDX_LENGTH; i++) {
    if (type == asn1_const[i + TAG_IDX_OFFSET].val) {
      lua_pushstring(L, asn1_const[i + TAG_IDX_OFFSET].name);
      ret += 1;
      break;
    }
  }
  return ret;
}

/***
get length of asn1_string

@function length
@treturn integer length of asn1_string
@usage
  local astr = asn1.new_string('ABCD')
  print('length:',#astr)
  print('length:',astr:length())
  assert(#astr==astr:length,"must equals")
*/
static int
openssl_asn1group_length(lua_State *L)
{
  ASN1_STRING *s = CHECK_GROUP(1, ASN1_STRING, "openssl.asn1group");
  lua_pushinteger(L, ASN1_STRING_length(s));
  return 1;
}

/***
get data of asn1_string

@function data
@treturn string raw data of asn1_string
*/

/***
set data of asn1_string

@function data
@tparam string data set to asn1_string
@treturn boolean success if value set true, or follow by errmsg
@treturn string fail error message
*/
static int
openssl_asn1group_data(lua_State *L)
{
  ASN1_STRING *s = CHECK_GROUP(1, ASN1_STRING, "openssl.asn1group");
  if (lua_isnone(L, 2))
    lua_pushlstring(L, (const char *)ASN1_STRING_get0_data(s), ASN1_STRING_length(s));
  else {
    size_t      l;
    const char *data = luaL_checklstring(L, 2, &l);
    int         ret = ASN1_STRING_set(s, data, l);
    lua_pushboolean(L, ret);
  }
  return 1;
}

/***
compare two asn1_string, if equals return true

@function equals
@tparam openssl.asn1_string another to compre
@treturn boolean true if equals
@usage
  local obj = astr:dup()
  assert(obj==astr, "must equals")
*/
/***
compare two ASN1 string objects for equality
@function __eq
@tparam openssl.asn1_string other ASN1 string object to compare with
@treturn boolean true if objects are equal
*/
static int
openssl_asn1group_eq(lua_State *L)
{
  ASN1_STRING *s = CHECK_GROUP(1, ASN1_STRING, "openssl.asn1group");
  ASN1_STRING *ss = CHECK_GROUP(2, ASN1_STRING, "openssl.asn1group");

  lua_pushboolean(L, (ASN1_STRING_type(s) == ASN1_STRING_type(ss)
                      && ASN1_STRING_cmp(s, ss) == 0));
  return 1;
}

static int
openssl_asn1group_free(lua_State *L)
{
  ASN1_STRING *s = CHECK_GROUP(1, ASN1_STRING, "openssl.asn1group");
  ASN1_STRING_free(s);
  return 0;
}

/***
convert asn1_string to lua string

@function __tostring
@treturn string result format match with type:data
*/
static int
openssl_asn1group_tostring(lua_State *L)
{
  ASN1_STRING *s = CHECK_GROUP(1, ASN1_STRING, "openssl.asn1group");
  int          ret = 0;

  if (s) {
    int type = ASN1_STRING_type(s);

    switch (type) {
    case V_ASN1_INTEGER:
    case V_ASN1_BIT_STRING: {
      BIGNUM *bn
        = BN_bin2bn((const unsigned char *)ASN1_STRING_get0_data(s), ASN1_STRING_length(s), NULL);
      char *str = BN_bn2hex(bn);
      lua_pushstring(L, str);
      BN_free(bn);
      OPENSSL_free(str);
      break;
    }
    default:
      lua_pushlstring(L, (const char *)ASN1_STRING_get0_data(s), ASN1_STRING_length(s));
      break;
    }
    ret = 1;
  }
  return ret;
}

/***
get data as printable encode string

@function toprint
@treturn string printable encoded string
*/
static int
openssl_asn1group_toprint(lua_State *L)
{
  ASN1_STRING  *s = CHECK_GROUP(1, ASN1_STRING, "openssl.asn1group");
  unsigned long flags = luaL_optint(L, 2, 0);
  BIO          *out = BIO_new(BIO_s_mem());
  BUF_MEM      *mem;
  switch (ASN1_STRING_type(s)) {
  case V_ASN1_UTCTIME: {
    ASN1_TIME *a = (ASN1_TIME *)s;
    ASN1_TIME_print(out, a);
    break;
  }
  case V_ASN1_GENERALIZEDTIME: {
    ASN1_GENERALIZEDTIME *a = (ASN1_GENERALIZEDTIME *)s;
    ASN1_GENERALIZEDTIME_print(out, a);
    break;
  }
  default:
    ASN1_STRING_print_ex(out, s, flags);
  }

  BIO_get_mem_ptr(out, &mem);
  lua_pushlstring(L, mem->data, mem->length);
  BIO_free(out);
  return 1;
}

/***
get data as utf8 encode string

@function toutf8
@treturn string utf8 encoded string
*/
static int
openssl_asn1group_toutf8(lua_State *L)
{
  ASN1_STRING   *s = CHECK_GROUP(1, ASN1_STRING, "openssl.asn1group");
  unsigned char *out = NULL;
  int            len = ASN1_STRING_to_UTF8(&out, s);
  if (out) {
    lua_pushlstring(L, (const char *)out, len);
    OPENSSL_free(out);
  }
  return 1;
}

/***
duplicate a new asn1_string

@function dup
@treturn openssl.asn1_string clone for self
*/
static int
openssl_asn1group_dup(lua_State *L)
{
  ASN1_STRING *s = CHECK_GROUP(1, ASN1_STRING, "openssl.asn1group");
  openssl_push_asn1(L, s, ASN1_STRING_type(s));
  return 1;
}

/***
check if asn1_time object is valid
@function check
@treturn boolean true if asn1_time is valid, false otherwise
*/
static int
openssl_asn1time_check(lua_State *L)
{
  ASN1_TIME *a = CHECK_OBJECT(1, ASN1_TIME, "openssl.asn1_time");
  int        ret = ASN1_TIME_check(a);
  return openssl_pushresult(L, ret);
}

/***
adjust asn1_time by specified offset
@function adj
@tparam number time base time as Unix timestamp
@tparam[opt=0] number offset_day offset in days
@tparam[opt=0] number offset_sec offset in seconds
@treturn asn1_time adjusted asn1_time object (self)
*/
static int
openssl_asn1time_adj(lua_State *L)
{
  ASN1_TIME *at = CHECK_OBJECT(1, ASN1_TIME, "openssl.asn1_time");
  time_t     t = luaL_checkinteger(L, 2);
  int        offset_day = luaL_optint(L, 3, 0);
  long       offset_sec = luaL_optlong(L, 4, 0);

  switch (ASN1_STRING_type(at)) {
  case V_ASN1_UTCTIME: {
    ASN1_UTCTIME *a = (ASN1_UTCTIME *)at;
    ASN1_UTCTIME_adj(a, t, offset_day, offset_sec);
    break;
  }
  case V_ASN1_GENERALIZEDTIME: {
    ASN1_GENERALIZEDTIME *a = (ASN1_UTCTIME *)at;
    ASN1_GENERALIZEDTIME_adj(a, t, offset_day, offset_sec);
    break;
  }
  }
  lua_pushvalue(L, 1);
  return 1;
}

#if !defined(LIBRESSL_VERSION_NUMBER)
/***
calculate difference between two asn1_time objects
@function diff
@tparam asn1_time to target time to compare with
@treturn[1] number difference in days
@treturn[1] number difference in seconds
@treturn[2] nil when comparison fails
*/
static int
openssl_asn1time_diff(lua_State *L)
{
  int        day, sec, ret;
  ASN1_TIME *from = CHECK_OBJECT(1, ASN1_TIME, "openssl.asn1_time");
  ASN1_TIME *to = lua_isnoneornil(L, 2) ? NULL : CHECK_OBJECT(2, ASN1_TIME, "openssl.asn1_time");

  luaL_argcheck(L, ASN1_STRING_type(to) == ASN1_STRING_type(from), 2, "asn1_time with mismatched type");

  ret = ASN1_TIME_diff(&day, &sec, from, to);
  if (ret == 1) {
    lua_pushinteger(L, day);
    lua_pushinteger(L, sec);
  }
  return ret == 1 ? 2 : openssl_pushresult(L, ret);
}
#endif

static luaL_Reg asn1str_funcs[] = {
  /* asn1string */
  { "length",     openssl_asn1group_length   },
  { "type",       openssl_asn1group_type     },
  { "data",       openssl_asn1group_data     },

  { "dup",        openssl_asn1group_dup      },

  { "toutf8",     openssl_asn1group_toutf8   },
  { "toprint",    openssl_asn1group_toprint  },
  { "tostring",   openssl_asn1group_tostring },

  { "__len",      openssl_asn1group_length   },
  { "__tostring", auxiliar_tostring          },

  { "__eq",       openssl_asn1group_eq       },
  { "__gc",       openssl_asn1group_free     },

  { "set",        openssl_asn1group_set      },
  { "get",        openssl_asn1group_get      },
  { "i2d",        openssl_asn1group_i2d      },
  { "d2i",        openssl_asn1group_d2i      },

  /* asn1int */
  { "bn",         openssl_asn1int_bn         },

  /* asn1time,asn1generalizedtime */
  { "adj",        openssl_asn1time_adj       },
#if !defined(LIBRESSL_VERSION_NUMBER)
  { "diff",       openssl_asn1time_diff      },
#endif
  { "check",      openssl_asn1time_check     },

  { NULL,         NULL                       }
};

int
luaopen_asn1(lua_State *L)
{
  auxiliar_newclass(L, "openssl.asn1_object", asn1obj_funcs);
  auxiliar_newclass(L, "openssl.asn1_type", asn1type_funcs);

  auxiliar_newclass(L, "openssl.asn1_string", asn1str_funcs);
  auxiliar_newclass(L, "openssl.asn1_integer", asn1str_funcs);
  auxiliar_newclass(L, "openssl.asn1_time", asn1str_funcs);

  auxiliar_add2group(L, "openssl.asn1_time", "openssl.asn1group");
  auxiliar_add2group(L, "openssl.asn1_string", "openssl.asn1group");
  auxiliar_add2group(L, "openssl.asn1_integer", "openssl.asn1group");

  lua_newtable(L);
  luaL_setfuncs(L, R, 0);

  auxiliar_enumerate(L, -1, asn1_const);

  return 1;
}

ASN1_OBJECT *
openssl_get_asn1object(lua_State *L, int idx, int nil)
{
  ASN1_OBJECT *obj = NULL;

  if (lua_isstring(L, idx)) {
    obj = OBJ_txt2obj(lua_tostring(L, idx), 0);
  } else if (auxiliar_getclassudata(L, "openssl.asn1_object", idx) != NULL) {
    ASN1_OBJECT *in = CHECK_OBJECT(idx, ASN1_OBJECT, "openssl.asn1_object");
    obj = OBJ_dup(in);
  }

  return obj;
}

int
openssl_push_asn1object(lua_State *L, const ASN1_OBJECT *obj)
{
  ASN1_OBJECT *dup = OBJ_dup(obj);
  PUSH_OBJECT(dup, "openssl.asn1_object");
  return 1;
}

int
openssl_push_asn1(lua_State *L, const ASN1_STRING *string, int type)
{
  int strType = ASN1_STRING_type(string);
  if ((strType & V_ASN1_GENERALIZEDTIME) == V_ASN1_GENERALIZEDTIME && type == V_ASN1_UTCTIME)
    type = V_ASN1_GENERALIZEDTIME;
  else if ((strType & V_ASN1_UTCTIME) == V_ASN1_UTCTIME && type == V_ASN1_GENERALIZEDTIME)
    type = V_ASN1_UTCTIME;
  else if (type == V_ASN1_UNDEF)
    type = strType;

  switch (type) {
  case V_ASN1_INTEGER: {
    ASN1_INTEGER *dup = ASN1_INTEGER_dup((ASN1_INTEGER *)string);
    PUSH_OBJECT(dup, "openssl.asn1_integer");
    return 1;
  }
  case V_ASN1_UTCTIME:
  case V_ASN1_GENERALIZEDTIME: {
    ASN1_TIME *dup = (ASN1_TIME *)ASN1_STRING_dup(string);
    PUSH_OBJECT(dup, "openssl.asn1_time");
    return 1;
  }
  case V_ASN1_OCTET_STRING:
  case V_ASN1_BIT_STRING:
  default: {
    ASN1_STRING *dup = ASN1_STRING_dup(string);
    PUSH_OBJECT(dup, "openssl.asn1_string");
    return 1;
  }
  }
}

int
openssl_push_asn1integer_as_bn(lua_State *L, const ASN1_INTEGER *ai)
{
  if (ai != NULL) {
    BIGNUM *bn = ASN1_INTEGER_to_BN(ai, NULL);
    PUSH_OBJECT(bn, "openssl.bn");
  } else
    lua_pushnil(L);
  return 1;
}
