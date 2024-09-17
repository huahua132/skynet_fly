local httpd = require "http.httpd"
local sockethelper = require "http.sockethelper"
local json = require "cjson"
local urllib = require "http.url"
local log = require "skynet-fly.log"

local sfind = string.find
local setmetatable = setmetatable
local parse_query = urllib.parse_query
local parse_url = urllib.parse

local M = {}
local empty_table = {}

-- new request: init args/body etc from http request
function M:new(req)
	local header = req.header
	local body = req.body
	local url = req.url
    local content_type = header['content-type'] or ""
    -- the post request have Content-Type header set

	local parse_func = nil
    if sfind(content_type, 'application/x-www-form-urlencoded', nil, true) then
        parse_func = parse_query
    elseif sfind(content_type, 'application/json', nil, true) then
        parse_func = json.decode
    end
    if parse_func then
        body = parse_func(body)
    -- the post request have no Content-Type header set will be parsed as x-www-form-urlencoded by default
    else
        body = parse_query(body)
    end

    local query = empty_table
    local path,query_str = parse_url(url)
    if query_str then
        query = parse_query(query_str)
    end

	req.path = path
	req.query = query
	req.body_raw = req.body
	req.body = body
    return req
end

return M
