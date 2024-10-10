local skynet = require "skynet"
local contriner_client = require "skynet-fly.client.contriner_client"
local mysql = require "skynet.db.mysql"

local assert = assert
local setmetatable = setmetatable
local pcall = pcall
local next = next

contriner_client:register("mysql_m")

local g_instance = nil
local g_instance_map = {}

local M = {}
local mt = {__index = M}

function M:new(db_name)
	local client = contriner_client:new("mysql_m",db_name)
	local t = {
		db_name = db_name,
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
	if self.db_name then
		return self.client:balance_call_by_name("query", sql_str)
	else
		return self.client:balance_call("query",sql_str)
	end
end

function M:max_packet_size()
	if self.db_name then
		return self.client:balance_call_by_name("max_packet_size")
	else
		self.client:balance_call("max_packet_size")
	end
end

return M