---#API
---#content ---
---#content title: mysql连接池调用
---#content date: 2024-06-29 22:00:00
---#content categories: ["skynet_fly API 文档","数据库相关"]
---#content category_bar: true
---#content tags: [skynet_fly_api]
---#content ---
---#content [mysqlf](https://github.com/huahua132/skynet_fly/blob/master/lualib/skynet-fly/db/mysqlf.lua)

local skynet = require "skynet"
local container_client = require "skynet-fly.client.container_client"
local mysql = require "skynet.db.mysql"

local assert = assert
local setmetatable = setmetatable
local pcall = pcall
local next = next

container_client:register("mysql_m")

local g_instance = nil
local g_instance_map = {}

local M = {}
local mt = {__index = M}

---#desc 新建一个访问对象
---@param db_name string 对应启动 mysql_m 中 default_arg|mod_args中的instance_name
---@return table obj
function M:new(db_name)
	local client = container_client:new("mysql_m",db_name)
	local t = {
		db_name = db_name,
		client = client
	}

	setmetatable(t,mt)
	return t
end

---#desc 使用常驻实例
---@param db_name string 对应启动 mysql_m 中 default_arg|mod_args中的instance_name
---@return table obj
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

---#desc 查询调用
---@param sql_str string sql语句
---@return table
function M:query(sql_str)
	if self.db_name then
		return self.client:balance_call_by_name("query", sql_str)
	else
		return self.client:balance_call("query",sql_str)
	end
end

---#desc 获取mysql_m配置的最大包体上限值
---@param sql_str string sql语句
---@return number
function M:max_packet_size()
	if self.db_name then
		return self.client:balance_call_by_name("max_packet_size")
	else
		self.client:balance_call("max_packet_size")
	end
end

return M