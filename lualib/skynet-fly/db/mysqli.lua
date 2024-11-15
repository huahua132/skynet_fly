local skynet = require "skynet"
local mysql = require "skynet.db.mysql"
local log = require "skynet-fly.log"
local timer = require "skynet-fly.timer"
local contriner_client = require "skynet-fly.client.contriner_client"

contriner_client:register("share_config_m")

local assert = assert
local setmetatable = setmetatable
local pcall = pcall
local next = next

local g_instance_map = {}

local M = {}

local function keep_alive(week_t)
	local t = next(week_t)
	if not t then return end
	local conn = t.conn
	if conn then
		local ok,ret = pcall(conn.ping, conn)
		if not ok then
			log.error("keep_alive err ", ret)
		end
	else
		log.error("keep_alive not conn ", conn)
	end
end

local g_lmt = {__gc = function(t)
	if t.keep_time then
		t.keep_time:cancel()
	end
end}

local week_mt = {__mode = "kv"}

function M.new_client(db_name)
	local cli = contriner_client:new('share_config_m')
	local conf_map = cli:mod_call('query','mysql')
	assert(conf_map and conf_map[db_name],"not mysql conf")

	local conf = conf_map[db_name]
	local database = conf.database
	conf.database = nil
	local conn = mysql.connect(conf)
	local sql_ret = conn:query('CREATE DATABASE IF NOT EXISTS `' .. database .. '`;')
	if sql_ret.errno then
		log.error("create database err ", sql_ret)
		error("create database err ", sql_ret.err)
	end
	conn:disconnect()
	conf.database = database
	conn = mysql.connect(conf)

	local t = {
		conf = conf,
		conn = conn,
	}

	local week_t = setmetatable({}, week_mt)
	week_t[t] = true

	t.keep_time = timer:new(timer.second * 10,timer.loop, keep_alive, week_t)
	t.keep_time:after_next()

	setmetatable(t, g_lmt)
	return t
end

function M.instance(db_name)
	if not g_instance_map[db_name] then
		g_instance_map[db_name] = M.new_client(db_name)
	end

	return g_instance_map[db_name]
end

return M