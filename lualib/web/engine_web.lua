local methods = require "methods_web"
local routergroup = require "routergroup_web"
local context = require "context_web"
local log = require "log"
local radix_router = require "radix-router"
local logger_mid = require "logger_mid"
local HTTP_STATUS = require "HTTP_STATUS"

local string = string
local setmetatable = setmetatable
local pairs = pairs

local M = {}
local mt = { __index = M}

function M:new()
    local instance = {
        routes_n = 0,
        routes = {},
        router = nil,
        no_route = {},
        all_no_route = {},
    }

    instance.routergroup = routergroup:new(instance, '/')
    return setmetatable(instance, mt)
end

function M:default()
    local app = M:new()
    app:use(logger_mid())
    return app
end

function M:set_no_route(...)
    self.no_route = {...}
    self:reset_no_route()
end

function M:reset_no_route()
    self.all_no_route = self.routergroup:combine_handlers(self.no_route)
end

function M:run()
    local router, err = radix_router.new(self.routes)
    if not router then
      -- todo error handling
    end
    self.router = router
end

function M:add_route(method, absolute_path, handlers)
    local path = absolute_path -- todo, converts gin style to openapi style. /users/:name -> /users/{name}
    self.routes_n = self.routes_n + 1
    self.routes[self.routes_n] = {
      paths = { path },
      methods = { method },
      handler = handlers,
    }
end

-- M:use(middleware1, middleware2, ...)
function M:use(...)
    self.routergroup:use(...)
    self:reset_no_route()
end

-- M:group("v1", ...)
function M:group(relative_path, ...)
    return self.routergroup:group(relative_path, ...)
end

-- M:get(path, handle1, handle2, ...)
-- M:post(path, handle1, handle2, ...)
for method,_ in pairs(methods) do
    local l_name = string.lower(method)
    M[l_name] = function (self, path, ...)
        self.routergroup:handle(method, path, ...)
    end
end

-- M:static_file("favicon.ico", "./favicon.ico")
function M:static_file(relative_path, filepath)
    self.routergroup:static_file(relative_path, filepath)
end

-- M:static_dir("/static", "./")
function M:static_dir(relative_path, static_path)
    self.routergroup:static_dir(relative_path, static_path)
end

function M.dispatch(app)
	return function(req)
		local c <close> = context:new(app,req)
		if not c then
			log.warn("dispatch request failed addr:",req.ip .. ':' .. req.port,", fd:",req.fd)
			return HTTP_STATUS.Internal_Server_Error
		end

		if c.found then
			c:next()
		else
			c.res:set_error_rsp(HTTP_STATUS.Not_Found)
			c.handlers = app.all_no_route
			c:next()
		end

		return c.res.status,c.res.body,c.res.resp_header
	end
end

return M
