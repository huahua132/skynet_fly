local Router = require "radix-router"
local utils = require "benchmark.utils"

local route_n = os.getenv("RADIX_ROUTER_ROUTES") or 1000 * 100
local times = os.getenv("RADIX_ROUTER_TIMES") or 1000 * 1000

local router
do
  local routes = {}
  for i = 1, route_n do
    routes[i] = { paths = { string.format("/%d", i) }, handler = i }
  end
  router = Router.new(routes)
end

local path = "/" .. route_n / 2

local rss_mb = utils.get_rss()

local elapsed = utils.timing(function()
  for _ = 1, times do
    router:match(path)
  end
end)

utils.print_result({
  title = "static path",
  routes = route_n,
  times = times,
  elapsed = elapsed,
  benchmark_path = path,
  benchmark_handler = router:match(path),
  rss = rss_mb,
})
