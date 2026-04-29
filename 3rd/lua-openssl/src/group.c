/***
EC_GROUP module for Lua OpenSSL binding.

This module provides a complete wrapper for OpenSSL's EC_GROUP operations,
enabling elliptic curve group mathematical operations similar to BIGNUM.

@module ec.group
@usage
  group = require('openssl').ec.group
*/

/* This file is included in ec.c */

#define MYTYPE_GROUP "openssl.ec_group"
#define MYTYPE_POINT "openssl.ec_point"
#define MYVERSION_GROUP MYTYPE_GROUP " library for " LUA_VERSION " / Nov 2024"

/***
Create EC group and generator point from curve specification

@function new
@tparam string|table|number curve curve specification (name, parameters, or NID)
@tparam[opt] string|number form point_conversion_form
@tparam[opt] string|number flag asn1_flag
@treturn[1] openssl.ec_group the elliptic curve group
@treturn[2] openssl.ec_point the generator point
@treturn[3] nil on error
@treturn[3] string error message
-- @see OpenSSL function: EC_GROUP_new_by_curve_name
-- @see OpenSSL function: EC_GROUP_new_curve_GFp
@usage
  local group = require('openssl').group

  -- Create group from curve name
  local ec_group, generator = group.new('prime256v1')

  -- Create group from NID
  local ec_group2, generator2 = group.new(415)  -- NID for prime256v1

  -- Create group with parameters
  local ec_group3, generator3 = group.new({
    p = '0xFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFF',
    a = '0xFFFFFFFF00000001000000000000000000000000FFFFFFFFFFFFFFFFFFFFFFFC',
    b = '0x5AC635D8AA3A93E7B3EBBD55769886BC651D06B0CC53B0F63BCE3C3E27D2604B',
    order = '0xFFFFFFFF00000000FFFFFFFFFFFFFFFFBCE6FAADA7179E84F3B9CAC2FC632551',
    generator = '046B17D1F2E12C4247F8BCE6E563A440F277037D812DEB33A0F4A13945D898C2964FE342E2FE1A7F9B8EE7EB4A7C0F9E162BCE33576B315ECECBB6406837BF51F5',
    cofactor = 1
  })
*/
static int
openssl_group_new(lua_State *L)
{
  const EC_GROUP *g = openssl_get_ec_group(L, 1, 2, 3);
  if (g) {
    const EC_POINT *p = EC_GROUP_get0_generator(g);
    p = EC_POINT_dup(p, g);
    PUSH_OBJECT(g, "openssl.ec_group");
    PUSH_OBJECT(p, "openssl.ec_point");
    return 2;
  }
  return 0;
};

/***
Duplicate an EC_GROUP.

@function dup
@treturn openssl.ec_group duplicated elliptic curve group
*/
static int openssl_group_dup(lua_State *L)
{
  const EC_GROUP *g = CHECK_OBJECT(1, EC_GROUP, MYTYPE_GROUP);
  EC_GROUP *dup = EC_GROUP_dup(g);

  if (dup) {
    PUSH_OBJECT(dup, MYTYPE_GROUP);
    return 1;
  }

  return 0;
}

/***
Get the generator point of the group.

@function generator
@treturn openssl.ec_point generator point of the curve
*/
static int openssl_group_generator(lua_State *L)
{
  const EC_GROUP *g = CHECK_OBJECT(1, EC_GROUP, MYTYPE_GROUP);
  const EC_POINT *p = EC_GROUP_get0_generator(g);

  if (p) {
    p = EC_POINT_dup(p, g);
    PUSH_OBJECT(p, MYTYPE_POINT);
    return 1;
  }

  return 0;
}

/***
Get the order of the group.

@function order
@treturn openssl.bn order of the group
*/
static int openssl_group_order(lua_State *L)
{
  const EC_GROUP *g = CHECK_OBJECT(1, EC_GROUP, MYTYPE_GROUP);
  BIGNUM *order = BN_new();
  BN_CTX *ctx = BN_CTX_new();

  if (EC_GROUP_get_order(g, order, ctx)) {
    BN_CTX_free(ctx);
    PUSH_OBJECT(order, "openssl.bn");
    return 1;
  }

  BN_CTX_free(ctx);
  BN_free(order);
  return 0;
}

/***
Get the cofactor of the group.

@function cofactor
@treturn openssl.bn cofactor of the group
*/
static int openssl_group_cofactor(lua_State *L)
{
  const EC_GROUP *g = CHECK_OBJECT(1, EC_GROUP, MYTYPE_GROUP);
  BIGNUM *cofactor = BN_new();
  BN_CTX *ctx = BN_CTX_new();

  if (EC_GROUP_get_cofactor(g, cofactor, ctx)) {
    BN_CTX_free(ctx);
    PUSH_OBJECT(cofactor, "openssl.bn");
    return 1;
  }

  BN_CTX_free(ctx);
  BN_free(cofactor);
  return 0;
}

/***
Get the degree of the group (field size in bits).

@function degree
@treturn number degree of the group
*/
static int openssl_group_degree(lua_State *L)
{
  const EC_GROUP *g = CHECK_OBJECT(1, EC_GROUP, MYTYPE_GROUP);
  lua_pushinteger(L, EC_GROUP_get_degree(g));
  return 1;
}

/***
Get the curve name NID.

@function curve_name
@treturn number NID of the curve
*/
static int openssl_group_curve_name(lua_State *L)
{
  const EC_GROUP *g = CHECK_OBJECT(1, EC_GROUP, MYTYPE_GROUP);
  lua_pushinteger(L, EC_GROUP_get_curve_name(g));
  return 1;
}

/***
Get or set the ASN1 flag.

@function asn1_flag
@tparam[opt] string|number flag ASN1 flag ("explicit" or "named_curve")
@treturn string|number current ASN1 flag (when getting)
@treturn openssl.ec_group self (when setting)
*/
static int openssl_group_asn1_flag(lua_State *L)
{
  EC_GROUP *g = CHECK_OBJECT(1, EC_GROUP, MYTYPE_GROUP);
  int asn1_flag;

  if (lua_isnone(L, 2)) {
    /* Get */
    asn1_flag = EC_GROUP_get_asn1_flag(g);
    openssl_push_group_asn1_flag(L, asn1_flag);
    lua_pushinteger(L, asn1_flag);
    return 2;
  } else {
    /* Set */
    if (lua_isnumber(L, 2))
      asn1_flag = luaL_checkint(L, 2);
    else
      asn1_flag = openssl_to_group_asn1_flag(L, 2, NULL);
    EC_GROUP_set_asn1_flag(g, asn1_flag);
    lua_pushvalue(L, 1);
    return 1;
  }
}

/***
Get or set the point conversion form.

@function point_conversion_form
@tparam[opt] string|number form point conversion form ("compressed", "uncompressed", or "hybrid")
@treturn string|number current conversion form (when getting)
@treturn openssl.ec_group self (when setting)
*/
int openssl_group_point_conversion_form(lua_State *L)
{
  EC_GROUP *g = CHECK_OBJECT(1, EC_GROUP, MYTYPE_GROUP);
  point_conversion_form_t form;

  if (lua_isnone(L, 2)) {
    /* Get */
    form = EC_GROUP_get_point_conversion_form(g);
    openssl_push_point_conversion_form(L, form);
    lua_pushinteger(L, form);
    return 2;
  } else {
    /* Set */
    if (lua_isnumber(L, 2))
      form = luaL_checkint(L, 2);
    else
      form = openssl_to_point_conversion_form(L, 2, NULL);
    EC_GROUP_set_point_conversion_form(g, form);
    lua_pushvalue(L, 1);
    return 1;
  }
}

/***
Get curve parameters (p, a, b).

@function curve
@treturn table containing p, a, b as BIGNUM objects
*/
static int openssl_group_curve(lua_State *L)
{
  const EC_GROUP *g = CHECK_OBJECT(1, EC_GROUP, MYTYPE_GROUP);
  BIGNUM *a = BN_new();
  BIGNUM *b = BN_new();
  BIGNUM *p = BN_new();
  BN_CTX *ctx = BN_CTX_new();

  if (EC_GROUP_get_curve(g, p, a, b, ctx)) {
    BN_CTX_free(ctx);
    lua_newtable(L);
    AUXILIAR_SETOBJECT(L, p, "openssl.bn", -1, "p");
    AUXILIAR_SETOBJECT(L, a, "openssl.bn", -1, "a");
    AUXILIAR_SETOBJECT(L, b, "openssl.bn", -1, "b");
    return 1;
  }

  BN_CTX_free(ctx);
  BN_free(a);
  BN_free(b);
  BN_free(p);
  return 0;
}

/***
Get the seed value for the group.

@function seed
@treturn string|nil seed value or nil if not set
*/
static int openssl_group_seed(lua_State *L)
{
  const EC_GROUP *g = CHECK_OBJECT(1, EC_GROUP, MYTYPE_GROUP);
  const unsigned char *seed = EC_GROUP_get0_seed(g);
  size_t seed_len = EC_GROUP_get_seed_len(g);

  if (seed && seed_len > 0) {
    lua_pushlstring(L, (const char *)seed, seed_len);
    return 1;
  }

  lua_pushnil(L);
  return 1;
}

/***
Parse the EC group to extract all parameters.

@function parse
@treturn table containing all group parameters (generator, order, cofactor, degree, curve_name, etc.)
*/
static int openssl_group_parse(lua_State *L)
{
  const EC_GROUP *group = CHECK_OBJECT(1, EC_GROUP, MYTYPE_GROUP);
  const EC_POINT *generator = EC_GROUP_get0_generator(group);
  BN_CTX *ctx = BN_CTX_new();
  BIGNUM *a, *b, *p, *order, *cofactor;

  lua_newtable(L);

  if (generator) {
    generator = EC_POINT_dup(generator, group);
    AUXILIAR_SETOBJECT(L, generator, MYTYPE_POINT, -1, "generator");
  }

  order = BN_new();
  EC_GROUP_get_order(group, order, ctx);
  AUXILIAR_SETOBJECT(L, order, "openssl.bn", -1, "order");

  cofactor = BN_new();
  EC_GROUP_get_cofactor(group, cofactor, ctx);
  AUXILIAR_SETOBJECT(L, cofactor, "openssl.bn", -1, "cofactor");

  openssl_push_group_asn1_flag(L, EC_GROUP_get_asn1_flag(group));
  lua_setfield(L, -2, "asn1_flag");

  AUXILIAR_SET(L, -1, "degree", EC_GROUP_get_degree(group), integer);
  AUXILIAR_SET(L, -1, "curve_name", EC_GROUP_get_curve_name(group), integer);

  openssl_push_point_conversion_form(L, EC_GROUP_get_point_conversion_form(group));
  lua_setfield(L, -2, "conversion_form");

  AUXILIAR_SETLSTR(L, -1, "seed", EC_GROUP_get0_seed(group), EC_GROUP_get_seed_len(group));

  a = BN_new();
  b = BN_new();
  p = BN_new();
  EC_GROUP_get_curve(group, p, a, b, ctx);
  lua_newtable(L);
  {
    AUXILIAR_SETOBJECT(L, p, "openssl.bn", -1, "p");
    AUXILIAR_SETOBJECT(L, a, "openssl.bn", -1, "a");
    AUXILIAR_SETOBJECT(L, b, "openssl.bn", -1, "b");
  }
  lua_setfield(L, -2, "curve");
  BN_CTX_free(ctx);

  return 1;
}

/***
Compare two EC groups for equality.

@function equal
@tparam openssl.ec_group other EC group to compare
@treturn boolean true if equal, false otherwise
*/
int openssl_group_equal(lua_State *L)
{
  const EC_GROUP *a = CHECK_OBJECT(1, EC_GROUP, MYTYPE_GROUP);
  const EC_GROUP *b = CHECK_OBJECT(2, EC_GROUP, MYTYPE_GROUP);

  lua_pushboolean(L, EC_GROUP_cmp(a, b, NULL) == 0);
  return 1;
}

int openssl_group_free(lua_State *L)
{
  EC_GROUP *g = CHECK_OBJECT(1, EC_GROUP, MYTYPE_GROUP);
  EC_GROUP_free(g);
  return 0;
}

static int openssl_group_tostring(lua_State *L)
{
  const EC_GROUP *g = CHECK_OBJECT(1, EC_GROUP, MYTYPE_GROUP);
  int nid = EC_GROUP_get_curve_name(g);
  const char *name = OBJ_nid2sn(nid);

  if (name)
    lua_pushfstring(L, "ec_group: %s (nid=%d)", name, nid);
  else
    lua_pushfstring(L, "ec_group: nid=%d", nid);

  return 1;
}

/* Helper functions */


/***
Create a new EC point on this group.

@function point_new
@treturn openssl.ec_point new elliptic curve point (at infinity)
*/
static int openssl_group_point_new(lua_State *L)
{
  EC_GROUP *group = CHECK_OBJECT(1, EC_GROUP, MYTYPE_GROUP);
  EC_POINT *point = EC_POINT_new(group);

  if (point) {
    PUSH_OBJECT(point, MYTYPE_POINT);
    return 1;
  }

  return 0;
}

/***
Duplicate an EC point on this group.

@function point_dup
@tparam openssl.ec_point point the EC point to duplicate
@treturn openssl.ec_point duplicated EC point
*/
static int openssl_group_point_dup(lua_State *L)
{
  const EC_GROUP *group = CHECK_OBJECT(1, EC_GROUP, MYTYPE_GROUP);
  const EC_POINT *point = CHECK_OBJECT(2, EC_POINT, MYTYPE_POINT);
  EC_POINT *dup = EC_POINT_dup(point, group);

  if (dup) {
    PUSH_OBJECT(dup, MYTYPE_POINT);
    return 1;
  }

  return 0;
}

/***
Compare two EC points for equality.

@function point_equal
@tparam openssl.ec_point a first EC point
@tparam openssl.ec_point b second EC point
@treturn boolean true if equal, false otherwise
*/
int openssl_group_point_equal(lua_State *L)
{
  const EC_GROUP *group = CHECK_OBJECT(1, EC_GROUP, MYTYPE_GROUP);
  const EC_POINT *a = CHECK_OBJECT(2, EC_POINT, MYTYPE_POINT);
  const EC_POINT *b = CHECK_OBJECT(3, EC_POINT, MYTYPE_POINT);
  BN_CTX *ctx = BN_CTX_new();
  int ret = EC_POINT_cmp(group, a, b, ctx);
  BN_CTX_free(ctx);

  lua_pushboolean(L, ret == 0);
  return 1;
}

/***
Convert EC point to octet string.

@function point2oct
@tparam openssl.ec_point point the EC point
@tparam[opt] string form point conversion form ("compressed", "uncompressed", or "hybrid")
@treturn string|nil octet string representation or nil on failure
*/
int openssl_group_point2oct(lua_State *L)
{
  const EC_GROUP *group = CHECK_OBJECT(1, EC_GROUP, MYTYPE_GROUP);
  const EC_POINT *point = CHECK_OBJECT(2, EC_POINT, MYTYPE_POINT);
  point_conversion_form_t form = lua_isnone(L, 3)
                                   ? EC_GROUP_get_point_conversion_form(group)
                                   : openssl_to_point_conversion_form(L, 3, "uncompressed");
  size_t size = EC_POINT_point2oct(group, point, form, NULL, 0, NULL);

  if (size > 0) {
    unsigned char *oct = (unsigned char *)OPENSSL_malloc(size);
    size = EC_POINT_point2oct(group, point, form, oct, size, NULL);
    if (size > 0) {
      lua_pushlstring(L, (const char *)oct, size);
      OPENSSL_free(oct);
      return 1;
    }
    OPENSSL_free(oct);
  }

  lua_pushnil(L);
  return 1;
}

/***
Convert octet string to EC point.

@function oct2point
@tparam string oct octet string representation
@treturn ec_point|nil the resulting EC point or nil on failure
*/
int openssl_group_oct2point(lua_State *L)
{
  const EC_GROUP *group = CHECK_OBJECT(1, EC_GROUP, MYTYPE_GROUP);
  size_t size = 0;
  const unsigned char *oct = (const unsigned char *)luaL_checklstring(L, 2, &size);
  EC_POINT *point = EC_POINT_new(group);

  if (EC_POINT_oct2point(group, point, oct, size, NULL) == 1) {
    PUSH_OBJECT(point, MYTYPE_POINT);
    return 1;
  }

  EC_POINT_free(point);
  lua_pushnil(L);
  return 1;
}

/***
Convert EC point to BIGNUM.

@function point2bn
@tparam openssl.ec_point point the EC point
@tparam[opt] string form point conversion form ("compressed", "uncompressed", or "hybrid")
@treturn bn|nil the resulting BIGNUM or nil on failure
*/
int openssl_group_point2bn(lua_State *L)
{
  const EC_GROUP *group = CHECK_OBJECT(1, EC_GROUP, MYTYPE_GROUP);
  const EC_POINT *point = CHECK_OBJECT(2, EC_POINT, MYTYPE_POINT);
  point_conversion_form_t form = lua_isnone(L, 3)
                                   ? EC_GROUP_get_point_conversion_form(group)
                                   : openssl_to_point_conversion_form(L, 3, "uncompressed");
  BIGNUM *bn = EC_POINT_point2bn(group, point, form, NULL, NULL);

  if (bn) {
    PUSH_OBJECT(bn, "openssl.bn");
    return 1;
  }

  lua_pushnil(L);
  return 1;
}

/***
Convert BIGNUM to EC point.

@function bn2point
@tparam openssl.bn bn the BIGNUM to convert
@treturn ec_point|nil the resulting EC point or nil on failure
*/
int openssl_group_bn2point(lua_State *L)
{
  const EC_GROUP *group = CHECK_OBJECT(1, EC_GROUP, MYTYPE_GROUP);
  const BIGNUM *bn = CHECK_OBJECT(2, BIGNUM, "openssl.bn");
  EC_POINT *point = EC_POINT_bn2point(group, bn, NULL, NULL);

  if (point) {
    PUSH_OBJECT(point, MYTYPE_POINT);
    return 1;
  }

  lua_pushnil(L);
  return 1;
}

/***
Convert EC point to hexadecimal string.

@function point2hex
@tparam openssl.ec_point point the EC point
@tparam[opt] string form point conversion form ("compressed", "uncompressed", or "hybrid")
@treturn string|nil hexadecimal string representation or nil on failure
*/
int openssl_group_point2hex(lua_State *L)
{
  const EC_GROUP *group = CHECK_OBJECT(1, EC_GROUP, MYTYPE_GROUP);
  const EC_POINT *point = CHECK_OBJECT(2, EC_POINT, MYTYPE_POINT);
  point_conversion_form_t form = lua_isnone(L, 3)
                                   ? EC_GROUP_get_point_conversion_form(group)
                                   : openssl_to_point_conversion_form(L, 3, "uncompressed");
  char *hex = EC_POINT_point2hex(group, point, form, NULL);

  if (hex) {
    lua_pushstring(L, hex);
    OPENSSL_free(hex);
    return 1;
  }

  lua_pushnil(L);
  return 1;
}

/***
Convert hexadecimal string to EC point.

@function hex2point
@tparam string hex hexadecimal string representation
@treturn ec_point|nil the resulting EC point or nil on failure
*/
int openssl_group_hex2point(lua_State *L)
{
  const EC_GROUP *group = CHECK_OBJECT(1, EC_GROUP, MYTYPE_GROUP);
  const char *hex = luaL_checkstring(L, 2);
  EC_POINT *point = EC_POINT_hex2point(group, hex, NULL, NULL);

  if (point) {
    PUSH_OBJECT(point, MYTYPE_POINT);
    return 1;
  }

  lua_pushnil(L);
  return 1;
}

/***
Get or set affine coordinates of an EC point.

@function affine_coordinates
@tparam openssl.ec_group group the EC group
@tparam openssl.ec_point point the EC point
@tparam[opt] openssl.bn x x coordinate (for setting)
@tparam[opt] openssl.bn y y coordinate (for setting)
@treturn openssl.bn x coordinate (when getting)
@treturn openssl.bn y coordinate (when getting)
*/
int openssl_group_affine_coordinates(lua_State *L)
{
  EC_GROUP *group = CHECK_OBJECT(1, EC_GROUP, MYTYPE_GROUP);
  EC_POINT *point = CHECK_OBJECT(2, EC_POINT, MYTYPE_POINT);
  int ret = 0;

  if (lua_gettop(L) == 2) {
    /* Get coordinates */
    BIGNUM *x = BN_new();
    BIGNUM *y = BN_new();

    ret = EC_POINT_get_affine_coordinates(group, point, x, y, NULL);
    if (ret == 1) {
      PUSH_BN(x);
      PUSH_BN(y);
      return 2;
    } else {
      BN_free(x);
      BN_free(y);
      return 0;
    }
  } else {
    /* Set coordinates */
    BIGNUM *x = CHECK_OBJECT(3, BIGNUM, "openssl.bn");
    BIGNUM *y = CHECK_OBJECT(4, BIGNUM, "openssl.bn");
    ret = EC_POINT_set_affine_coordinates(group, point, x, y, NULL);
    if (ret == 1) {
      lua_pushvalue(L, 2);
      return 1;
    }
  }

  return openssl_pushresult(L, ret);
}

/***
Set EC point to infinity.

@function set_to_infinity
@tparam openssl.ec_group group the EC group
@treturn openssl.ec_point self
*/
static int openssl_point_set_to_infinity(lua_State *L)
{
  const EC_GROUP *group = CHECK_OBJECT(1, EC_GROUP, MYTYPE_GROUP);
  EC_POINT *point = CHECK_OBJECT(2, EC_POINT, MYTYPE_POINT);

  if (EC_POINT_set_to_infinity(group, point)) {
    lua_pushvalue(L, 2);
    return 1;
  }

  return 0;
}

/***
Check if EC point is at infinity.

@function is_at_infinity
@tparam openssl.ec_group group the EC group
@treturn boolean true if at infinity, false otherwise
*/
static int openssl_point_is_at_infinity(lua_State *L)
{
  const EC_GROUP *group = CHECK_OBJECT(1, EC_GROUP, MYTYPE_GROUP);
  const EC_POINT *point = CHECK_OBJECT(2, EC_POINT, MYTYPE_POINT);

  lua_pushboolean(L, EC_POINT_is_at_infinity(group, point));
  return 1;
}

/***
Check if EC point is on the curve.

@function is_on_curve
@tparam openssl.ec_group group the EC group
@treturn boolean true if on curve, false otherwise
*/
static int openssl_point_is_on_curve(lua_State *L)
{
  const EC_GROUP *group = CHECK_OBJECT(1, EC_GROUP, MYTYPE_GROUP);
  const EC_POINT *point = CHECK_OBJECT(2, EC_POINT, MYTYPE_POINT);
  BN_CTX *ctx = BN_CTX_new();
  int ret = EC_POINT_is_on_curve(group, point, ctx);
  BN_CTX_free(ctx);

  lua_pushboolean(L, ret);
  return 1;
}

/***
Add two EC points.

@function point_add
@tparam openssl.ec_group group the EC group
@tparam openssl.ec_point a first point
@tparam openssl.ec_point b second point
@treturn openssl.ec_point result point (a + b)
*/
static int openssl_point_add(lua_State *L)
{
  const EC_GROUP *group = CHECK_OBJECT(1, EC_GROUP, MYTYPE_GROUP);
  const EC_POINT *a = CHECK_OBJECT(2, EC_POINT, MYTYPE_POINT);
  const EC_POINT *b = CHECK_OBJECT(3, EC_POINT, MYTYPE_POINT);
  EC_POINT *r = EC_POINT_new(group);
  BN_CTX *ctx = BN_CTX_new();

  if (EC_POINT_add(group, r, a, b, ctx)) {
    BN_CTX_free(ctx);
    PUSH_OBJECT(r, MYTYPE_POINT);
    return 1;
  }

  BN_CTX_free(ctx);
  EC_POINT_free(r);
  return 0;
}

/***
Double an EC point.

@function point_dbl
@tparam openssl.ec_group group the EC group
@treturn openssl.ec_point result point (2 * point)
*/
static int openssl_point_dbl(lua_State *L)
{
  const EC_GROUP *group = CHECK_OBJECT(1, EC_GROUP, MYTYPE_GROUP);
  const EC_POINT *point = CHECK_OBJECT(2, EC_POINT, MYTYPE_POINT);
  EC_POINT *r = EC_POINT_new(group);
  BN_CTX *ctx = BN_CTX_new();

  if (EC_POINT_dbl(group, r, point, ctx)) {
    BN_CTX_free(ctx);
    PUSH_OBJECT(r, MYTYPE_POINT);
    return 1;
  }

  BN_CTX_free(ctx);
  EC_POINT_free(r);
  return 0;
}

/***
Invert an EC point.

@function point_invert
@tparam openssl.ec_group group the EC group
@treturn openssl.ec_point self (inverted)
*/
static int openssl_point_invert(lua_State *L)
{
  const EC_GROUP *group = CHECK_OBJECT(1, EC_GROUP, MYTYPE_GROUP);
  EC_POINT *point = CHECK_OBJECT(2, EC_POINT, MYTYPE_POINT);
  BN_CTX *ctx = BN_CTX_new();

  if (EC_POINT_invert(group, point, ctx)) {
    BN_CTX_free(ctx);
    lua_pushvalue(L, 2);
    return 1;
  }

  BN_CTX_free(ctx);
  return 0;
}

/***
Multiply EC point by a scalar.

@function point_mul
@tparam openssl.ec_group group the EC group
@tparam bn|number n scalar multiplier
@tparam[opt] openssl.ec_point q optional point for double scalar multiplication
@tparam[opt] openssl.bn m optional second scalar for double scalar multiplication
@treturn openssl.ec_point result point (n * point) or (n * point + m * q)
*/
static int openssl_point_mul(lua_State *L)
{
  const EC_GROUP *group = CHECK_OBJECT(1, EC_GROUP, MYTYPE_GROUP);
  const EC_POINT *point = CHECK_OBJECT(2, EC_POINT, MYTYPE_POINT);
  BIGNUM *n = NULL;
  const EC_POINT *q = NULL;
  const BIGNUM *m = NULL;
  EC_POINT *r = EC_POINT_new(group);
  BN_CTX *ctx = BN_CTX_new();
  int ret;

  /* Get scalar n */
  if (lua_isnumber(L, 3)) {
    lua_Integer num = lua_tointeger(L, 3);
    n = BN_new();
    if (num < 0) {
      BN_set_word(n, -num);
      BN_set_negative(n, 1);
    } else {
      BN_set_word(n, num);
    }
  } else {
    n = CHECK_OBJECT(3, BIGNUM, "openssl.bn");
  }

  /* Check for double scalar multiplication */
  if (!lua_isnone(L, 4)) {
    q = CHECK_OBJECT(4, EC_POINT, MYTYPE_POINT);
    m = CHECK_OBJECT(5, BIGNUM, "openssl.bn");
    ret = EC_POINT_mul(group, r, NULL, point, n, ctx);
    if (ret) {
      EC_POINT *temp = EC_POINT_new(group);
      ret = EC_POINT_mul(group, temp, NULL, q, m, ctx);
      if (ret) {
        ret = EC_POINT_add(group, r, r, temp, ctx);
      }
      EC_POINT_free(temp);
    }
  } else {
    ret = EC_POINT_mul(group, r, NULL, point, n, ctx);
  }

  if (lua_isnumber(L, 3)) {
    BN_free(n);
  }
  BN_CTX_free(ctx);

  if (ret) {
    PUSH_OBJECT(r, MYTYPE_POINT);
    return 1;
  }

  EC_POINT_free(r);
  return 0;
}

/***
Generate EC key pair from this group.

@function generate_key
@treturn ec_key generated EC key object or nil if failed
*/
int openssl_group_generate_key(lua_State *L)
{
  const EC_GROUP *group = CHECK_OBJECT(1, EC_GROUP, MYTYPE_GROUP);

  EC_KEY *ec = EC_KEY_new();
  if (ec) {
    int ret;
    EC_KEY_set_group(ec, group);
    ret = EC_KEY_generate_key(ec);
    if (ret == 1) {
      PUSH_OBJECT(ec, "openssl.ec_key");
      return 1;
    }
    EC_KEY_free(ec);
    return openssl_pushresult(L, ret);
  }
  return 0;
}

/***
List all available elliptic curve names.

@function list
@treturn table array of curve names and descriptions
*/
static int openssl_group_list(lua_State *L)
{
  size_t i = 0;
  size_t crv_len = EC_get_builtin_curves(NULL, 0);
  EC_builtin_curve *curves = OPENSSL_malloc((int)(sizeof(EC_builtin_curve) * crv_len));

  if (curves == NULL) return 0;

  if (!EC_get_builtin_curves(curves, crv_len)) {
    OPENSSL_free(curves);
    return 0;
  }

  lua_newtable(L);
  for (i = 0; i < crv_len; i++) {
    const char *comment;
    const char *sname;
    comment = curves[i].comment;
    sname = OBJ_nid2sn(curves[i].nid);
    if (comment == NULL) comment = "CURVE DESCRIPTION NOT AVAILABLE";
    if (sname == NULL) sname = "";

    AUXILIAR_SET(L, -1, sname, comment, string);
  }

  OPENSSL_free(curves);
  return 1;
}

/* Method table */
static luaL_Reg group_methods[] = {
  /* Object methods */
  {"dup",                   openssl_group_dup},
  {"generator",             openssl_group_generator},
  {"order",                 openssl_group_order},
  {"cofactor",              openssl_group_cofactor},
  {"degree",                openssl_group_degree},
  {"curve_name",            openssl_group_curve_name},
  {"asn1_flag",             openssl_group_asn1_flag},
  {"point_conversion_form", openssl_group_point_conversion_form},
  {"curve",                 openssl_group_curve},
  {"seed",                  openssl_group_seed},
  {"parse",                 openssl_group_parse},
  {"equal",                 openssl_group_equal},

  /* Point operations on group */
  {"point_new",             openssl_group_point_new},
  {"point_dup",             openssl_group_point_dup},
  {"point_equal",           openssl_group_point_equal},
  {"point_add",             openssl_point_add},
  {"point_dbl",             openssl_point_dbl},
  {"point_invert",          openssl_point_invert},
  {"point_mul",             openssl_point_mul},

  {"is_at_infinity",        openssl_point_is_at_infinity},
  {"is_on_curve",           openssl_point_is_on_curve},

  {"point2oct",             openssl_group_point2oct},
  {"oct2point",             openssl_group_oct2point},
  {"point2bn",              openssl_group_point2bn},
  {"bn2point",              openssl_group_bn2point},
  {"point2hex",             openssl_group_point2hex},
  {"hex2point",             openssl_group_hex2point},

  {"affine_coordinates",    openssl_group_affine_coordinates},
  {"set_to_infinity",       openssl_point_set_to_infinity},

  /* EC Key generation */
  {"generate_key",          openssl_group_generate_key},

  /* Metamethods */
  {"__eq",                  openssl_group_equal},
  {"__gc",                  openssl_group_free},
  {"__tostring",            auxiliar_tostring},

  {NULL,                    NULL}
};

/* Module functions */
static luaL_Reg group_functions[] = {
  {"new",  openssl_group_new},
  {"list", openssl_group_list},

  {NULL,   NULL}
};

int
luaopen_ec_group(lua_State *L) {
  auxiliar_newclass(L, MYTYPE_GROUP, group_methods);

  lua_newtable(L);
  luaL_setfuncs(L, group_functions, 0);
  return 1;
}
