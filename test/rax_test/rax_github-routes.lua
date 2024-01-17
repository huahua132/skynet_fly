local rax = require "rax"
local utils = require "benchmark.utils"


local times = os.getenv("RADIX_ROUTER_TIMES") or 1000 * 10

local function revert_path(path)
    path = string.gsub(path, "{([^{}]*)}", ":%1")
    path = string.gsub(path, "{%*(%w*)}", "*%1")
    return path
end

local router
local i = 0
do
  local file, err = io.open("benchmark/github-apis.txt", "r")
  if err then
    error(err)
  end
  local routes = {}
  router = rax:new()
  for line in file:lines() do
    i = i + 1
    router:insert("GET", revert_path(line), line)
  end
  file:close()
  router:compile()
end

local rss_mb = utils.get_rss()

local path = "/repos/vm-001/lua-radix-router/import"

local elapsed = utils.timing(function()
  for _ = 1, times do
    router:match(path, "GET")
  end
end)

utils.print_result({
  title = "rax github apis",
  routes = i,
  times = times,
  elapsed = elapsed,
  benchmark_path = path,
  benchmark_handler = router:match(path),
  rss = rss_mb,
})
