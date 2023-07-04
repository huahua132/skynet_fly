local log = require "log"
local timer = require "timer"
local skynet = require "skynet"
local pb_util = require "pb_util"

local CMD = {}

function CMD.start()
	log.error("proto_test_m start!!!")

	log.info(pb_util.load("./proto"))

	local login_req = {
		player_id = 100001,
		nickname = "skynet_fly",
		password = "123456",
		account = "skynet",
	}

	local ok,pb_str = pb_util.encode(".login.LoginReq",login_req)
	log.info("pb.encode:",ok,pb_str)

	log.info("pb.decode:",pb_util.decode(".login.LoginReq",pb_str))

	log.error("proto_test_m start!!!")
end

function CMD.exit()
	timer:new(timer.second*60,1,skynet.exit)
end

return CMD