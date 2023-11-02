local skynet = require "skynet"
local contriner_client = require "contriner_client"
local log = require "log"

local assert = assert
local setmetatable = setmetatable

contriner_client:register("mysql_m")

local g_instance = nil
local g_instance_map = {}

local M = {}
local mt = {__index = M}

function M:new(db_name)
	local client = contriner_client:new("mysql_m",db_name)
	local t = {
		client = client
	}

	setmetatable(t,mt)
	return t
end

function M:instance(db_name)
	if not db_name then
		g_instance = g_instance or M:new()
		return g_instance
	end

	if not g_instance_map[db_name] then
		g_instance_map[db_name] = M:new(db_name)
	end

	return g_instance_map[db_name]
end

function M:query(sql_str)
	return self.client:balance_call("query",sql_str)
end

return M