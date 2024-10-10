local skynet = require "skynet"
local log = require "skynet-fly.log"
local timer = require "skynet-fly.timer"
local mysqlf = require "skynet-fly.db.mysqlf"
local CMD = {}

local function test()
	log.error("mysql_test_m start!!!")
	local game_client = mysqlf:new("game")

	local create_sql = [[
		CREATE TABLE IF NOT EXISTS `user` (
			`id` int(11) NOT NULL,
			`name` varchar(255) DEFAULT NULL,
			PRIMARY KEY (`id`)
		) ENGINE=InnoDB DEFAULT CHARSET=latin1;
	]]
	game_client:query(create_sql)

	local ret = game_client:query("show tables;")
	log.error("ret :",ret)

	local sql_str = "insert into user(id,name) values('1','skynet_fly');"
	log.info("game insert:",game_client:query(sql_str))

	local sql_str = "select * from user where name = 'skynet_fly';"
	log.info("game select:",game_client:query(sql_str))

	local hall_client = mysqlf:new("hall")
	local ret = hall_client:query("show tables;")
	log.error("ret :",ret)

	hall_client:query(create_sql)
	log.info("hall select:",hall_client:query(sql_str))

	local fcli = mysqlf:new("hall")
	log.info("fcli hall select:",fcli:query(sql_str))

	mysqlf:instance("game"):query("drop table if exists user")
	mysqlf:instance("hall"):query("drop table if exists user")

	log.error("mysql_test_m over!!!")

end

local function test_l_new_client()
	local db = mysqlf.l_new_client("game")
	db.conn:query("drop table if exists user")

	local create_sql = [[
		CREATE TABLE IF NOT EXISTS `user` (
			`id` int(11) NOT NULL,
			`name` varchar(255) DEFAULT NULL,
			PRIMARY KEY (`id`)
		) ENGINE=InnoDB DEFAULT CHARSET=latin1;
	]]
	db.conn:query(create_sql)

	local stmt_insert = db.conn:prepare("INSERT user (id,name) VALUES (?,?),(?,?)")
	log.info("stmt_insert >>> ", stmt_insert)
	local r = db.conn:execute(stmt_insert,10001, "'", 10002, "'ddd")
	log.info("insert ret:", r)
	-- os.execute("pkill mysql")
    -- log.info("杀掉数据库》》》》》》》》》》》》》")

    skynet.sleep(500)

    -- os.execute("systemctl start mysql")
    -- log.info("启动数据库》》》》》》》》》》》》》")
	local r = db.conn:execute(stmt_insert,10003, "'", 10004, "'ddd")
	log.info("insert ret:", r)

	log.info("select:", db.conn:query("select * from user;"))
end

function CMD.start()
	--skynet.fork(test)
	skynet.fork(test_l_new_client)
	return true
end

function CMD.exit()
	return true
end

return CMD