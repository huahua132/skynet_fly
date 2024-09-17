local uv = require("luv")
local helper = require("helper")
local ssl = require("luv.ssl")

-----------------------------------------------
---[[
local count = 0

local function setInterval(fn, ms)
  local handle = uv.new_timer()
  uv.timer_start(handle, ms, ms, fn)
  return handle
end

--]]
--------------------------------------------------------------
host = arg[1] or "127.0.0.1" --only ip
port = arg[2] or "8383"

local address = {
  port = tonumber(port),
  address = host,
}

local ctx = ssl.new_ctx({
  protocol = helper.sslProtocol(true),
  key = "certs/agent1-key.pem",
  certificate = "certs/agent1-cert.pem",
  cafile = "certs/agent1-ca.pem",
  verify = ssl.none,
  --   options = {"all", "no_sslv2"}
})

function create_server(host, port, on_connection)
  local server = uv.new_tcp()
  uv.tcp_bind(server, host, port)
  uv.listen(server, 64, function(self)
    local client = uv.new_tcp()
    uv.accept(server, client)
    on_connection(client)
  end)
  return server
end

local p = print
local server
server = create_server(address.address, address.port, function(client)
  local scli = ssl.new_ssl(ctx, client, true)
  scli:handshake(function(scli)
    count = count + 1
  end)

  function scli:ondata(chunk)
    self:close()
  end
  function scli:onerror(err)
    print("onerr", err, ssl.error())
  end

  function scli:onend()
    uv.shutdown(client, function()
      uv.close(client)
    end)
  end
end)

local address = uv.tcp_getsockname(server)
p("server", server, address)

local timer, limit = nil, 0
timer=setInterval(function()
  print(os.date(), count)
  collectgarbage()
  if limit > 5 then
    timer:close()
    server:close()
  end
  limit = limit+1
end, 1000)

uv.run("default")

print("done")
