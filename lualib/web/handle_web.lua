local skynet       = require "skynet"
local socket       = require "skynet.socket"
local sockethelper = require "http.sockethelper"
local httpd        = require "http.httpd"
local HTTP_STATUS = require "HTTP_STATUS"
local log = require "log"
local error = error
local string = string

local SSLCTX_SERVER = nil
local function gen_interface(protocol, fd)
  if protocol == "http" then
    return {
      init = nil,
      close = nil,
      read = sockethelper.readfunc(fd),
      write = sockethelper.writefunc(fd),
    }
  elseif protocol == "https" then
    local tls = require "http.tlshelper"
    if not SSLCTX_SERVER then
      SSLCTX_SERVER = tls.newctx()
      local certfile = skynet.getenv("certfile") or "./server-cert.pem"
      local keyfile  = skynet.getenv("keyfile") or "./server-key.pem"
      SSLCTX_SERVER:set_cert(certfile, keyfile)
    end
    local tls_ctx = tls.newtls("server", SSLCTX_SERVER)
    return {
      init = tls.init_responsefunc(fd, tls_ctx),
      close = tls.closefunc(tls_ctx),
      read = tls.readfunc(fd, tls_ctx),
      write = tls.writefunc(fd, tls_ctx),
    }
  else
    error(string.format("Invalid protocol: %s", protocol))
  end
end

local function do_response(fd, write, statuscode, bodyfunc, header)
  local ok, retval = httpd.write_response(write, statuscode, bodyfunc, header)
  if not ok then
    error(string.format("httpd.response(%d) : %s", fd, retval))
  end
end

local function do_request(fd, ip,port, protocol, handle)
  socket.start(fd)
  local interface = gen_interface(protocol, fd)
  if interface.init then
      interface.init()
  end
  local is_close = false
  local code, url, method, header, body
  return {
    read_request = function()
      code, url, method, header, body = httpd.read_request(interface.read, 8192)
      return code
    end,

    handle_response = function()
      if code then
        if code ~= HTTP_STATUS.OK then
          do_response(fd, interface.write, code)
        else
          if header.upgrade == "websocket" then
            do_response(fd, interface.write, HTTP_STATUS.Bad_Request)
          else
            local req = {
              fd       = fd,
              protocol = protocol,
              method   = method,
              url      = url,
              header   = header,
              body     = body,
              ip       = ip,
              port     = port,
            }
            local code,bodyfunc,rspheader = handle(req)
            if code == HTTP_STATUS.OK then
              do_response(fd, interface.write, code, bodyfunc,rspheader)
              return true
            else
              do_response(fd, interface.write, code)
            end
          end
        end
      else
        if url == sockethelper.socket_error then
          log.info("httpd : socket closed!!!", fd)
        else
          log.error("httpd : request failed!!!", fd, url)
        end
      end
    end,

    close = function()
      if is_close then return end
      is_close = true
      socket.close(fd)
      if interface.close then
        interface.close()
      end
    end
  }
end

return do_request
