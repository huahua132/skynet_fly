local log = require "log"
local timer = require "timer"
local pb_util = require "pb_util"
local socket = require "socket"
local skynet = require "skynet"
local pbnet_util = require "pbnet_util"

local string = string
local pcall = pcall
local recv_cancel = nil

local CMD = {}

function CMD.start(config)
	pb_util.load("./proto")

	local fd,err = socket.open('127.0.0.1','8001')
	if not fd then
		log.fatal("open socket err ",'127.0.0.1','8001')
		return
	end

	local login_req = {
		player_id = config.player_id,
		account = config.account,
		password = config.password,
		nickname = config.nickname,
	}

	pbnet_util.send(fd,".login.LoginReq",login_req)

	pbnet_util.recv(fd,function(packname,tab)
		log.info("dispath msg ",packname,tab)
	end)

	return true
end

function CMD.exit()
	
end

return CMD