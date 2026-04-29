local uv = require("luv")
local helper = require("helper")
local ssl = require("luv.ssl")
-----------------------------------------------
local count, concurancy = 0, 0
local ncount = arg[3] and tonumber(arg[3]) or 1000
local step = 100 / 2
local tmp = true

local function setInterval(fn, ms)
  local handle = uv.new_timer()
  uv.timer_start(handle, ms, ms, fn)
  return handle
end

--------------------------------------------------------------
host = arg[1] or "127.0.0.1" --only ip
port = arg[2] or "8383"

local address = {
  port = tonumber(port),
  address = host,
}

local ctx = ssl.new_ctx({
  protocol = helper.sslProtocol(false),
  verify = ssl.none,
  --   options = {"all", "no_sslv2"}
})

local new_connection

function new_connection(i)
  local scli = ssl.connect(address.address, address.port, ctx, function(self)
    count = count + 1
    concurancy = concurancy + 1
    self:write("GET / HTTP/1.0\r\n\r\n")
    if tmp then
      self:close()
    end

    if concurancy <= ncount then
      new_connection(i)
    end
  end)

  function scli:ondata(chunk)
  end

  function scli:onerror(err)
    print("onerror", err)
  end

  function scli:onend()
    self:close()
  end
  function scli:onclose()
    count = count - 1
  end
  return scli
end

tmp = true
local conns = {}

for i = 1, step do
  new_connection(i)
end

local timer
timer = setInterval(function()
  print(os.date(), count, concurancy)
  print(ssl.error())
  collectgarbage()
  if (concurancy >= ncount) then
    timer:close()
  end
end, 1000)

uv.run("default")

print("done")
