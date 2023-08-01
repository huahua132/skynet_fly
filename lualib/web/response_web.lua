local httpd = require "httpd"
local sockethelper = require "sockethelper"
local HTTP_STATUS = require "HTTP_STATUS"
local log = require "log"
local json = require "cjson"

local setmetatable = setmetatable

local M = {}
local mt = { __index = M }

function M:new()
    local instance = {
        resp_header = {}, -- TODO:
        status = HTTP_STATUS.OK,
		body = "",
    }
    return setmetatable(instance, mt)
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
