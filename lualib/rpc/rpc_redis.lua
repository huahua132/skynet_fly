local redisf = require "redisf"
local string_util = require "string_util"

local setmetatable = setmetatable
local assert = assert
local string = string
local tonumber = tonumber

local M = {}
local meta = {__index = M}

local g_dbindex = 0          --redis几号数据库
local g_db_name = "rpc"

function M:new()
	local cli = redisf.new_client(g_db_name)
	local t = {
		cli = cli
	}
	assert(cli,"can`t connect redis",g_db_name)
	setmetatable(t,meta)
	return t
end

--注册，设置连接信息2秒过期时间，需要1秒调用一次
function M:register(svr_name,svr_id,host)
	assert(svr_name,"not svr_name")
	assert(svr_id,"not svr_id")
	assert(host,"not host")

	local key = string.format("skynet_fly:rpc:%s:%s",svr_name,svr_id)
	self.cli:set(key,host,"EX",2)
end

--获取结点的ip和端口
function M:get_node_host(svr_name,svr_id)
	assert(svr_name,"not svr_name")
	assert(svr_id,"not svr_id")

	local key = string.format("skynet_fly:rpc:%s:%s",svr_name,svr_id)
	return self.cli:get(key)
end

--监听结点host
--redis config 需要配置 notify-keyspace-events KA
--可以监听key的所有操作事情包括过期
function M:watch(svr_name,call_back)
	local k = string.format("__keyspace@%d__:skynet_fly:rpc:%s:*",g_dbindex,svr_name)
	return redisf.new_watch(g_db_name,{},{k},function(event,key,psubkey)
		local split_str = string_util.split(key,':')
		local svr_id = tonumber(split_str[#split_str])
		if event == 'set' then
			local host = self:get_node_host(svr_name,svr_id)
			if host then
				call_back(event,svr_name,svr_id,host)
			else
				call_back("get_failed",svr_name,svr_id)
			end
		elseif event == 'expired' then
			call_back(event,svr_name,svr_id,nil)
		end
	end)
end

return M