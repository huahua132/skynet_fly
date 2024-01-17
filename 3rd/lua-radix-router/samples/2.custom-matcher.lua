local Router = require "radix-router"

local ip_matcher = {
  process = function(route)
    -- builds a table for O(1) access
    if route.ips then
      local ips = {}
      for _, ip in ipairs(route.ips) do
        ips[ip] = true
      end
      route.ips = ips
    end
  end,
  match = function(route, ctx, matched)
    if route.ips then
      local ip = ctx.ip
      if not route.ips[ip] then
        return false
      end
      if matched then
        matched["ip"] = ip
      end
    end
    return true
  end
}

local opts = {
  matchers = { ip_matcher }, -- register custom ip_matcher
  matcher_names = { "method" }, -- host is disabled
}

local router = Router.new({
  {
    paths = { "/" },
    methods = { "GET", "POST" },
    ips = { "127.0.0.1", "127.0.0.2" },
    handler = "1",
  },
  {
    paths = { "/" },
    methods = { "GET", "POST" },
    ips = { "192.168.1.1", "192.168.1.2" },
    handler = "2",
  }
}, opts)
assert("1" == router:match("/", { method = "GET", ip = "127.0.0.2" }))
local matched = {}
assert("2" == router:match("/", { method = "GET", ip = "192.168.1.2" }, nil, matched))
print(matched.method) -- GET
print(matched.ip) -- 192.168.1.2
