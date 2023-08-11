local skynet = require "skynet"
local timer = require "timer"
local log = require "log"
local mysql = require "skynet.db.mysql"

local pcall = pcall

local CMD = {}
local g_db_conf = nil
local g_db_conn = nil
local g_ti = nil
local g_querying_cnt = 0

local function keep_alive()
	g_ti = timer:new(timer.second * 10,0,function()
		if g_db_conn then
			local ok,ret = pcall(g_db_conn.ping,g_db_conn)
		else
			log.error("keep_alive not conn")
		end
	end)
end

function CMD.start(config)
	g_db_conf = config.db_conf
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

function CMD.exit()
	timer:new(timer.minute,0,function()
		if g_querying_cnt <= 0 then
			if g_ti then
				g_ti:cancel()
			end
			if g_db_conn then
				g_db_conn:disconnect()
			end
			skynet.exit()
		end
	end)
end

return CMD