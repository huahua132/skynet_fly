local log = require "log"
local skynet = require "skynet"
local timer = require "timer"
local socket = require "socket"
local pbnet_util = require "pbnet_util"
local pb_util = require "pb_util"

local CMD = {}

local g_config

local function dispatch(packname,tab)
	log.info("dispatch:",packname,tab)
end

local function connnect()
	local fd = socket.open('127.0.0.1',8001)
	if not fd then
		log.error("connect faild ")
		return
	end

	local login_req = {
		account = g_config.account,
		password = g_config.password,
		player_id = g_config.player_id,
	}

	pbnet_util.recv(fd,dispatch)
	pbnet_util.send(fd,'.login.LoginReq',login_req)
	return fd
end

local function loginout(fd)
	local login_out_req = {
		player_id = g_config.player_id,
	}
	pbnet_util.send(fd,'.login.LoginOutReq',login_out_req)
end

--重复登录测试
local function repeat_connect_test()
	connnect()
	connnect()
end

--重复退出测试
local function repeat_loginout_test()
	local fd = connnect()
	loginout(fd)
	loginout(fd)
end

function CMD.start(config)
	pb_util.load('./proto')
	g_config = config

	--repeat_connect_test()
	repeat_loginout_test()
	return true
end

function CMD.exit()

end

return CMD