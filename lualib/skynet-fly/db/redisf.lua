---#API
---#content ---
---#content title: redis调用
---#content date: 2024-06-29 22:00:00
---#content categories: ["skynet_fly API 文档","数据库相关"]
---#content category_bar: true
---#content tags: [skynet_fly_api]
---#content ---
---#content [redisf](https://github.com/huahua132/skynet_fly/blob/master/lualib/skynet-fly/db/redisf.lua)

---#content 调用redis命令的基础封装

local skynet = require "skynet"
local contriner_client = require "skynet-fly.client.contriner_client"
local redis = require "skynet.db.redis"
local string_util = require "skynet-fly.utils.string_util"
local crypt = require "skynet.crypt"
local log = require "skynet-fly.log"

local setmetatable = setmetatable
local assert = assert
local pcall = pcall
local ipairs = ipairs
local pairs = pairs
local type = type
local string = string
local tpack = table.pack
local tunpack = table.unpack
local debug_getinfo = debug.getinfo

contriner_client:register('share_config_m')

local g_sha_map = {}

local M = {}
local command = {}     --自定义命令函数

local cmdfuncs = {}    --命令函数缓存

local g_instance_map = {}  --实例

---#desc 运行redis脚本命令
---@param script_str string 脚本串
---@param ... number|string|nil 脚本命令参数 arg1为KEY数量然后紧跟KEYS参数，之后是ARGV参数
---@return number|string|table
function command:script_run(script_str,...)
	local conn = self.conn
	assert(conn,"not connect redis ")
	assert(type(script_str) == 'string','script_str not string')

	local sha = g_sha_map[script_str]
	if not sha then
		sha = crypt.hexencode(crypt.sha1(script_str))
		g_sha_map[script_str] = sha
	end

	local isok,ret = pcall(conn.evalsha,conn,sha,...)
	if not isok then
		if string.find(ret,"NOSCRIPT",nil,true) then
			ret = conn:eval(script_str,...)
		end
	end
	
	return ret
end

local function get_line_info()
	local info = debug_getinfo(3,"Sl") 
	return info.short_src .. ":" .. info.currentline
end

--给redis命令施加保护执行
local mt = {
	__index = function(t,k)
		local f = cmdfuncs[k]
		if f then
			t[k] = f
			return f
		end

		local f = function (self,...)
			if not self.conn then
				local ok,conn = pcall(redis.connect,self.conf)
				if not ok then
					log.error("connect redis err ",get_line_info(),conn,k,self.conf)
					return
				else
					self.conn = conn
				end
			end

			local cmd = command[k]
			if cmd then
				local ret = tpack(pcall(cmd,self,...))
				local isok = ret[1]
				local err = ret[2]
				if not isok then
					log.error("call redis command faild ",get_line_info(),err,k,...)
					return
				else
					return tunpack(ret, 2, ret.n)
				end
			else
				local isok,ret = pcall(self.conn[k],self.conn,...)
				if not isok then
					log.error("call redis faild ",get_line_info(),ret,k,...)
					return
				end
				return ret
			end
		end

		t[k] = f
		--缓存命令函数
		cmdfuncs[k] = f
		return f
	end
}

---#desc 运行redis脚本命令
---@param db_name string 对应share_config_m 中写的key为redis表的名为db_name的连接配置
---@return table obj
function M.new_client(db_name)
	local cli = contriner_client:new('share_config_m')
	local conf_map = cli:mod_call('query','redis')
	assert(conf_map and conf_map[db_name],"not redis conf:" .. db_name)

	local conf = conf_map[db_name]
	local t_conn = {
		conf = conf,
		conn = false
	}
	setmetatable(t_conn,mt)
	t_conn:get("ping")       --尝试调一下
	return t_conn
end

---#desc 有时候并不想创建和管理redis连接,就直接访问常驻实例
---@param db_name string 对应share_config_m 中写的key为redis表的名为db_name的连接配置
---@return table obj
function M.instance(db_name)
	if not g_instance_map[db_name] then
		g_instance_map[db_name] = M.new_client(db_name)
	end

	return g_instance_map[db_name]
end

---#desc 增加自定义command命令
---@param M string 对应commond命令实现
function M.add_command(M)
	for k,func in pairs(M) do
		assert(not command[k],"command is exists " .. k)
		command[k] = func
	end
end

---#desc redis订阅
---@param db_name string 对应share_config_m 中写的key为redis表的名为db_name的连接配置
---@param subscribe_list string[] 订阅名列表
---@param psubscribe_list string[] 批量订阅名列表
---@param call_back function 回调函数
---@return function 取消订阅函数
function M.new_watch(db_name,subscribe_list,psubscribe_list,call_back)
	local cli = contriner_client:new('share_config_m')
	local conf_map = cli:mod_call('query','redis')
	assert(conf_map and conf_map[db_name],"not redis conf")
	local conf = conf_map[db_name]

	local is_cancel = false
	local ok,watch

	skynet.fork(function()
		while not ok and not is_cancel do
			ok,watch = pcall(redis.watch,conf)
			if not ok then
				log.error("redisf connect watch err ",conf)
			end
			skynet.sleep(100)
		end
		for _,key in ipairs(subscribe_list) do
			if not is_cancel then
				watch:subscribe(key)
			end
		end

		for _,key in ipairs(psubscribe_list) do
			if not is_cancel then
				watch:psubscribe(key)
			end
		end

		while not is_cancel do
			local ok,msg,key,psubkey = pcall(watch.message,watch)
			if ok then
				call_back(msg,key,psubkey)
			else
				if not is_cancel then
					log.error("watch.message err :",msg,key,psubkey)
				end
			end
		end
	end)

	return function()
		is_cancel = true
		if watch then
			for _,key in ipairs(subscribe_list) do
				watch:unsubscribe(key)
			end
		
			for _,key in ipairs(psubscribe_list) do
				watch:punsubscribe(key)
			end
			watch:disconnect()
			watch = nil
		end
		return true
	end
end

return M