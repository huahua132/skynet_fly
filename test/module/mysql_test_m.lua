local skynet = require "skynet"
local log = require "skynet-fly.log"
local contriner_client = require "skynet-fly.client.contriner_client"
local timer = require "skynet-fly.timer"
local mysqlf = require "skynet-fly.db.mysqlf"
contriner_client:register("mysql_m")
local CMD = {}

local function test()
	log.error("mysql_test_m start!!!")
	local game_client = contriner_client:new("mysql_m","game")

	local create_sql = [[
		CREATE TABLE IF NOT EXISTS `user` (
			`id` int(11) NOT NULL,
			`name` varchar(255) DEFAULT NULL,
			PRIMARY KEY (`id`)
		) ENGINE=InnoDB DEFAULT CHARSET=latin1;
	]]
	game_client:mod_call_by_name("query", create_sql)

	local ret = game_client:mod_call_by_name("query","show tables;")
	log.error("ret :",ret)

	local sql_str = "insert into user(id,name) values('1','skynet_fly');"
	log.info("game insert:",game_client:balance_call_by_name("query",sql_str))

	local sql_str = "select * from user where name = 'skynet_fly';"
	log.info("game select:",game_client:balance_call_by_name("query",sql_str))

	local hall_client = contriner_client:new("mysql_m","hall")
	hall_client:mod_call_by_name("query", create_sql)
	log.info("hall select:",hall_client:balance_call_by_name("query",sql_str))

	local fcli = mysqlf:new("hall")
	log.info("fcli hall select:",fcli:query(sql_str))

	mysqlf:instance("game"):query("drop table if exists user")
	mysqlf:instance("hall"):query("drop table if exists user")

	log.error("mysql_test_m over!!!")

end

function CMD.start()
	skynet.fork(test)
	return true
end

function CMD.exit()
	return true
end

return CMD