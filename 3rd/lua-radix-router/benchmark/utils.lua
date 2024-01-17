local fmt = string.format

local function timing(fn)
  local start_time = os.clock()
  fn()
  return os.clock() - start_time
end

local log = require "log"
local print = log.info

local function print_result(result, items)
  print(fmt("========== %s ==========", result.title))
  print("routes  :", result.routes)
  print("times   :", result.times)
  print("elapsed :", result.elapsed .. " s")
  print("QPS     :", math.floor(result.times / result.elapsed))
  print("ns/op   :", result.elapsed * 1000 * 1000 / result.times .. " ns")
  print("path    :", result.benchmark_path)
  print("handler :", result.benchmark_handler)
  for _, item in ipairs(items or {}) do
    print(fmt("%s : %s", item.name, item.value))
  end
  print("Memory  :", result.rss)
  print()
end

local function get_pid()
  -- local ok, ffi = pcall(require, "ffi")
  -- if ok then
  --   ffi.cdef [[
  --     int getpid(void);
  --   ]]
  --   return ffi.C.getpid()
  -- end
  -- return nil
  local file = io.open('skynet.pid','r')
  if not file then
    return nil
  end

  local str = file:read("*a")
  return tonumber(str)
end

local function get_rss()
  collectgarbage("collect")

  local pid = get_pid()
  if not pid then
    return "unable to get the pid"
  end

  local command = "ps -o rss= -p " .. tostring(pid)
  local handle = io.popen(command)
  local result = handle:read("*a")
  handle:close()
  local kbytes = tonumber(result) or 0
  return fmt("%.2f MB", kbytes / 1024)
end

return {
  timing = timing,
  print_result = print_result,
  get_rss = get_rss,
}
