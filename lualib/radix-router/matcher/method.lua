--- MethodMatcher

local utils = require "radix-router.utils"
local bit = utils.is_luajit and require "bit"

local is_luajit = utils.is_luajit
local METHODS = {}
do
  local methods = { "GET", "HEAD", "POST", "PUT", "DELETE", "CONNECT", "OPTIONS", "TRACE", "PATCH" }
  for i, method in ipairs(methods) do
    if is_luajit then
      METHODS[method] = bit.lshift(1, i - 1)
    else
      METHODS[method] = true
    end
  end
end


local _M = {}


function _M.process(route)
  if route.methods then
    local methods_bit = 0
    local methods = {}
    for _, method in ipairs(route.methods) do
      if not METHODS[method] then
        return "invalid methond"
      end
      if is_luajit then
        methods_bit = bit.bor(methods_bit, METHODS[method])
      else
        methods[method] = true
      end
    end
    route.method = is_luajit and methods_bit or methods
  end
end


function _M.match(route, ctx, matched)
  if route.method then
    local method = ctx.method
    if not method or METHODS[method] == nil then
      return false
    end
    if is_luajit then
      if bit.band(route.method, METHODS[method]) == 0 then
        return false
      end
    else
      if not route.method[method] then
        return false
      end
    end

    if matched then
      matched.method = method
    end
  end

  return true
end


return _M