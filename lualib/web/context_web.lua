local log = require "log"
local request = require "request_web"
local response = require "response_web"
local file_util = require "file_util"
local puremagic = require "puremagic"
local HTTP_STATUS = require "HTTP_STATUS"

local setmetatable = setmetatable
local iopen = io.open

local M = {}
local mt = { __index = M }

function M:new(app, req)
    local req = request:new(req)
    if not req then
        return
    end

    local res = response:new()

    local handlers, params = app.router:match(req.path, req.method)
    log.debug("wlua context new. path:", req.path, ", method:", req.method, ", params:", params,",handlers:",handlers)

    local found = false
    if handlers then
        found = true
    end
    local instance = {
        app = app,
        req = req,
        res = res,
        index = 0,
        handlers = handlers or {},
        params = params,
        found = found,
    }
    return setmetatable(instance, mt)
end

function M:next()
    self.index = self.index + 1
    while self.index <= #self.handlers do
        self.handlers[self.index](self)
        self.index = self.index + 1
    end
end

-- M:send(text, status, content_type)
function M:send(...)
    self.res:send(...)
end

-- M:send_json({AA="BB"})
function M:send_json(...)
    self.res:send_json(...)
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
        local mimetype = puremagic.via_content(content, filepath)
        filecache[filepath] = { content, mimetype }
    else
        filecache[filepath] = {}
    end
    return filecache[filepath]
end

M.static_file = setmetatable({}, { __index = read_filecache })

function M:file(filepath)
    local ret = file_util.static_file[filepath]
    local content = ret[1]
    local mimetype = ret[2]
    if not content then
        self.found = false
        self.res.status = HTTP_STATUS.Not_Found
        log.debug("file not exist:", filepath)
        return
    end
    log.debug("file. filepath:", filepath, ", mimetype:", mimetype)
	self:set_text_rsp(content,HTTP_STATUS.OK,mimetype)
end

return M
