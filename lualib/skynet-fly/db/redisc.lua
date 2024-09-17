local redisf = require "skynet-fly.db.redisf"

local tinsert = table.insert
local tunpack = table.unpack
local pairs = pairs

local M = {}

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