local log = require "log"
local skynet = require "skynet"
local timer = require "timer"
local socket = require "socket"
local pbnet_util = require "pbnet_util"
local pb_util = require "pb_util"

local CMD = {}

local fd = nil

local function dispatch(packname,tab)
	log.info("dispatch:",packname,tab)
end

function CMD.start(config)
	pb_util.load('./proto')
	fd = socket.open('127.0.0.1',8001)
	if not fd then
		log.error("connect faild ")
		return
	end

	local login_req = {
		account = config.account,
		password = config.password,
		player_id = config.player_id,
	}

	pbnet_util.recv(fd,dispatch)
	pbnet_util.send(fd,'.login.LoginReq',login_req)
	return true
end

function CMD.exit()
	if fd then
		socket.close(fd)
	end
end

return CMD