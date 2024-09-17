local openssl = require 'openssl'
local bio = openssl.bio
local host, port, loop
local arg = assert(arg)

host = arg[1] or "127.0.0.1"; -- only ip
port = arg[2] or "8383";
loop = arg[3] and tonumber(arg[3]) or 100

print(string.format('Listen at %s:%s', host, port))
local i = 0;
local srv = assert(bio.accept(host .. ':' .. port))
if srv then
  -- make real listen
  if(srv:accept(true)) then
    print('accepting...')
    io.flush()
    while i < loop do
      local cli = assert(srv:accept())
      repeat
        local s = cli:read()
        if s then
          cli:write(s)
          cli:flush()
        end
      until not s
      cli:close()
      collectgarbage()
      i = i + 1
    end
  else
    print(openssl.errors())
  end
  srv:close()
end
