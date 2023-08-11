local skynet = require "skynet"
local contriner_client = require "contriner_client"
local log = require "log"

local assert = assert
local setmetatable = setmetatable

local M = {}
local mt = {__index = M}

function M:new(db_name)
	local client = contriner_client:new("mysql_m",db_name)
	assert(client,"not mysql_m service ")

	local t = {
		client = client
	}

	setmetatable(t,mt)
	return t
end

function M:query(sql_str)
	return self.client:balance_call("query",sql_str)
end

return M