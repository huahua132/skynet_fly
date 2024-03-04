local str_byte = string.byte
local math_min = math.min
local type = type

local is_luajit = type(_G.jit) == "table"

local clear_table
local new_table
do
  local ok
  ok, clear_table = pcall(require, "table.clear")
  if not ok then
    local pairs = pairs
    clear_table = function (tab)
      for k, _ in pairs(tab) do
        tab[k] = nil
      end
    end
  end
  ok, new_table = pcall(require, "table.new")
  if not ok then
    new_table = function(narr , nrec)
      return {}
    end
  end
end


local starts_with
local ends_with
do
  if is_luajit then
    local ffi = require "ffi"
    local C = ffi.C
    ffi.cdef[[
      int memcmp(const void *s1, const void *s2, size_t n);
    ]]
    starts_with = function(str, prefix, strn, prefixn)
      strn = strn or #str
      prefixn = prefixn or #prefix

      if prefixn == 0 then
        return true
      end

      if strn < prefixn then
        return false
      end

      local rc = C.memcmp(str, prefix, prefixn)
      return rc == 0
    end
    ends_with = function(str, suffix, strn, suffixn, suffix_skip)
      strn = strn or #str
      suffix_skip = suffix_skip or 0
      suffixn = (suffixn or #suffix) - suffix_skip

      if suffixn == 0 then
        return true
      end

      if strn < suffixn then
        return false
      end

      local rc = C.memcmp(ffi.cast("char *", str) + strn - suffixn, ffi.cast("char *", suffix) + suffix_skip, suffixn)
      return rc == 0
    end
  else
    local str_sub = string.sub
    starts_with = function(str, prefix, strn, prefixn)
      strn = strn or #str
      prefixn = prefixn or #prefix

      if prefixn == 0 then
        return true
      end

      if strn < prefixn then
        return false
      end

      for i = 1, prefixn do
        if str_byte(str, i) ~= str_byte(prefix, i) then
          return false
        end
      end

      return true
    end
    ends_with = function(str, suffix, strn, suffixn, suffix_skip)
      strn = strn or #str
      suffix_skip = suffix_skip or 0
      suffixn = (suffixn or #suffix) - suffix_skip

      if suffixn == 0 then
        return true
      end

      if strn < suffixn then
        return false
      end

      return str_sub(str, -suffixn) == str_sub(suffix, 1 + suffix_skip)
    end
  end
end


local function lcp(str1, str2)
  if str1 == nil or str2 == nil then
    return 0
  end
  local min_len = math_min(#str1, #str2)
  local n = 0
  for i = 1, min_len do
    if str_byte(str1, i) == str_byte(str2, i) then
      n = n + 1
    else
      break
    end
  end
  return n
end


local function readonly(t)
  return setmetatable(t, {
    __newindex = function() error("attempt to modify a read-only table") end
  })
end


return {
  lcp = lcp,
  starts_with = starts_with,
  ends_with = ends_with,
  clear_table = clear_table,
  new_table = new_table,
  is_luajit = is_luajit,
  readonly = readonly,
}
