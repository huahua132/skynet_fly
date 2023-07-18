local skynet = require "skynet"
local time_util = require "time_util"
local log = require "log"
local type = type
local math = math
local x_pcall = x_pcall
local tostring = tostring
local assert = assert
local setmetatable = setmetatable
local tunpack = table.unpack

local M = {}

local CHECK_INVAL_TIME = 6000 --ms
local mata = {__index = M}
local register

local function time_out_func(t)
	if t.is_cancel then return end
	t.cur_times = t.cur_times + 1

	if t.times == 0 or t.cur_times < t.times then
		t.expire_time = time_util.skynet_int_time() + t.expire
		skynet.fork(register,t)
	else
		t.is_over = true
	end

	local is_ok,err = x_pcall(t.callback,tunpack(t.args))
	if not is_ok then
		log.fatal("time_out_func err ",err,t.callback,t.args)
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

--[[
	函数作用域：M 对象的成员函数
	函数名称：new
	描述:  创建一个定时器对象
	参数:
		- expire (number): 过期时间 100等于1秒
		- times (number): 次数，0表示循环触发
		- callback (function): 回调函数
		- ...  回调参数
]]
function M:new(expire,times,callback,...)
	assert(expire >= 0)
	assert(times >= 0)
	assert(type(callback) == "function")

	local t = {
		expire = expire,
		times = times,
		callback = callback,
		args = {...},
		is_cancel = false,
		is_over = false,
		cur_times = 0,
		expire_time = time_util.skynet_int_time() + expire
	}

	skynet.fork(register,t)
	setmetatable(t,mata)
	return t
end

--[[
	函数作用域：M:new 对象的成员函数
	函数名称：cancel
	描述:  取消定时器
]]
function M:cancel()
	self.is_cancel = true
end

--[[
	函数作用域：M:new 对象的成员函数
	函数名称：extend
	描述:  延长定时器
	参数:
		- ex_expire (number): 延长时间 100等于1秒
]]
function M:extend(ex_expire)
	if self.is_cancel or self.is_over then
		return false
	end
	
	local pre_expire = self.expire
	local pre_times = self.times
	local pre_cur_times = self.cur_times
	local pre_callback = self.callback
	local pre_args = self.args
	local pre_expire_time = self.expire_time

	local expire = pre_expire + ex_expire
	self:cancel()
	self = M:new(expire,pre_times,pre_callback,tunpack(pre_args))
	self.cur_times = pre_cur_times
	self.expire_time = time_util.skynet_int_time() + (pre_expire_time - time_util.skynet_int_time()) + ex_expire

	return true
end

--秒
M.second = 100
--分钟
M.minute = M.second * 60
--小时
M.hour = M.minute * 60
--一天
M.day = M.hour * 24

return M