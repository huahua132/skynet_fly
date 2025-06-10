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

local function sproto_all_test()
	local sp = sproto.parse [[
	.foobar {
		.nest {
			a 1 : string
			b 3 : boolean
			c 5 : integer
			d 6 : integer(3)
		}
		.map {
			a 1 : string
			b 2 : nest
		}
		a 0 : string
		b 1 : integer
		c 2 : boolean
		d 3 : *nest(a)

		e 4 : *string
		f 5 : *integer
		g 6 : *boolean
		h 7 : *foobar
		i 8 : *integer(2)
		j 9 : binary
		k 10: double
		l 11: *double
		m 12: *map()
	}
	]]

	local obj = {
		a = "hello",
		b = 1000000,
		c = true,
		d = {
			{
				a = "one",
				-- skip b
				c = -1,
			},
			{
				a = "two",
				b = true,
			},
			{
				a = "",
				b = false,
				c = 1,
			},
			{
				a = "decimal",
				d = 1.235,
			}
		},
		e = { "ABC", "", "def" },
		f = { -3, -2, -1, 0 , 1, 2},
		g = { true, false, true },
		h = {
			{ b = 100 },
			{},
			{ b = -100, c= false },
			{ b = 0, e = { "test" } },
		},
		i = { 1,2.1,3.21,4.321, 500.123},
		--j = "\0\1\2\3",
		k = 12.34567,
		l = {11.1, 22.2, 33.3, 44.4},
		m = {
			a = {a = "str1", b = false, c = 5, d = 6},
			c = {a = "str2", b = true, c = 6, d = 7},
		}
	}

	local code = sp:encode("foobar", obj)
	obj = sp:decode("foobar", code)
	log.info(obj)

	core.dumpproto(sp.__cobj)
end

local function benchmark_proto()
	log.error("benchmark_proto start!!!")
	log.info(pb_netpack.load("./proto"))
	local ab = {
		person = {
			{
				name = "Alice",
				id = 10000,
				phone = {
					{ number = "123456789" , type = 1 },
					{ number = "87654321" , type = 2 },
				}
			},
			{
				name = "Bob",
				id = 20000,
				phone = {
					{ number = "01234567890" , type = 3 },
				}
			}
		}
	}
	local _, str = pb_netpack.encode(".benchmark.AddressBook", ab)
	log.info("encode size: ", #str)
	local time = skynet.time()
	for i = 1, 1024 * 1024 do
		pb_netpack.encode(".benchmark.AddressBook", ab)
	end
	local end_time = skynet.time()

	log.info("encode 1M times use time:", end_time - time)

	for i = 1, 1024 * 1024 do
		pb_netpack.decode(".benchmark.AddressBook", str)
	end

	local now_time = skynet.time()
	log.info("decode 1M times use time:", now_time - end_time)

	log.error("benchmark_proto end!!!")
end

local function benchmark_sproto(isp)
	log.error("benchmark_sproto start!!!")
	local name = "sp"
	if isp then
		name = "isp"
	end
	local sp = sp_netpack.new(name)
	log.info(sp.load("./sproto"))
	if isp then
		sp.set_pcode()
	end
	local ab = {
		person = {
			{
				name = "Alice",
				id = 10000,
				phone = {
					{ number = "123456789" , type = 1 },
					{ number = "87654321" , type = 2 },
				}
			},
			{
				name = "Bob",
				id = 20000,
				phone = {
					{ number = "01234567890" , type = 3 },
				}
			}
		}
	}
	local _, str = sp.encode("AddressBook", ab)
	log.info("encode size: ", #str)
	local time = skynet.time()
	for i = 1, 1024 * 1024 do
		sp.encode("AddressBook", ab)
	end
	local end_time = skynet.time()

	log.info("encode 1M use time:", end_time - time)

		for i = 1, 1024 * 1024 do
		sp.decode("AddressBook", str)
	end

	local now_time = skynet.time()
	log.info("decode 1M times use time:", now_time - end_time)

	log.error("benchmark_sproto end!!!")
end

function CMD.start()
	-- protobuff_test()
	-- sproto_test()
	-- sproto_netpack_test()
	-- sproto_all_test()
	benchmark_proto()
	benchmark_sproto()
	benchmark_sproto(true)
	return true
end

function CMD.exit()
	return true
end

return CMD