/***
x509.attribute module to mapping X509_ATTRIBUTE to lua object.

@module x509.attribute
@usage
  attr = require('openssl').x509.attribute
*/
#include "openssl.h"
#include "private.h"
#include "sk.h"

/***
x509_attribute contrust param table.

@table x509_attribute_param_table
@tfield string|integer|asn1_object object, identify a asn1_object
@tfield string|integer type, same with type in asn1.new_string
@tfield string|asn1_object value, value of attribute

@usage
xattr = x509.attribute.new_attribute {
  object = asn1_object,
  type = Nid_or_String,
  value = string or asn1_string value
}
*/

/***
asn1_type object as table

@table asn1_type_table
@tfield string value, value data
@tfield string type, type of value
@tfield string format, value is 'der', only exist when type is not in 'bit','bmp','octet'
*/

/***
Create x509_attribute object

@function new_attribute
@tparam table attribute with object, type and value
@treturn[1] x509_attribute mapping to X509_ATTRIBUTE in openssl

@see x509_attribute_param_table
*/
static int openssl_xattr_new(lua_State*L)
{
  X509_ATTRIBUTE *x = NULL;
  luaL_checktable(L, 1);

  x = openssl_new_xattribute(L, NULL, 1);
  PUSH_OBJECT(x, "openssl.x509_attribute");
  return 1;
}

static luaL_Reg R[] =
{
  {"new_attribute",         openssl_xattr_new},

  {NULL,          NULL},
};

/***
x509_attribute infomation table

@table x509_attribute_info_table
@tfield asn1_object|object object of asn1_object
@tfield boolean single  true for single value
@tfield table value  if single, value is asn1_type or array have asn1_type node table
*/
static int openssl_xattr_totable(lua_State*L, X509_ATTRIBUTE *attr)
{
  int i, c;

  lua_newtable(L);
  openssl_push_asn1object(L, X509_ATTRIBUTE_get0_object(attr));
  lua_setfield(L, -2, "object");

  c = X509_ATTRIBUTE_count(attr);
  if (c > 0)
  {
    lua_newtable(L);
    for (i = 0; i < c; i++)
    {
      ASN1_TYPE* t = X509_ATTRIBUTE_get0_type(attr, i);
      openssl_push_asn1type(L, t);
      lua_rawseti(L, -2, i + 1);
    }
    lua_setfield(L, -2, "value");
  }

#if OPENSSL_VERSION_NUMBER < 0x10100000L
  if (attr->single)
  {

    openssl_push_asn1type(L, attr->value.single);
    lua_setfield(L, -2, "value");
  }
#endif

  return 1;
}

/***
openssl.x509_attribute object
@type x509_attribute
*/

/***
get infomation table of x509_attribute.

@function info
@treturn[1] table info,  x509_attribute infomation as table
@see x509_attribute_info_table
*/
static int openssl_xattr_info(lua_State*L)
{
  X509_ATTRIBUTE* attr = CHECK_OBJECT(1, X509_ATTRIBUTE, "openssl.x509_attribute");
  return openssl_xattr_totable(L, attr);
}

/***
clone then asn1_attribute

@function dup
@treturn x509_attribute attr clone of x509_attribute
*/
static int openssl_xattr_dup(lua_State*L)
{
  X509_ATTRIBUTE* attr = CHECK_OBJECT(1, X509_ATTRIBUTE, "openssl.x509_attribute");
  X509_ATTRIBUTE* dup = X509_ATTRIBUTE_dup(attr);
  PUSH_OBJECT(dup, "openssl.x509_attribute");
  return 1;
}

static int openssl_xattr_free(lua_State*L)
{
  X509_ATTRIBUTE* attr = CHECK_OBJECT(1, X509_ATTRIBUTE, "openssl.x509_attribute");

#if OPENSSL_VERSION_NUMBER < 0x10100000L
  sk_ASN1_TYPE_pop_free(attr->value.set, ASN1_TYPE_free);
  attr->value.ptr = NULL;
#endif

  X509_ATTRIBUTE_free(attr);
  return 0;
}

/***
get type of x509_attribute

@function data
@tparam integer idx location want to get type
@tparam string attrtype attribute type
@treturn asn1_string
*/
/***
set type of x509_attribute

@function data
@tparam string attrtype attribute type
@tparam string data set to asn1_attr
@treturn boolean result true for success and others for fail
*/
static int openssl_xattr_data(lua_State*L)
{
  X509_ATTRIBUTE* attr = CHECK_OBJECT(1, X509_ATTRIBUTE, "openssl.x509_attribute");
  if (lua_type(L, 3) == LUA_TSTRING)
  {
    int attrtype = luaL_checkint(L, 2);
    size_t size;
    int ret;
    const char *data = luaL_checklstring(L, 3, &size);
#if OPENSSL_VERSION_NUMBER < 0x10100000L
    sk_ASN1_TYPE_pop_free(attr->value.set, ASN1_TYPE_free);
    attr->value.ptr = NULL;
#endif
    ret = X509_ATTRIBUTE_set1_data(attr, attrtype, data, size);
    return openssl_pushresult(L, ret);
  }
  else
  {
    int idx = luaL_checkint(L, 2);
    int attrtype = luaL_checkint(L, 3);
    ASN1_STRING *as = (ASN1_STRING *)X509_ATTRIBUTE_get0_data(attr, idx, attrtype, NULL);
    PUSH_ASN1_STRING(L, as);
    return 1;
  }
}

/***
get type of x509_attribute.

@function type
@tparam[opt] integer location which location to get type, default is 0
@treturn table asn1_type, asn1_type as table info
@treturn nil nil, fail return nothing
@see asn1_type_table
*/
static int openssl_xattr_type(lua_State*L)
{
  X509_ATTRIBUTE* attr = CHECK_OBJECT(1, X509_ATTRIBUTE, "openssl.x509_attribute");
  int loc = luaL_optint(L, 2, 0);
  ASN1_TYPE *type = X509_ATTRIBUTE_get0_type(attr, loc);
  if (type)
  {
    openssl_push_asn1type(L, type);
    return 1;
  }
  return 0;
}

/***
get asn1_object of x509_attribute.

@function object
@treturn asn1_object object of x509_attribute
*/
/***
set asn1_object for x509_attribute.

@function object
@tparam asn1_object obj
@treturn boolean true for success
@return nil when occure error, and followed by error message
*/
static int openssl_xattr_object(lua_State*L)
{
  X509_ATTRIBUTE* attr = CHECK_OBJECT(1, X509_ATTRIBUTE, "openssl.x509_attribute");
  if (lua_isnone(L, 2))
  {
    ASN1_OBJECT* obj = X509_ATTRIBUTE_get0_object(attr);
    openssl_push_asn1object(L, obj);
    return 1;
  }
  else
  {
    ASN1_OBJECT *obj = openssl_get_asn1object(L, 2, 0);
    int ret = X509_ATTRIBUTE_set1_object(attr, obj);
    ASN1_OBJECT_free(obj);
    return openssl_pushresult(L, ret);
  }
}

static luaL_Reg x509_attribute_funs[] =
{
  {"info",          openssl_xattr_info},
  {"dup",           openssl_xattr_dup},
  /* set or get */
  {"data",          openssl_xattr_data},
  {"type",          openssl_xattr_type},
  {"object",        openssl_xattr_object},

  {"__gc",          openssl_xattr_free},
  {"__tostring",    auxiliar_tostring},

  { NULL, NULL }
};

X509_ATTRIBUTE* openssl_new_xattribute(lua_State*L, X509_ATTRIBUTE** a, int idx)
{
  int arttype;
  size_t len = 0;
  const char* data = NULL;
  ASN1_STRING *s = NULL;
  ASN1_OBJECT *obj = NULL;

  lua_getfield(L, idx, "object");
  obj  = openssl_get_asn1object(L, -1, 1);
  lua_pop(L, 1);

  lua_getfield(L, idx, "type");
  arttype = luaL_checkint(L, -1);
  lua_pop(L, 1);

  lua_getfield(L, idx, "value");
  if (lua_isstring(L, -1))
  {
    data = lua_tolstring(L, -1, &len);
  }
  else if ((s = GET_GROUP(-1, ASN1_STRING, "openssl.asn1group")) != NULL)
  {
    data = (const char *)ASN1_STRING_get0_data(s);
    len  = ASN1_STRING_length(s);
  }
  lua_pop(L, 1);
  if (data)
    return X509_ATTRIBUTE_create_by_OBJ(a, obj, arttype, data, len);
  ASN1_OBJECT_free(obj);

  return 0;
}


IMP_LUA_SK(X509_ATTRIBUTE, x509_attribute)

int openssl_register_xattribute(lua_State*L)
{
  auxiliar_newclass(L, "openssl.x509_attribute", x509_attribute_funs);
  lua_newtable(L);
  luaL_setfuncs(L, R, 0);
  return 1;
}
