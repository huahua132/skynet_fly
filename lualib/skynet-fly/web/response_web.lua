local httpd = require "http.httpd"
local sockethelper = require "http.sockethelper"
local HTTP_STATUS = require "skynet-fly.web.HTTP_STATUS"
local table_pool = require "skynet-fly.pool.table_pool":new(2048)
local log = require "skynet-fly.log"
local json = require "cjson"

local setmetatable = setmetatable
local pairs = pairs

local M = {}
local mt = { __index = M}

function M:new()
	local t = table_pool:get()
    for k,v in pairs(t) do
        t[k] = nil
    end
	t.resp_header = t.resp_header or {}
	t.status = HTTP_STATUS.OK
	t.body = ""
    return setmetatable(t, mt)
end

function M:close()
	table_pool:release(self)
end

function M:get_header(header_key)
    return self.resp_header[header_key]
end

function M:set_header(header_key, header_value)
    self.resp_header[header_key] = header_value
end

function M:set_content_type(content_type)
    self:set_header("Content-Type", content_type)
end

function M:set_rsp(text, status, content_type)
    self.status = status or self.status
    content_type = content_type or "text/plain"
    self:set_content_type(content_type)
	self.body = text
end

function M:set_json_rsp(lua_table)
    local text = json.encode(lua_table)
    self:set_content_type("application/json")
	self.status = HTTP_STATUS.OK
	self.body = text
end

function M:set_error_rsp(status)
	self.status = status
end

return M
