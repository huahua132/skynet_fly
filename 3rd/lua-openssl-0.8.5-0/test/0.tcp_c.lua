local openssl = require 'openssl'
local bio = openssl.bio
local host, port, loop
local arg = assert(arg)

host = arg[1] or "127.0.0.1"; -- only ip
port = arg[2] or "8383";
loop = arg[3] and tonumber(arg[3]) or 100
print(string.format('CONNECT to %s:%s', host, port))

local function mk_connection(_host, _port)
  local cli = assert(bio.connect(_host .. ':' .. _port, true))
  if (cli) then
    local s = 'aaa'
    io.write('.')
    for _ = 1, 100 do
      assert(cli:write(s))
      assert(cli:flush())
      assert(cli:read())
    end
    cli:shutdown()
    cli:close()
    collectgarbage()
  end
end

for _ = 1, loop do mk_connection(host, port) end
print(openssl.errors())
