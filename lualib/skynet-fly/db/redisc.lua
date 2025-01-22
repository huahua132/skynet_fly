---#API
---#content ---
---#content title: redis命令扩展
---#content date: 2024-06-29 22:00:00
---#content categories: ["skynet_fly API 文档","数据库相关"]
---#content category_bar: true
---#content tags: [skynet_fly_api]
---#content ---
---#content [redisc](https://github.com/huahua132/skynet_fly/blob/master/lualib/skynet-fly/db/redisc.lua)

---#content redis命令扩展重写的例子
local redisf = require "skynet-fly.db.redisf"

local tinsert = table.insert
local tunpack = table.unpack
local pairs = pairs

local M = {}

---#desc 重写hgetall 改为map结果形式
---@param key string rediskey
---@return table
function M:hgetall(key)
	local conn = self.conn
	local ret = conn:hgetall(key)
	local res = {}
	
	for i = 1,#ret,2 do
		local k = ret[i]
		local v = ret[i + 1]
		res[k] = v
	end

	return res
end

---#desc 重写hmset 能直接传递map
---@param key string rediskey
---@param map table map表
---@return number
function M:hmset(key,map)
	local conn = self.conn
	local args_list = {}
	for k,v in pairs(map) do
		tinsert(args_list,k)
		tinsert(args_list,v)
	end
	return conn:hmset(key,tunpack(args_list))
end

redisf.add_command(M)

return redisf