local log = require "log"
local request = require "request_web"
local response = require "response_web"
local puremagic = require "puremagic"
local HTTP_STATUS = require "HTTP_STATUS"
local table_pool = require "table_pool":new(2048)

local setmetatable = setmetatable
local iopen = io.open

local M = {}
local mt = { __index = M,__close = function(t)
	t.res:close()
	table_pool:release(t)
end}

function M:new(app, oldreq)
    local req = request:new(oldreq)
    if not req then
        return
    end

    local res = response:new()

    local handlers, params = app.router:match(req.path, req.method)

    local found = false
    if handlers then
        found = true
    end
	local t = table_pool:get()
	t.app = app
	t.req = req
	t.res = res
	t.index = 0
	t.handlers = handlers or {}
	t.params = params
	t.found = found

    return setmetatable(t, mt)
end

function M:next()
    self.index = self.index + 1
    while self.index <= #self.handlers do
        self.handlers[self.index](self)
        self.index = self.index + 1
    end
end

local static_root_path = "./static/"
local filecache = setmetatable({}, { __mode = "kv"  })
local function read_filecache(_, filepath)
    local v = filecache[filepath]
    if v then
        return v
    end
    local fpath = static_root_path .. filepath
    log.debug("read_filecache. fpath:", fpath)
    local f = iopen(fpath)
    if f then
        local content = f:read "a"
        f:close()
		if content then
			local mimetype = puremagic.via_content(content, filepath)
			filecache[filepath] = { content, mimetype }
		else
			filecache[filepath] = {}
		end
    else
        filecache[filepath] = {}
    end
    return filecache[filepath]
end

local static_file = setmetatable({}, { __index = read_filecache })

function M:file(filepath)
    local ret = static_file[filepath]
    local content = ret[1]
    local mimetype = ret[2]
    if not content then
        self.found = false
        self.res.status = HTTP_STATUS.Not_Found
        log.debug("file not exist:", filepath)
        return
    end
    log.debug("file. filepath:", filepath, ", mimetype:", mimetype)
	self.res:set_rsp(content,HTTP_STATUS.OK,mimetype)
end

return M
