local log = require "log"
local skynet = require "skynet"
local pb_util = require "pb_util"
local socket = require "socket"
local netpack = require "netpack"

local M = {}

function M.init(gate)
	pb_util.load("./proto")
end

function M.unpack(msg,sz)
	local msgstr = skynet.tostring(msg,sz)
	if sz < 2 then
		log.info("unpack invalid msg ",msgstr,sz)
		return nil
	end
	
	local packname,tab = pb_util.unpack(msgstr)
	if not packname then
		log.fatal("unpack err ",tab)
		return
	end

	if packname ~= ".login.LoginReq" then
		log.fatal("unpack err pack ",packname)
		return
	end

	return tab
end

function M.dispatch(fd,address,msgtab)
	skynet.ignoreret()
	log.info("dispatch:",fd,address,msgtab)

	local login_res = {
		player_id = 10000,
	}
	local msg,err = pb_util.pack(".login.LoginRes",login_res)
	if not msg then
		log.error("pb_util.pack err ",msg)
		return
	end

	socket.write(fd,netpack.pack(msg))
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