local skynet       = require "skynet"
local socket       = require "skynet.socket"
local sockethelper = require "http.sockethelper"
local httpd        = require "http.httpd"
local HTTP_STATUS = require "skynet-fly.web.HTTP_STATUS"
local table_pool = require "skynet-fly.pool.table_pool":new(2048)
local log = require "skynet-fly.log"
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

local function do_request(fd, ip, port, protocol, handle, max_packge_limit)
	socket.start(fd)
	local interface = gen_interface(protocol, fd)
	if interface.init then
		interface.init()
	end
	local is_close = false
	local code, url, method, header, body
	local req = table_pool:get()
	req.fd = fd
	req.protocol = protocol
	req.ip = ip
	req.port = port
	req.session = {}			--可用于记录一个连接的临时数据

  	return {
    	read_request = function()
			code, url, method, header, body = httpd.read_request(interface.read, max_packge_limit)
			return code
    	end,

		handle_response = function()
			if code ~= HTTP_STATUS.OK then
				httpd.write_response(interface.write, code)
			else
				if header.upgrade == "websocket" then
					httpd.write_response(interface.write, code, HTTP_STATUS.Bad_Request)
				else
					req.method = method
					req.url = url
					req.header = header
					req.body = body
					local code,bodyfunc,rspheader = handle(req)
					if code == HTTP_STATUS.OK then
						httpd.write_response(interface.write, code, bodyfunc, rspheader)
						return true
					else
						httpd.write_response(interface.write, code)
					end
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
			table_pool:release(req)
		end
	}
end

return do_request
