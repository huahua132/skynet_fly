local log = require "log"
local timer = require "timer"
local pb_util = require "pb_util"
local socket = require "socket"
local netpack = require "netpack"
local skynet = require "skynet"

local string = string
local pcall = pcall
local recv_cancel = nil

local CMD = {}

local function recv_msg(fd,unpack,dispatch)
	local is_cancel = false
	local total_msg = ""

	local function unpack_msg()
		local sz = total_msg:len()
		if sz < 2 then
			return nil
		end

		local pack_sz = (total_msg:byte(1) << 8) + total_msg:byte(2)
		if sz < pack_sz + 2 then
			return nil
		end

		local offset = 2
		local msg = total_msg:sub(offset + 1,offset + pack_sz)
		total_msg = total_msg:sub(offset + 1 + pack_sz)
		return msg
	end

	skynet.fork(function()
		while not is_cancel do
			local ok,msg = pcall(socket.read,fd)
			if not ok then
				log.error("read faild ",fd)
				break
			end

			total_msg = total_msg .. msg
			while total_msg:len() > 0 do
				local one_pack = unpack_msg()
				if not one_pack then break end
				dispatch(unpack(one_pack))
			end
		end

		socket.close(fd)
	end)

	return function() 
		is_cancel = true
	end
end

function CMD.start(config)
	pb_util.load("./proto")

	local fd,err = socket.open('127.0.0.1','8001')
	if not fd then
		log.fatal("open socket err ",'127.0.0.1','8001')
		return
	end

	local login_req = {
		account = config.account,
		password = config.password,
	}

	local packname = ".login.LoginReq"
	local pbmsgbuff,err = pb_util.pack(packname,login_req)
	if not pbmsgbuff then
		log.fatal("pack err ",err)
		return
	end
	local msg,sz = netpack.pack(pbmsgbuff)
	socket.write(fd,msg,sz)
	
	recv_cancel = recv_msg(fd,pb_util.unpack,function(packname,tab)
		log.info("dispath msg ",packname,tab)
	end)

	return true
end

function CMD.exit()
	
end

return CMD