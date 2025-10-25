
---#API
---#content ---
---#content title: mongo直连
---#content date: 2024-06-29 22:00:00
---#content categories: ["skynet_fly API 文档","数据库相关"]
---#content category_bar: true
---#content tags: [skynet_fly_api]
---#content ---
---#content [mongof](https://github.com/huahua132/skynet_fly/blob/master/lualib/skynet-fly/db/mongof.lua)
local container_client = require "skynet-fly.client.container_client"
local mongo = require "skynet.db.mongo"
container_client:register("share_config_m")

local assert = assert
local setmetatable = setmetatable

local g_instance_map = {}
local M = {}

---#desc 新建一个连接对象
---@param db_name string 对应share_config_m 中写的key为mongo表的名为db_name的连接配置
---@return table
function M.new_client(db_name)
	local cli = container_client:new('share_config_m')
	local conf_map = cli:mod_call('query','mongo')
	assert(conf_map and conf_map[db_name],"not mongo conf:" .. db_name)

	local conf = conf_map[db_name]
	local authdb = conf.authdb
	conf.authdb = nil
	local c = mongo.client(conf)
    local db = c[authdb]
    return db
end

---#desc 访问常驻实例
---@param db_name string 对应share_config_m 中写的key为mongo表的名为db_name的连接配置
---@return table
function M.instance(db_name)
	if not g_instance_map[db_name] then
		g_instance_map[db_name] = M.new_client(db_name)
	end

	return g_instance_map[db_name]
end

return M