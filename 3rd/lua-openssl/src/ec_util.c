#include "openssl.h"

int openssl_to_group_asn1_flag(lua_State *L, int i, const char *defval)
{
  const char *const flag[] = {"explicit", "named_curve", NULL};
  int f = luaL_checkoption(L, i, defval, flag);
  int form = 0;

  if (f == 0)
    form = 0;
  else if (f == 1)
    form = OPENSSL_EC_NAMED_CURVE;
  else
    luaL_argerror(L, i, "invalid parameter, only accept 'explicit' or 'named_curve'");

  return form;
}

int openssl_push_group_asn1_flag(lua_State *L, int flag)
{
  if (flag == 0)
    lua_pushstring(L, "explicit");
  else if (flag == 1)
    lua_pushstring(L, "named_curve");
  else
    lua_pushnil(L);

  return 1;
}

point_conversion_form_t openssl_to_point_conversion_form(lua_State *L, int i, const char *defval)
{
  const char *options[] = {"compressed", "uncompressed", "hybrid", NULL};
  int f = luaL_checkoption(L, i, defval, options);
  point_conversion_form_t form = 0;

  if (f == 0)
    form = POINT_CONVERSION_COMPRESSED;
  else if (f == 1)
    form = POINT_CONVERSION_UNCOMPRESSED;
  else if (f == 2)
    form = POINT_CONVERSION_HYBRID;
  else
    luaL_argerror(L, i, "invalid parameter, only support 'compressed', 'uncompressed' or 'hybrid'");

  return form;
}

int openssl_push_point_conversion_form(lua_State *L, point_conversion_form_t form)
{
  if (form == POINT_CONVERSION_COMPRESSED)
    lua_pushstring(L, "compressed");
  else if (form == POINT_CONVERSION_UNCOMPRESSED)
    lua_pushstring(L, "uncompressed");
  else if (form == POINT_CONVERSION_HYBRID)
    lua_pushstring(L, "hybrid");
  else
    lua_pushnil(L);

  return 1;
}

EC_GROUP *
openssl_get_ec_group(lua_State *L, int ec_name_idx, int conv_form_idx, int asn1_flags_idx)
{
  int       nid = NID_undef;
  EC_GROUP *g = NULL;

  /* ec_name can be number|string|evp_pkey|ec_key */
  if (lua_isnumber(L, ec_name_idx))
    nid = lua_tointeger(L, ec_name_idx);
  else if (lua_isstring(L, ec_name_idx)) {
    const char *name = luaL_checkstring(L, ec_name_idx);
    nid = OBJ_txt2nid(name);
  } else if (lua_isuserdata(L, ec_name_idx)) {
    if (auxiliar_getclassudata(L, "openssl.evp_pkey", ec_name_idx)) {
      EVP_PKEY *pkey = CHECK_OBJECT(1, EVP_PKEY, "openssl.evp_pkey");
      EC_KEY   *ec_key = EVP_PKEY_get1_EC_KEY(pkey);
      if (ec_key) {
        g = (EC_GROUP *)EC_KEY_get0_group(ec_key);
        EC_KEY_free(ec_key);
      }
    } else if (auxiliar_getclassudata(L, "openssl.ec_key", ec_name_idx)) {
      EC_KEY *ec_key = CHECK_OBJECT(1, EC_KEY, "openssl.ec_key");
      g = (EC_GROUP *)EC_KEY_get0_group(ec_key);
    }
    if (g) g = EC_GROUP_dup(g);
  }

  if (g == NULL && nid != NID_undef) g = EC_GROUP_new_by_curve_name(nid);

  if (g) {
    /* conv_form can be number|string|nil */
    if (conv_form_idx) {
      int form = 0;
      int type = lua_type(L, conv_form_idx);
      if (type == LUA_TSTRING) {
        form = openssl_to_point_conversion_form(L, conv_form_idx, NULL);
        EC_GROUP_set_point_conversion_form(g, form);
      } else if (type == LUA_TNUMBER) {
        form = luaL_checkint(L, conv_form_idx);
        EC_GROUP_set_point_conversion_form(g, form);
      } else if (lua_isnoneornil(L, conv_form_idx)) {
        EC_GROUP_set_point_conversion_form(g, POINT_CONVERSION_UNCOMPRESSED);
      } else
        luaL_argerror(L, conv_form_idx, "not accept type of point_conversion_form");
    } else
      EC_GROUP_set_point_conversion_form(g, POINT_CONVERSION_UNCOMPRESSED);

    /* asn1_flags can be number|string|nil */
    if (asn1_flags_idx) {
      int asn1_flag = 0;
      int type = lua_type(L, asn1_flags_idx);
      if (type == LUA_TSTRING) {
        asn1_flag = openssl_to_group_asn1_flag(L, asn1_flags_idx, NULL);
        EC_GROUP_set_asn1_flag(g, asn1_flag);
      } else if (type == LUA_TNUMBER) {
        asn1_flag = luaL_checkint(L, asn1_flags_idx);
        EC_GROUP_set_asn1_flag(g, asn1_flag);
      } else if (lua_isnoneornil(L, asn1_flags_idx)) {
        EC_GROUP_set_asn1_flag(g, OPENSSL_EC_NAMED_CURVE);
      } else
        luaL_argerror(L, asn1_flags_idx, "not accept type of asn1 flag");
    } else
      EC_GROUP_set_asn1_flag(g, OPENSSL_EC_NAMED_CURVE);
  }

  return g;
}

