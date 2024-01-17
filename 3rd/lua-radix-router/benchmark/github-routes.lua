local Router = require "radix-router"
local utils = require "benchmark.utils"


local times = os.getenv("RADIX_ROUTER_TIMES") or 1000 * 100

local router
local i = 0
do
  local file, err = io.open("benchmark/github-apis.txt", "r")
  if err then
    error(err)
  end
  local routes = {}
  for line in file:lines() do
    i = i + 1
    routes[i] = { paths = { line }, handler = line }
  end
  file:close()
  router = Router.new(routes)
end

local rss_mb = utils.get_rss()

local path = "/repos/vm-001/lua-radix-router/import"

local elapsed = utils.timing(function()
  for _ = 1, times do
    router:match(path)
  end
end)

utils.print_result({
  title = "github apis",
  routes = i,
  times = times,
  elapsed = elapsed,
  benchmark_path = path,
  benchmark_handler = router:match(path),
  rss = rss_mb,
})
