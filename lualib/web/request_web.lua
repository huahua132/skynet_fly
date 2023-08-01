local httpd = require "http.httpd"
local sockethelper = require "http.sockethelper"
local json = require "cjson"
local urllib = require "http.url"
local log = require "log"

local sfind = string.find
local setmetatable = setmetatable
local parse_query = urllib.parse_query
local parse_url = urllib.parse

local M = {}
local mt = { __index = M }

-- new request: init args/body etc from http request
function M:new(req)
    log.debug("req. url:", req.url, ", method:", req.method, ", header:", req.header)
	local header = req.header
	local body = req.body
	local url = req.url
    local content_type = header['content-type']
    -- the post request have Content-Type header set
    if content_type then
        if sfind(content_type, "application/x-www-form-urlencoded", 1, true) then
            body = parse_query(body)
        elseif sfind(content_type, "application/json", 1, true) then
            body = json.decode(body)
        end
    -- the post request have no Content-Type header set will be parsed as x-www-form-urlencoded by default
    else
        body = parse_query(body)
    end

    local query = {}
    local path,query_str = parse_url(url)
    if query_str then
        query = parse_query(query_str)
    end

    return {
        path = path,
        method = req.method,
        query = query,
        body = body,
        body_raw = req.body,
        url = url,
        headers = req.headers, -- request headers
        code = req.code,
        fd = req.fd,
		ip = req.ip,
		port = req.port,
		protocol = req.protocol,
    }
end

return M
