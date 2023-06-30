local skynet = require "skynet"
local log = require "log"
local setmetatable = setmetatable
local os = os
local ipairs = ipairs
local pairs = pairs
local table = table
local next = next
local math = math
local assert = assert

local function get_time()
	return math.floor(skynet.time())
end

local cur_time_point = get_time()
local cache_obj_list = {}

local function cache_clear_loop()
	local now_time = get_time()
	local diff = now_time - cur_time_point
	for i = 1,diff do
		cur_time_point = cur_time_point + 1
		for _,obj in ipairs(cache_obj_list) do
			local expire_time_map = obj.expire_time_map
			if expire_time_map[cur_time_point] then
				local time_map = expire_time_map[cur_time_point]
				for key,_ in pairs(time_map) do
					local v = obj.cache_map[key]
					obj:del(key)
					if obj.call_back then
						skynet.fork(obj.call_back,key,v)
					end
				end
			end
		end
	end

	skynet.timeout(100,cache_clear_loop)
end
cache_clear_loop()

local M = {}

function M:new(cache_time,call_back,cache_limit)
	assert(cache_time > 0)

	local t = {
		cache_time = cache_time,
		cache_map = {},
		call_back = call_back,
		cache_limit = cache_limit or 10000,
		cache_cnt = 0,
		expire_time_map = {},
		pre_expire_map = {},
	}
	table.insert(cache_obj_list,t)
	setmetatable(t,self)
	self.__index = self
	return t
end

function M:add(key,value)
	local expire_time = cur_time_point + self.cache_time
	self.pre_expire_map[key] = expire_time
	if not self.expire_time_map[expire_time] then
		self.expire_time_map[expire_time] = {}
	end
	self.expire_time_map[expire_time][key] = true
	self.cache_cnt = self.cache_cnt + 1
	self.cache_map[key] = value
	return true
end

function M:del(key)
	local pre_expire_time = self.pre_expire_map[key]
	if pre_expire_time then
		local time_map = self.expire_time_map[pre_expire_time]
		if time_map[key] then
			time_map[key] = nil
			self.cache_cnt = self.cache_cnt - 1
			self.cache_map[key] = nil
			self.pre_expire_map[key] = nil
			if not next(time_map) then
			self.expire_time_map[pre_expire_time] = nil
			end
			return true
		end
	end

	return false
end

function M:set_cache(key,value)
	assert(key)
	assert(value)
	if self.cache_map[key] then
	return false
	end
	if self.cache_cnt >= self.cache_limit then
	log.fatal("set_cache cache limit ",key,self.cache_limit)
	return false
	end

	self:add(key,value)
	return true
end

function M:get_cache(key)
	assert(key)
	return self.cache_map[key]
end

function M:update_cache(key,value)
	assert(key)
	assert(value)
	if not self.cache_map[key] then
	return false
	end

	self:del(key)
	self:add(key,value)
	return true
end

function M:del_cache(key)
	assert(key)
	if not self.cache_map[key] then
		return false
	end
	self:del(key)
	return true
end

return M
