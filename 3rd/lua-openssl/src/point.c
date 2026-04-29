/***
EC_POINT module for Lua OpenSSL binding.

This module provides a complete wrapper for OpenSSL's EC_POINT operations,
enabling elliptic curve point mathematical operations.

@module ec.point
@usage
  point = require('openssl').ec.point
*/

/* This file is included in ec.c */

#define MYTYPE_POINT "openssl.ec_point"
#define MYVERSION_POINT MYTYPE_POINT " library for " LUA_VERSION " / Nov 2024"

/***
Create a new EC point on a given group.

@function new
@tparam openssl.ec_group group the EC group
@treturn openssl.ec_point new elliptic curve point (at infinity)
@usage
  group = require('openssl').group
  point = require('openssl').point
  g = group.new('prime256v1')
  p = point.new(g)
*/

/***
Copy one EC point to another.

@function copy
@tparam openssl.ec_point dest destination point
@tparam openssl.ec_point src source point
@treturn openssl.ec_point destination point (self)
*/
int openssl_point_copy(lua_State *L)
{
  EC_POINT *dest = CHECK_OBJECT(1, EC_POINT, MYTYPE_POINT);
  const EC_POINT *src = CHECK_OBJECT(2, EC_POINT, MYTYPE_POINT);

  if (EC_POINT_copy(dest, src)) {
    lua_pushvalue(L, 1);
    return 1;
  }

  return 0;
}

int openssl_point_free(lua_State *L)
{
  EC_POINT *point = CHECK_OBJECT(1, EC_POINT, MYTYPE_POINT);
  EC_POINT_free(point);
  return 0;
}

/***
Convert EC point to string (internal, called by __tostring).

@function tostring
@treturn string string representation
*/
static int openssl_point_tostring(lua_State *L)
{
  lua_pushfstring(L, "openssl.ec_point: %p", lua_touserdata(L, 1));
  return 1;
}

/* Method table */
static luaL_Reg point_methods[] = {
  /* Object methods */
  {"copy",                 openssl_point_copy},

  /* Metamethods */
  {"__gc",                 openssl_point_free},
  {"__tostring",           auxiliar_tostring},

  {NULL,                   NULL}
};

/* Module functions */
static luaL_Reg point_functions[] = {
  {"new",                  openssl_group_point_new},
  {"dup",                  openssl_group_point_dup},
  {"equal",                openssl_group_point_equal},
  {"add",                  openssl_point_add},
  {"dbl",                  openssl_point_dbl},
  {"invert",               openssl_point_invert},
  {"mul",                  openssl_point_mul},

  {"is_at_infinity",       openssl_point_is_at_infinity},
  {"is_on_curve",          openssl_point_is_on_curve},

  {"point2oct",            openssl_group_point2oct},
  {"oct2point",            openssl_group_oct2point},
  {"point2bn",             openssl_group_point2bn},
  {"bn2point",             openssl_group_bn2point},
  {"point2hex",            openssl_group_point2hex},
  {"hex2point",            openssl_group_hex2point},

  {"affine_coordinates",   openssl_group_affine_coordinates},
  {"set_to_infinity",      openssl_point_set_to_infinity},

  {NULL,                   NULL}
};

int
luaopen_ec_point(lua_State *L) {
  auxiliar_newclass(L, MYTYPE_POINT, point_methods);
  lua_newtable(L);
  luaL_setfuncs(L, point_functions, 0);
  return 1;
}

