local log = require "skynet-fly.log"
local timer = require "skynet-fly.timer"
local skynet = require "skynet"
local pb_netpack = require "skynet-fly.netpack.pb_netpack"
local sp_netpack = require "skynet-fly.netpack.sp_netpack"
local sproto = require "sproto"
local core = require "sproto.core"

local CMD = {}

local function protobuff_test()
	log.error("protobuff_test start!!!")

	log.info(pb_netpack.load("./proto"))

	local login_req = {
		player_id = 100001,
		nickname = "skynet_fly",
		password = "123456",
		account = "skynet",
	}

	local ok,pb_str = pb_netpack.encode(".login.LoginReq",login_req)
	log.info("pb.encode:",ok,#pb_str,pb_str)

	log.info("pb.decode:",pb_netpack.decode(".login.LoginReq",pb_str))

	log.error("protobuff_test end!!!")
end

local function sproto_test()
	log.error("sproto_test start!!!")

	local sproto_str = io.open('./sproto/login.sproto'):read('a')
	local sp = sproto.parse(sproto_str)
	core.dumpproto(sp.__cobj)
	
	for _, f in ipairs {"LoginReq", "LoginRes"} do
		local def = sp:default(f)
		print("default table for " .. f)
		log.info(def)
		print("--------------")
	end

	local login_req = {
		player_id = 100001,
		nickname = "skynet_fly",
		password = "123456",
		account = "skynet",
	}
	local pb_str = sp:encode("LoginReq", login_req)
	log.info("sp encode:",#pb_str, pb_str)
	log.info("sp pencode:", #sp:pencode("LoginReq", login_req))

	log.info("sp decode:", sp:decode("LoginReq", pb_str))

	log.error("sproto_test end!!!")
end

local function sproto_netpack_test()
	log.error("sproto_netpack_test start!!!")

	log.info(sp_netpack.load("./sproto"))
	sp_netpack.set_pcode()  --压缩方式
	local login_req = {
		player_id = 100001,
		nickname = "skynet_fly",
		password = "123456",
		account = "skynet",
	}

	local ok,pb_str = sp_netpack.encode("LoginReq",login_req)
	log.info("sp.encode:",ok,#pb_str,pb_str)

	log.info("sp.decode:",sp_netpack.decode("LoginReq",pb_str))

	log.error("sproto_netpack_test end!!!")
end

function CMD.start()
	protobuff_test()
	sproto_test()
	sproto_netpack_test()
	return true
end

function CMD.exit()
	return true
end

return CMD