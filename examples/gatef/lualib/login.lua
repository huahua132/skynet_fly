local log = require "log"
local skynet = require "skynet"
local pb_util = require "pb_util"
local socket = require "socket"
local netpack = require "netpack"
local pbnet_util = require "pbnet_util"

local M = {}

function M.init(gate)
	pb_util.load("./proto")
end

M.unpack = pbnet_util.unpack

function M.dispatch(fd,address,packname,msgtab)
	skynet.ignoreret()
	log.info("dispatch:",fd,address,packname,msgtab)

	local login_res = {
		player_id = msgtab.player_id,
	}

	pbnet_util.send(fd,".login.LoginRes",login_res)
end

function M.open(gate,fd,addr)
	log.info("open:",gate,fd,addr)
	skynet.call(gate, "lua", "forward", fd)
end

function M.close(gate,fd)
	log.info("close:",gate,fd)
end

function M.error(gate,fd,msg)
	log.info("error:",gate,fd,msg)
end

function M.warning(gate,fd,size)
	log.info("warning:",gate,fd,size)
end

function M.data(gate,fd,msg)
	log.info("data:",gate,fd,msg)
end

function M.check_exit()
	log.info("check_exit")
	return true
end

return M