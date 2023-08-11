local skynet = require "skynet"
local log = require "log"
local contriner_client = require "contriner_client"
local timer = require "timer"
local mysqlf = require "mysqlf"

local CMD = {}

function CMD.start()
	log.error("mysql_test_m start!!!")
	local game_client = contriner_client:new("mysql_m","game")
	local ret = game_client:mod_call_by_name("query","show tables;")
	log.error("ret :",ret)

	local sql_str = "insert into user(id,name) values('1','skynet_fly');"
	log.info("game insert:",game_client:balance_call_by_name("query",sql_str))

	local sql_str = "select * from user where name = 'skynet_fly';"
	log.info("game select:",game_client:balance_call_by_name("query",sql_str))

	local hall_client = contriner_client:new("mysql_m","hall")
	log.info("hall select:",hall_client:balance_call_by_name("query",sql_str))

	local fcli = mysqlf:new("hall")
	log.info("fcli hall select:",fcli:query(sql_str))

	log.error("mysql_test_m over!!!")

	return true
end

function CMD.exit()
	timer:new(timer.minute,1,skynet.exit)
end

return CMD