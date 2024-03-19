local skynet = require "skynet"
local time_util = require "skynet-fly.utils.time_util"
local log = require "skynet-fly.log"
local zset = require "skynet-fly.3rd.zset"
local timer = require "skynet-fly.timer"
local setmetatable = setmetatable
local os = os
local ipairs = ipairs
local pairs = pairs
local table = table
local next = next
local math = math
local assert = assert
local tostring = tostring

local cur_time_point = time_util.skynet_int_time()
local cache_obj_list = {}

--添加
local function add(self, key, value)
	local expire_time = cur_time_point + self.cache_time
	self.pre_expire_map[key] = expire_time
	if not self.expire_time_map[expire_time] then
		self.expire_time_map[expire_time] = {}
	end
	self.expire_time_map[expire_time][key] = true
	self.cache_cnt = self.cache_cnt + 1
	self.cache_map[key] = value
	if self.zs then
		local k = tostring(key)
		self.zs:add(expire_time, k)
		self.tt_map[k] = key
	end
	return true
end
--删除
local function del(self, key, isup)
	local pre_expire_time = self.pre_expire_map[key]
	if pre_expire_time then
		local time_map = self.expire_time_map[pre_expire_time]
		if time_map[key] then
			time_map[key] = nil
			self.cache_cnt = self.cache_cnt - 1
			local v = self.cache_map[key]
			self.cache_map[key] = nil
			self.pre_expire_map[key] = nil
			if not next(time_map) then
				self.expire_time_map[pre_expire_time] = nil
			end
			if self.zs then
				local k = tostring(key)
				self.zs:rem(k)
				self.tt_map[k] = nil
			end
			if self.call_back and not isup then
				skynet.fork(self.call_back, key, v)
			end
			return true
		end
	end

	return false
end

--过期时间检查循环
local function cache_clear_loop()
	local now_time = time_util.skynet_int_time()
	local diff = now_time - cur_time_point
	for i = 1,diff do
		cur_time_point = cur_time_point + 1
		for _,obj in ipairs(cache_obj_list) do
			local expire_time_map = obj.expire_time_map
			if expire_time_map[cur_time_point] then
				local time_map = expire_time_map[cur_time_point]
				for key,_ in pairs(time_map) do
					del(obj, key)
				end
			end
		end
	end

	skynet.timeout(100,cache_clear_loop)
end

cache_clear_loop()

--TTI 淘汰策略
local function TTI_del(self)
	local function tti_d(k)
		local key = assert(self.tt_map[k])
		del(self, key)
	end

	self.zs:rev_limit(self.cache_limit, tti_d)
	self.tting = false
end

local M = {}
local mata = {__index = M}

--新建一个缓存对象
function M:new(cache_time,call_back,cache_limit)
	assert(cache_time > 0)

	local t = {
		cache_time = cache_time,
		cache_map = {},
		call_back = call_back,
		cache_limit = cache_limit,
		cache_cnt = 0,
		expire_time_map = {},
		pre_expire_map = {},
	}
	if cache_limit then
		t.zs = zset:new()
		t.tting = false    --是否触发TTI了
		t.tt_map = {}
	end
	table.insert(cache_obj_list,t)
	setmetatable(t,mata)

	return t
end

--设置缓存
function M:set_cache(key,value)
	assert(key)
	assert(value)
	if self.cache_map[key] then
		return false
	end
	if self.cache_limit and self.cache_cnt >= self.cache_limit then
		if not self.tting then
			self.tting = true
			timer:new(timer.second * 1, 1, TTI_del, self)
		end
	end

	add(self, key, value)
	return true
end
--获取缓存
function M:get_cache(key)
	assert(key)
	return self.cache_map[key]
end
--更新缓存
function M:update_cache(key,value)
	assert(key)
	assert(value)
	if not self.cache_map[key] then
		return false
	end

	del(self, key, true)
	add(self, key, value)
	return true
end
--删除缓存
function M:del_cache(key)
	assert(key)
	if not self.cache_map[key] then
		return false
	end
	del(self, key)
	return true
end

return M
