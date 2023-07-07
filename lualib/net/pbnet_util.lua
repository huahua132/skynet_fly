local log = require "log"
local socket = require "socket"
local netpack = require "netpack"
local pb_util = require "pb_util"
local skynet = require "skynet"
local pcall = pcall
local assert = assert

local M = {}

--给fd发送socket消息
function M.send(fd,name,tab)
	assert(fd)
	assert(name)
	assert(tab)

	local msg,err = pb_util.pack(name,tab)
	if not msg then
		log.error("pb_util.pack err ",msg)
		return
	end

	return socket.write(fd,netpack.pack(msg))
end

--解包
function M.unpack(msg,sz)
	assert(msg)
	assert(sz)

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

	return packname,tab
end

--读取
function M.recv(fd,dispatch)
	assert(fd)
	assert(dispatch)

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
			if not ok or msg == false then
				log.error("read faild ",fd,msg)
				break
			end

			total_msg = total_msg .. msg
			while total_msg:len() > 0 do
				local one_pack = unpack_msg()
				if not one_pack then break end
				skynet.fork(dispatch,pb_util.unpack(one_pack))
			end
		end

		socket.close(fd)
	end)

	return function() 
		is_cancel = true
	end
end

return M 