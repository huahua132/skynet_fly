local skynet = require "skynet"
local contriner_client = require "contriner_client"
local redis = require "skynet.db.redis"
local sha2 = require "sha2"
local log = require "log"

local setmetatable = setmetatable
local assert = assert
local pcall = pcall
local ipairs = ipairs
local type = type
local string = string

local g_sha_map = {}

local M = {}
--[[
	函数作用域：M的成员函数
	函数名称：new_client
	描述:新建一个在share_config_m 中写的key为redis表的名为db_name的连接配置
	参数：
		- db_name (string): 连接配置名称
]]
function M.new_client(db_name)
	local cli = contriner_client:new('share_config_m')
	local conf_map = cli:mod_call('query','redis')
	assert(conf_map and conf_map[db_name],"not redis conf")

	local conf = conf_map[db_name]
	local ok,conn = pcall(redis.connect,conf)
	if not ok then
		log.fatal("redisf new_client err ",conn,conf)
		return nil
	end

	return conn
end

--[[
	函数作用域：M的成员函数
	函数名称：script_run
	描述:运行redis脚本命令
	参数：
		- conn (redis_conn): new_client返回的连接对象
		- script_str (string)：redis lua 脚本
		- ...       脚本传递参数
]]
function M.script_run(conn,script_str,...)
	assert(conn)
	assert(type(script_str) == 'string','script_str not string')

	local sha = g_sha_map[script_str]
	if not sha then
		sha = sha2.sha1(script_str)
		g_sha_map[script_str] = sha
	end

	local ok,ret = pcall(conn.evalsha,conn,sha,...)
	if not ok then
		if string.find(ret,"NOSCRIPT",nil,true) then
			ret = conn:eval(script_str,...)
		end
	end
	
	return ret
end

--[[
	函数作用域：M的成员函数
	函数名称：new_watch
	描述:redis订阅
	参数：
		- db_name (string): 连接的redis名称
		- subscribe_list (table): 订阅的固定key
		- psubscribe_list (table): 订阅的匹配key
		- call_back (function): 消息回调函数

	返回值
		- 取消订阅函数
]]
function M.new_watch(db_name,subscribe_list,psubscribe_list,call_back)
	local cli = contriner_client:new('share_config_m')
	local conf_map = cli:mod_call('query','redis')
	assert(conf_map and conf_map[db_name],"not redis conf")
	local conf = conf_map[db_name]

	local ok,watch = pcall(redis.watch,conf)
	if not ok then
		log.fatal("redisf new_watch err ",conf)
		return nil
	end

	for _,key in ipairs(subscribe_list) do
		watch:subscribe(key)
	end

	for _,key in ipairs(psubscribe_list) do
		watch:psubscribe(key)
	end

	local is_cancel = false

	skynet.fork(function()
		while not is_cancel do
			local ok,msg,key,psubkey = pcall(watch.message,watch)
			if ok then
				call_back(msg,key,psubkey)
			else
				if not is_cancel then
					log.fatal("watch.message err :",msg,key,psubkey)
				end
				break
			end
		end
	end)

	return function()
		for _,key in ipairs(subscribe_list) do
			watch:unsubscribe(key)
		end
	
		for _,key in ipairs(psubscribe_list) do
			watch:punsubscribe(key)
		end
		watch:disconnect()
		is_cancel = true
		return true
	end
end

return M