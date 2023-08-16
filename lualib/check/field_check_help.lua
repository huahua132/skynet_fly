local log = require "logger"
local type = type
local pairs = pairs
local ipairs = ipairs
local pcall = pcall
local next = next
local assert = assert
local table_clone = table.copy
-------------------------------------
--[[
  描述 字段
  _isreset 是否重置值，重启就会覆盖key的值为default
  _pack     打包value
  _unpack   解包value
  _begin_func 字段校验函数
  _repeat_field 表内容重复字段描述
  _map_field 不重复内容字段描述
  _end_func 尾调用
  _keep_update 保持更新  不受其他配置出错影响更新
]]
-------------------------------------
local M = {}

function M.check_args(value, check_des, base_map, args_name)
  if type(value) == "nil" then
    log.fatal("check_args err is a nil value", args_name)
    return false
  end
  if check_des._unpack then
    local ok,ret = pcall(check_des._unpack,value)
    if not ok then
      log.fatal("check_args unpack err ",value,args_name)
      return false
    else
      value = ret
    end
  end

  local _begin_func = check_des._begin_func
  if not _begin_func then
    log.fatal("check_args not _begin_func ", args_name, check_des)
    return false
  end
  if not _begin_func(value) then
    log.fatal("check_args _begin_func err ", value, args_name)
    return false
  end

  local check_ret_map = true
  if type(value) == 'table' then
    check_ret_map = {}
    if not check_des._repeat_field and not check_des._map_field then
      log.fatal("check_args not _check_field ", args_name)
      return false
    end
    if check_des._repeat_field then
      for k, v in pairs(value) do
        local is_ok,tmp_check_ret_map = M.check_args(v, check_des._repeat_field, value, args_name .. ':' .. k)
        if is_ok then
          check_ret_map[k] = tmp_check_ret_map
        else
          check_ret_map[k] = false
        end
      end
    else
      for k,v in pairs(check_des._map_field) do
        local is_ok,tmp_check_ret_map = M.check_args(value[k], check_des._map_field[k], value, args_name .. ':' .. k)
        if is_ok then
          check_ret_map[k] = tmp_check_ret_map
        else
          check_ret_map[k] = false
        end
      end
    end
  end

  if check_des._end_func then
    if not check_des._end_func(value, base_map) then
      log.error("check_args _end_func err", value, args_name)
      return false
    end
  end
  return true,check_ret_map
end

function M.decode_args(value, check_des)
  if not check_des then return value end

  if check_des._unpack then
    value = check_des._unpack(value)
  end

  if type(value) == 'table' then
    if check_des._repeat_field then
      for i, v in pairs(value) do
        value[i] = M.decode_args(v,check_des._repeat_field)
      end
    else
      for k,v in pairs(value) do
        if check_des._map_field[k] then
          value[k] = M.decode_args(v,check_des._map_field[k])
        else
          value[k] = nil
        end
      end
    end
  end
  return value
end

function M.update_args(old_t,new_t,check_ret_map,check_des)
  local is_update = false

  local is_have_fail = false
  for _,ret in pairs(check_ret_map) do
    if not ret then
      is_have_fail = true
    end
  end

  for k,v in pairs(new_t) do
    local check_field = check_des._repeat_field
    if not check_field then
      check_field = check_des._map_field[k]
    end
    if type(v) == 'table' then
      if type(old_t[k]) == 'nil' then
        old_t[k] = {}
      end
      if (M.update_args(old_t[k],v,check_ret_map[k],check_field)) then
        is_update = true
      end
    else
      if (type(old_t[k]) == 'nil' or old_t[k] ~= v) and check_ret_map[k] and (not is_have_fail or check_field._keep_update) then
        is_update = true
        old_t[k] = v
      end
    end
  end
  return is_update
end

function M.init_args(cfg_info,default,old_t,des)
  des = des or ""
  local marge_field = {}
  local k_map = {}
  for k,_ in pairs(default) do
    k_map[k] = true
  end

  if old_t then
    for k,_ in pairs(old_t) do
      k_map[k] = true
    end
  end

  for k,_ in pairs(k_map) do
    local v = default[k]
    local v_info = nil
    local pack = nil
    local unpack = nil
    local isreset = nil

    if cfg_info._repeat_field then
      v_info = cfg_info._repeat_field
    elseif cfg_info._map_field then
      v_info = cfg_info._map_field[k]
    end

    if v_info then
      pack = v_info._pack
      unpack = v_info._unpack
      isreset = v_info._isreset
    end

    if cfg_info._repeat_field and old_t and not old_t[k] then
      --数据key已经存在，但是下标数据已经不存在，这时候不应该用初始化去新增它，不符合预期。
    elseif type(v) ~= 'table' then
      if not old_t or not old_t[k] or isreset then
        marge_field[k] = pack and pack(v) or v
      else
        marge_field[k] = old_t[k]
      end
    else
      assert(v_info,"init not v_info " .. des .. '-' .. k)
      local v_o_t = old_t and old_t[k] or nil
      local ok
      if v_o_t and unpack then
        ok,v_o_t = pcall(unpack,v_o_t)
        assert(ok,"unpack old_value err " .. des .. '-' .. k)
      end
      if pack then
        marge_field[k] = pack(M.init_args(v_info,v,v_o_t,des .. '-' .. k))
        assert(marge_field[k],"pack marge_field err nil ".. des .. '-' .. k)
      else
        marge_field[k] = M.init_args(v_info,v,v_o_t,des .. '-' .. k)
      end
    end
  end

  return marge_field
end

return M
