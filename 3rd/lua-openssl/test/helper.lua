local openssl = require("openssl")
local ca = require("utils.ca")

local M = {}

M.luaopensslv, M.luav, M.opensslv = openssl.version()
M._luaopensslv, M._luav, M._opensslv = openssl.version(true)
M.libressl = M.opensslv:find("^LibreSSL")
M.openssl3 = M.opensslv:find("^OpenSSL 3")

function M.sslProtocol(srv, protocol)
  protocol = protocol or openssl.ssl.default
  if M.opensslv:match('1.0.2') then
    protocol = protocol:gsub('DTLS', 'DTLSv1_2')
  end
  if srv == true then
    return protocol .. "_server"
  elseif srv == false then
    return protocol .. "_client"
  elseif srv == nil then
    return protocol
  end
  assert(nil)
end

function M.supportTLSv1_3()
  return M._opensslv > 0x10100000
end

function M.get_ca()
  if not M.ca then
    M.ca = ca:new()
  end
  return M.ca
end

function M.new_req(subject, exts, attrs)
  local pkey = openssl.pkey.new()
  if type(subject) == "table" then
    subject = openssl.x509.name.new(subject)
  end
  local req = assert(openssl.x509.req.new(subject))
  if (exts) then
    req:extensions(exts)
  end
  if (attrs) then
    req:attributes(attrs)
  end
  assert(req:sign(pkey))
  return req, pkey
end

function M.sign(subject, extensions)
  local CA = M.get_ca()
  if not type(subject):match("x509.req") then
    local req, pkey = M.new_req(subject)
    local cert = CA:sign(req, extensions)
    return cert, pkey
  end
  return CA:sign(subject, extensions)
end

function M.spawn(cmd, args, pattern, after_start, after_close, env)
  local uv = require("luv")
  env = env or {}
  if os.getenv('ASAN_LIB') then
    env[#env+1] = 'DYLD_INSERT_LIBRARIES=' .. os.getenv('ASAN_LIB')
  end
  env[#env+1] = 'LUA_CPATH=' .. package.cpath
  env[#env+1] = 'LUA_PATH=' .. package.path

  local function stderr_read(err, chunk)
    assert(not err, err)
    if (chunk) then
      io.write(chunk)
      io.flush()
    end
  end

  local resutls = ''
  local function stdout_read(err, chunk)
    assert(not err, err)
    if (chunk) then
      io.write(chunk)
      io.flush()
      resutls = resutls .. chunk
      if pattern and resutls:match(pattern) then
        print('matched.ing')
        if after_start then
          after_start()
        end
        resutls=''
      end
    end
  end

  local stdin = uv.new_pipe(false)
  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)

  local handle, pid
  handle, pid = assert(uv.spawn(
    cmd,
    {
      args = args,
      env = env,
      cwd = uv.cwd(),
      stdio = { stdin, stdout, stderr },
    },
    function(code, signal)
      uv.close(handle)
      if after_close then
        after_close(code, signal)
      end
    end
  ))
  uv.read_start(stdout, stdout_read)
  uv.read_start(stderr, stderr_read)
  return handle, pid
end

return M
