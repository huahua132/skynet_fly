local redisf = require "skynet-fly.db.redisf"
local string_util = require "skynet-fly.utils.string_util"

local setmetatable = setmetatable
local assert = assert
local string = string
local tonumber = tonumber
local next = next

local M = {}
local meta = {__index = M}

local g_dbindex = 0          --redis几号数据库
local g_db_name = "rpc"

function M:new()
	local cli = redisf.new_client(g_db_name)
	local t = {
		cli = cli
	}
	setmetatable(t,meta)
	return t
end

--注册，设置连接信息10秒过期时间，需要1秒调用一次
function M:register(svr_name, svr_id, host, secret_key)
	assert(svr_name,"not svr_name")
	assert(svr_id,"not svr_id")
	assert(host,"not host")

	local key = string.format("skynet_fly:rpc:%s:%s",svr_name, svr_id)
	local info = host
	if secret_key then
		info = host .. '_' .. secret_key
	end
	self.cli:set(key, info, "EX", 10)
end

--获取结点的ip和端口
function M:get_node_host(svr_name, svr_id)
	assert(svr_name,"not svr_name")
	assert(svr_id,"not svr_id")

	local key = string.format("skynet_fly:rpc:%s:%s", svr_name, svr_id)
	local info = self.cli:get(key)
	if not info then return end

	local info_list = string_util.split(info, '_')
	local host = info
	local secret_key = nil
	if next(info_list) then
		host = info_list[1]
		secret_key = info_list[2]
	end

	return host, secret_key
end

--监听结点host
--redis config 需要配置 notify-keyspace-events KA
--可以监听key的所有操作事情包括过期
function M:watch(svr_name,call_back)
	local k = string.format("__keyspace@%d__:skynet_fly:rpc:%s:*",g_dbindex, svr_name)
	return redisf.new_watch(g_db_name,{},{k},function(event, key, psubkey)
		local split_str = string_util.split(key,':')
		local svr_id = tonumber(split_str[#split_str])
		if event == 'set' then
			local host, secret_key = self:get_node_host(svr_name,svr_id)
			if host then
				call_back(event, svr_name, svr_id, host, secret_key)
			else
				call_back("get_failed",svr_name, svr_id)
			end
		elseif event == 'expired' then
			call_back(event, svr_name, svr_id, nil)
		end
	end)
end

return M