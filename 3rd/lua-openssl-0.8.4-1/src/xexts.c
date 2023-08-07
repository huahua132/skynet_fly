/***
x509.extension module to mapping X509_EXTENSION to lua object.

@module x509.extension
@usage
  extension = require('openssl').x509.extension
*/
#include <ctype.h>
#include "openssl.h"
#include "private.h"
#include <openssl/x509v3.h>

#include "sk.h"

/***
x509_extension contrust param table.

@table x509_extension_param_table
@tfield boolean critical true set critical
@tfield asn1_string value of x509_extension
@tfield string|asn1_object object, object of extension

@usage
xattr = x509.attrextension.new_extension {
  object = asn1_object,
  critical = false,
  value = string or asn1_string value
}
*/
static X509_EXTENSION* openssl_new_xextension(lua_State*L, int idx, int v3)
{
  int critical = 0;
  ASN1_OCTET_STRING* value = NULL;
  X509_EXTENSION* y = NULL;
  ASN1_OBJECT *obj = NULL;
  int nid = NID_undef;

  lua_getfield(L, idx, "object");
  obj = openssl_get_asn1object(L, -1, 0);
  nid = OBJ_obj2nid(obj);
  ASN1_OBJECT_free(obj);
  lua_pop(L, 1);

  lua_getfield(L, idx, "critical");
  critical = lua_isnil(L, -1) ? 0 : lua_toboolean(L, -1);
  lua_pop(L, 1);

  lua_getfield(L, idx, "value");
  if (lua_isstring(L, -1))
  {
    size_t size;
    const char* data = lua_tolstring(L, -1, &size);
    lua_pop(L, 1);
    if (v3)
    {
      const X509V3_EXT_METHOD *method = X509V3_EXT_get_nid(nid);
      if (method)
      {
        void *ext_struc = NULL;
        STACK_OF(CONF_VALUE) *nval = X509V3_parse_list(data);
        /* Now get internal extension representation based on type */
        if (method->v2i && nval)
        {
          if (sk_CONF_VALUE_num(nval) > 0)
          {
            ext_struc = method->v2i(method, NULL, nval);
          }
        }
        else if (method->s2i)
        {
          ext_struc = method->s2i(method, NULL, data);
        }
        if (nval)
          sk_CONF_VALUE_pop_free(nval, X509V3_conf_free);

        if (ext_struc)
        {
          unsigned char *ext_der = NULL;
          int ext_len;
          /* Convert internal representation to DER */
          if (method->it)
          {
            ext_der = NULL;
            ext_len = ASN1_item_i2d(ext_struc, &ext_der, ASN1_ITEM_ptr(method->it));
            if (ext_len < 0) ext_der = NULL;
          }
          else
          {
            ext_len = method->i2d(ext_struc, NULL);
            ext_der = OPENSSL_malloc(ext_len);
            if (ext_der)
            {
              unsigned char* p = ext_der;
              method->i2d(ext_struc, &p);
            }
          }
          if (ext_der)
          {
            value = ASN1_STRING_type_new(V_ASN1_OCTET_STRING);
            ASN1_STRING_set(value, ext_der, ext_len);
            OPENSSL_free(ext_der);
          }
          else value = NULL;

          if (method->it) ASN1_item_free(ext_struc, ASN1_ITEM_ptr(method->it));
          else method->ext_free(ext_struc);
        }
      }
      else
      {
        value = ASN1_STRING_type_new(V_ASN1_OCTET_STRING);
        ASN1_STRING_set(value, data, size);
      }
    }
    else
    {
      value = ASN1_STRING_type_new(V_ASN1_OCTET_STRING);
      ASN1_STRING_set(value, data, size);
    }
    if (value)
    {
      y = X509_EXTENSION_create_by_NID(NULL, nid, critical, value);
      ASN1_STRING_free(value);
      return y;
    }
    else
    {
      luaL_error(L, "don't support object(%s) with value (%s)", OBJ_nid2ln(nid), data);
      return NULL;
    }
  }
  else
  {
    value = GET_GROUP(-1, ASN1_STRING, "openssl.asn1group");
    if(value)
    {
      y = X509_EXTENSION_create_by_NID(NULL, nid, critical, value);
      lua_pop(L, 1);
      return y;
    }
  }
  luaL_argerror(L, 1, "field value must be string or openssl.asn1group object");
  return NULL;
}

/***
Create x509_extension object
@function new_extension
@tparam table extension with object, value and critical
@treturn x509_extension mapping to X509_EXTENSION in openssl
@see x509_extension_param_table
*/
static int openssl_xext_new(lua_State* L)
{
  X509_EXTENSION *x = NULL;
  int ret = 0, v3 = 1;
  luaL_checktable(L, 1);
  if (!lua_isnone(L, 2)) v3 = lua_toboolean(L, 2);
  x = openssl_new_xextension(L, 1, v3);
  if (x)
  {
    PUSH_OBJECT(x, "openssl.x509_extension");
    ret = 1;
  }
  return ret;
};

/***
read der encoded x509_extension
@function read_extension
@tparam string data der encoded
@treturn x509_extension mappling to X509_EXTENSION in openssl
*/
static int openssl_xext_read(lua_State* L)
{
  int ret = 0;
  size_t size;
  const unsigned char* s = (const unsigned char*)luaL_checklstring(L, 1, &size);
  X509_EXTENSION *x = d2i_X509_EXTENSION(NULL, &s, size);
  if (x)
  {
    PUSH_OBJECT(x, "openssl.x509_extension");
    ret = 1;
  }
  return ret;
};

/***
get all x509 certificate supported extensions
@function support
@treturn table contain all support extension info as table node {lname=..., sname=..., nid=...}
*/
/***
check x509_extension object support or not
@function support
@tparam x509_extension extension
@treturn boolean true for supported, false or not
*/
/***
check nid or name support or not
@function support
@tparam number|string nid_or_name for extension
@treturn boolean true for supported, false or not
*/
static int openssl_xext_support(lua_State*L)
{
  int ret = 0;
  static const int supported_nids[] =
  {
    NID_netscape_cert_type, /* 71 */
    NID_key_usage,    /* 83 */
    NID_subject_alt_name, /* 85 */
    NID_basic_constraints,  /* 87 */
    NID_certificate_policies, /* 89 */
    NID_ext_key_usage,  /* 126 */
#ifndef OPENSSL_NO_RFC3779
    NID_sbgp_ipAddrBlock, /* 290 */
    NID_sbgp_autonomousSysNum, /* 291 */
#endif
    NID_policy_constraints, /* 401 */
    NID_proxyCertInfo,  /* 663 */
    NID_name_constraints, /* 666 */
    NID_policy_mappings,  /* 747 */
    NID_inhibit_any_policy  /* 748 */
  };
  if (lua_isnoneornil(L, 1))
  {
    int count = sizeof(supported_nids) / sizeof(int);
    int i, nid;
    lua_newtable(L);
    for (i = 0; i < count; i++)
    {
      nid = supported_nids[i];
      lua_newtable(L);
      lua_pushstring(L, OBJ_nid2ln(nid));
      lua_setfield(L, -2, "lname");
      lua_pushstring(L, OBJ_nid2sn(nid));
      lua_setfield(L, -2, "sname");
      lua_pushinteger(L, nid);
      lua_setfield(L, -2, "nid");
      lua_rawseti(L, -2, i + 1);
    };
    ret = 1;
  }
  else if (auxiliar_getclassudata(L, "openssl.x509_extension", 1))
  {
    X509_EXTENSION* ext = CHECK_OBJECT(1, X509_EXTENSION, "openssl.x509_extension");
    ret = X509_supported_extension(ext);
    lua_pushboolean(L, ret);
    ret = 1;
  }
  else
  {
    int i;
    int nid = NID_undef;
    ASN1_OBJECT *obj = openssl_get_asn1object(L, 1, 1);
    if (obj)
    {
      nid = OBJ_obj2nid(obj);
      ASN1_OBJECT_free(obj);

      for (i = 0; i < sizeof(supported_nids) / sizeof(int); i++)
      {
        if (supported_nids[i] == nid) break;
      }
      lua_pushboolean(L, i < sizeof(supported_nids) / sizeof(int));
      return 1;
    }

  }
  return ret;
}

static luaL_Reg R[] =
{
  {"support",                 openssl_xext_support},
  {"new_extension",           openssl_xext_new},
  {"read_extension",          openssl_xext_read},

  {NULL,          NULL},
};

/***
openssl.x509_extension object
@type x509_extension
*/

/***
x509_extension infomation table
@todo double check
@table x509_extension_info_table
@tfield asn1_object|object object of x509_extension
@tfield boolean|critical true for critical value
@tfield string|value as octet string
*/
static int openssl_xext_totable(lua_State* L, X509_EXTENSION *x)
{
  ASN1_OBJECT *obj = X509_EXTENSION_get_object(x);
  int nid = OBJ_obj2nid(obj);
  lua_newtable(L);
  openssl_push_asn1object(L, obj);
  lua_setfield(L, -2, "object");

  PUSH_ASN1_OCTET_STRING(L, X509_EXTENSION_get_data(x));
  lua_setfield(L, -2, "value");

  AUXILIAR_SET(L, -1, "critical", X509_EXTENSION_get_critical(x), boolean);

  switch (nid)
  {
  case NID_subject_alt_name:
  {
    int i;
    int n_general_names;

    STACK_OF(GENERAL_NAME) *values = X509V3_EXT_d2i(x);

    if (values == NULL) break;

    /* Push ret[oid] */
    openssl_push_asn1object(L, obj);
    lua_newtable(L);
    n_general_names = sk_GENERAL_NAME_num(values);
    for (i = 0; i < n_general_names; i++)
    {
      GENERAL_NAME *general_name = sk_GENERAL_NAME_value(values, i);
      openssl_push_general_name(L, general_name);
      lua_rawseti(L, -2, i + 1);
    }
    lua_settable(L, -3);
    sk_GENERAL_NAME_pop_free(values, GENERAL_NAME_free);
  }
  default:
    break;
  }
  return 1;
};

/***
get infomation table of x509_extension.

@function info
@tparam[opt] boolean|utf8 true for utf8 default
@treturn[1] table info,  x509_extension infomation as table
@see x509_extension_info_table
*/
static int openssl_xext_info(lua_State* L)
{
  X509_EXTENSION *x = CHECK_OBJECT(1, X509_EXTENSION, "openssl.x509_extension");
  return openssl_xext_totable(L, x);
};

/***
clone then x509_extension

@function dup
@treturn x509_extension clone of x509_extension
*/
static int openssl_xext_dup(lua_State* L)
{
  X509_EXTENSION *x = CHECK_OBJECT(1, X509_EXTENSION, "openssl.x509_extension");
  X509_EXTENSION *d = X509_EXTENSION_dup(x);
  PUSH_OBJECT(d, "openssl.x509_extension");
  return 1;
};

/***
export x509_extenion to der encoded string
@function export
@treturn string
*/
static int openssl_xext_export(lua_State* L)
{
  X509_EXTENSION *x = CHECK_OBJECT(1, X509_EXTENSION, "openssl.x509_extension");
  unsigned char* p = NULL;
  int ret = i2d_X509_EXTENSION(x, &p);
  if (ret > 0)
  {
    lua_pushlstring(L, (const char *)p, ret);
    OPENSSL_free(p);
  }
  return ret > 0 ? 1 : 0;
};

static int openssl_xext_free(lua_State* L)
{
  X509_EXTENSION *x = CHECK_OBJECT(1, X509_EXTENSION, "openssl.x509_extension");
  X509_EXTENSION_free(x);
  return 0;
};

/***
get asn1_object of x509_extension.
@function object
@treturn asn1_object object of x509_extension
*/

/***
set asn1_object for x509_extension.

@function object
@tparam asn1_object obj
@treturn boolean true for success
@return nil when occure error, and followed by error message
*/
static int openssl_xext_object(lua_State* L)
{
  X509_EXTENSION *x = CHECK_OBJECT(1, X509_EXTENSION, "openssl.x509_extension");
  ASN1_OBJECT* obj;
  if (lua_isnone(L, 2))
  {
    obj = X509_EXTENSION_get_object(x);
    openssl_push_asn1object(L, obj);
    return 1;
  }
  else
  {
    ASN1_OBJECT *obj = openssl_get_asn1object(L, 2, 0);
    int ret = X509_EXTENSION_set_object(x, obj);
    ASN1_OBJECT_free(obj);
    return openssl_pushresult(L, ret);
  }
};

/***
get critical of x509_extension.

@function critical
@treturn boolean true if extension set critical or false
*/
/***
set critical of x509_extension.

@function critical
@tparam boolean critical set to self
@treturn boolean set critical success return true
@return nil fail return nil, and followed by error message
*/
static int openssl_xext_critical(lua_State* L)
{
  X509_EXTENSION *x = CHECK_OBJECT(1, X509_EXTENSION, "openssl.x509_extension");
  if (lua_isnone(L, 2))
  {
    lua_pushboolean(L, X509_EXTENSION_get_critical(x));
    return 1;
  }
  else
  {
    int ret = X509_EXTENSION_set_critical(x, lua_toboolean(L, 2));
    return openssl_pushresult(L, ret);
  }
};

/***
get data of x509_extension

@function data
@treturn asn1_string
*/

/***
set type of x509_extension

@function data
@tparam asn1_string data set to self
@treturn boolean result true for success
@return nil for error, and followed by error message
*/
static int openssl_xext_data(lua_State* L)
{
  int ret = 0;

  X509_EXTENSION *x = CHECK_OBJECT(1, X509_EXTENSION, "openssl.x509_extension");
  if (lua_isnone(L, 2))
  {
    ASN1_STRING *s = X509_EXTENSION_get_data(x);
    PUSH_ASN1_STRING(L, s);
    ret = 1;
  }
  else if (lua_isstring(L, 2))
  {
    size_t size;
    const char* data = lua_tolstring(L, 2, &size);
    int type = lua_isnone(L, 3) ? V_ASN1_OCTET_STRING : luaL_checkint(L, 3);
    ASN1_STRING* s = ASN1_STRING_type_new(type);
    if (ASN1_STRING_set(s, data, size) == 1)
    {
      ret = X509_EXTENSION_set_data(x, s);
    }
    ASN1_STRING_free(s);
    ret = openssl_pushresult(L, ret);
  }
  else
  {
    ASN1_STRING* s = CHECK_GROUP(2, ASN1_STRING, "openssl.asn1group");
    luaL_argcheck(L,
                  ASN1_STRING_type(s) == V_ASN1_OCTET_STRING,
                  2,
                  "only accpet asn1 octet string if is a asn1 string"
                  );

    ret = X509_EXTENSION_set_data(x, s);
    ret = openssl_pushresult(L, ret);
  }
  return ret;
};

static luaL_Reg x509_extension_funs[] =
{
  {"info",          openssl_xext_info},
  {"dup",           openssl_xext_dup},
  {"export",        openssl_xext_export},

  /* set and get */
  {"object",        openssl_xext_object},
  {"critical",      openssl_xext_critical},
  {"data",          openssl_xext_data},

  {"__gc",          openssl_xext_free},
  {"__tostring",    auxiliar_tostring},

  { NULL, NULL }
};

IMP_LUA_SK(X509_EXTENSION, x509_extension)

int openssl_register_xextension(lua_State*L)
{
  auxiliar_newclass(L, "openssl.x509_extension", x509_extension_funs);
  lua_newtable(L);
  luaL_setfuncs(L, R, 0);
  return 1;
}
