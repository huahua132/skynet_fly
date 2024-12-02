local log = require "skynet-fly.log"
local request = require "skynet-fly.web.request_web"
local response = require "skynet-fly.web.response_web"
local puremagic = require "skynet-fly.utils.puremagic"
local HTTP_STATUS = require "skynet-fly.web.HTTP_STATUS"
local table_pool = require "skynet-fly.pool.table_pool":new(2048)
local setmetatable = setmetatable
local iopen = io.open
local pairs = pairs

local M = {}
local mt = { __index = M,__close = function(t)
	t.res:close()
	table_pool:release(t)
end}

local req_ctx = {}

function M:new(app, oldreq)
    local req = request:new(oldreq)
    if not req then
        return
    end

    local res = response:new()

    req_ctx.method = req.method
    local t = table_pool:get()
    t.matched = t.matched or {}
    t.params = t.params or {}
    for k,v in pairs(t.params) do
        t.params[k] = nil
    end

    local handlers = app.router:match(req.path, req_ctx, t.params, t.matched)
    local found = false
    if handlers then
        found = true
    end
	t.app = app
	t.req = req
	t.res = res
	t.index = 0
	t.handlers = handlers or {}
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

--中断调用,比如中间件验证失败
function M:abort()
    self.index = #self.handlers + 1
end

local filecache = setmetatable({}, { __mode = "kv"  })
local function read_filecache(_, filepath)
    local v = filecache[filepath]
    if v then
        return v
    end
    local fpath = filepath
    log.debug("read_filecache. fpath:", fpath)
    local f = iopen(fpath, 'rb')
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
