---#API
---#content ---
---#content title: 定时器
---#content date: 2024-06-29 22:00:00
---#content categories: ["skynet_fly API 文档","定时器相关"]
---#content category_bar: true
---#content tags: [skynet_fly_api]
---#content ---
---#content [timer](https://github.com/huahua132/skynet_fly/blob/master/lualib/skynet-fly/timer.lua)
local skynet = require "skynet"
local time_util = require "skynet-fly.utils.time_util"
local log = require "skynet-fly.log"
local type = type
local math = math
local x_pcall = x_pcall
local tostring = tostring
local assert = assert
local setmetatable = setmetatable
local tpack = table.pack
local tunpack = table.unpack

----------------------------------------------------------------------------------------
--private
----------------------------------------------------------------------------------------

local TIMES_LOOP<const> = 0   --循环触发
local CHECK_INVAL_TIME = 6000 --60s
local register

local function repeat_register(t)
	if t.times == TIMES_LOOP or t.cur_times < t.times then
		t.expire_time = time_util.skynet_int_time() + t.expire
		skynet.fork(register,t)
	else
		t.is_over = true
	end
end

local function execute_call_back(t)
	local is_ok,err = x_pcall(t.callback,tunpack(t.args, 1, t.args.n))
	if not is_ok then
		log.error("time_out_func err ",err,t.callback,t.args)
	end
end

local function time_out_func(t)
	if t.is_cancel then return end
	t.cur_times = t.cur_times + 1

	if t.is_after_next then
		--先执行回调，再注册下一次
		execute_call_back(t)
		repeat_register(t)
	else
		--先注册下一次，再执行回调
		repeat_register(t)
		execute_call_back(t)
	end
end

register = function(t)
	while not t.is_cancel do
		local expire_time = t.expire_time
		local remain_time = expire_time - time_util.skynet_int_time()
		if remain_time > CHECK_INVAL_TIME then
			--为了防止大于 1 分钟的定时器出现大量注册又注销，创建过多的无效携程和定时器事件
			skynet.sleep(CHECK_INVAL_TIME)
		else
			skynet.sleep(remain_time)
			time_out_func(t)
			break
		end
	end
end
----------------------------------------------------------------------------------------
--public
----------------------------------------------------------------------------------------

local M = {}
local mata = {__index = M}

---#desc 创建一个定时器对象
---@param expire number 过期时间 100等于1秒
---@param times number 次数，0表示循环触发
---@param callback function 回调函数
---@param ... any 回调参数
---@return table 定时器对象
function M:new(expire,times,callback,...)
	assert(expire >= 0)
	assert(times >= 0)
	assert(type(callback) == "function")

	local t = {
		expire = expire,
		times = times,
		callback = callback,
		args = tpack(...),
		is_cancel = false,
		is_over = false,
		cur_times = 0,
		expire_time = time_util.skynet_int_time() + expire,
		is_after_next = false,
	}

	skynet.fork(register,t)
	setmetatable(t,mata)
	return t
end

---#desc 取消定时器
---@return table 定时器对象
function M:cancel()
	self.is_cancel = true
	return self
end

---#desc 回调执行完再注册下一次，默认先注册下一次，再执行回调
---@return table 定时器对象
function M:after_next()
	self.is_after_next = true
	return self
end

---#desc 定时器延时
---@param ex_expire number 延长时间 100等于1秒
---@return table 定时器对象
function M:extend(ex_expire)
	if self.is_cancel or self.is_over then
		return self
	end
	
	local pre_expire = self.expire
	local pre_times = self.times
	local pre_cur_times = self.cur_times
	local pre_callback = self.callback
	local pre_args = self.args
	local pre_expire_time = self.expire_time
	local pre_is_after_next = self.is_after_next

	local expire = pre_expire + ex_expire
	self:cancel()
	local nt = M:new(expire,pre_times,pre_callback,tunpack(pre_args, 1, pre_args.n))
	nt.cur_times = pre_cur_times
	nt.expire_time = time_util.skynet_int_time() + (pre_expire_time - time_util.skynet_int_time()) + ex_expire
	nt.is_after_next = pre_is_after_next

	return nt
end

---#desc 获取剩余触发时间
---@return number 剩余触发时间  -1 表示已经触发完了或者被取消了
function M:remain_expire()
	if self.is_cancel or self.is_over then
		return -1     --已经触发完了
	end

	return self.expire_time - time_util.skynet_int_time()
end

--循环执行
M.loop = TIMES_LOOP
--秒
M.second = 100
--分钟
M.minute = M.second * 60
--小时
M.hour = M.minute * 60
--一天
M.day = M.hour * 24

return M