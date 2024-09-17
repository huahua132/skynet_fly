local skynet = require "skynet"
local timer = require "skynet-fly.timer"
local log = require "skynet-fly.log"
local mysql = require "skynet.db.mysql"

local pcall = pcall

local CMD = {}
local g_db_conf = nil
local g_db_conn = nil
local g_ti = nil
local g_querying_cnt = 0

local function keep_alive()
	g_ti = timer:new(timer.second * 10,timer.loop,function()
		if g_db_conn then
			local ok,ret = pcall(g_db_conn.ping,g_db_conn)
			if not ok then
				log.error("keep_alive err ", ret)
			end
		else
			log.error("keep_alive not conn ", g_db_conf)
		end
	end)
	g_ti:after_next()
end

function CMD.start(config)
	g_db_conf = config.db_conf

	if config.is_create then
		local database = g_db_conf.database
		g_db_conf.database = nil
		local ok,conn = pcall(mysql.connect, g_db_conf)
		if not ok then
			log.error("connect faild ",conn,g_db_conf)
			return
		end

		conn:query('CREATE DATABASE IF NOT EXISTS ' .. database .. ';')
		conn:disconnect()
		g_db_conf.database = database
	end

	local ok,conn = pcall(mysql.connect,g_db_conf)
	if not ok then
		log.error("connect faild ",conn,g_db_conf)
		return
	end

	g_db_conn = conn
	keep_alive()
	return true
end

function CMD.query(sql_str)
	g_querying_cnt = g_querying_cnt + 1
	local ok,ret = pcall(g_db_conn.query,g_db_conn,sql_str)
	g_querying_cnt = g_querying_cnt - 1
	if not ok then
		log.error("query faild ",g_db_conf.host,g_db_conf.port,g_db_conf.database,sql_str)
		return nil
	end

	return ret
end

function CMD.max_packet_size()
	return g_db_conf.max_packet_size or 1024 * 1024
end

function CMD.check_exit()
	return g_querying_cnt <= 0
end

function CMD.exit()
	if g_ti then
		g_ti:cancel()
	end
	if g_db_conn then
		g_db_conn:disconnect()
	end
	return true
end

return CMD