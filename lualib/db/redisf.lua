local skynet = require "skynet"
local contriner_client = require "contriner_client"
local redis = require "skynet.db.redis"
local crypt = require "crypt"
local log = require "log"

local setmetatable = setmetatable
local assert = assert
local pcall = pcall
local ipairs = ipairs
local type = type
local string = string

local function sha1(text)
	local c = crypt.sha1(text)
	return crypt.hexencode(c)
end

local g_sha_map = {}

local M = {}

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


function M.script_run(conn,script_str,...)
	assert(conn)
	assert(type(script_str) == 'string','script_str not string')

	local sha = g_sha_map[script_str]
	if not sha then
		sha = sha1(script_str)
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