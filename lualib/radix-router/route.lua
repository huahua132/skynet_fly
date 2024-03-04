--- Route a route defines the matching conditions of its handler.
--
--

local ipairs = ipairs
local str_byte = string.byte
local BYTE_SLASH = str_byte("/")

local Route = {}
local mt = { __index = Route }


function Route.new(route, _)
  if route.handler == nil then
    return nil, "handler must not be nil"
  end

  for _, path in ipairs(route.paths) do
    if str_byte(path) ~= BYTE_SLASH then
      return nil, "path must start with /"
    end
  end

  return setmetatable(route, mt)
end


function Route:compare(other)
  return (self.priority or 0) > (other.priority or 0)
end


return Route
