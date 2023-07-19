local log = require "log"
local json_util = require "json_util"
local skynet = require "skynet"
local websocket = require "websocket"
local socket = require "socket"
local pcall = pcall
local assert = assert
local string = string

local M = {}

--给fd发送socket binary消息
function M.send(gate,fd,name,tab)
	assert(fd)
	assert(name)
	assert(tab)

	local msg,err = json_util.pack(name,tab)
	if not msg then
		log.error("pb_util.pack err ",name,tab,err)
		return
	end

	--大端2字节表示包长度
	local send_buffer = string.pack(">I2",msg:len()) .. msg

	if not gate then
		if websocket.is_close(fd) then
			log.warn("send exists fd ",fd)
		else
			websocket.write(fd,send_buffer,"text")
		end
	else
		skynet.send(gate,'lua','send_text',fd,send_buffer)
	end
end

--解包
function M.unpack(msg,sz)
	assert(msg)
	local msgstr = skynet.tostring(msg,sz)
	if sz < 2 then
		log.info("unpack invalid msg ",msg,sz)
		return
	end
	
	local msgsz = (msgstr:byte(1) << 8) + msgstr:byte(2)
	msgstr = msgstr:sub(3)
	sz = msgstr:len()
	if msgsz ~= sz then
		log.info("unpack invalid msg ",msgsz,sz)
		return
	end

	local packname,tab = json_util.unpack(msgstr)
	if not packname then
		log.error("unpack err ",tab)
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
			local ok,msg = pcall(websocket.read,fd)
			if not ok or msg == false then
				log.error("read faild ",fd,msg)
				break
			end

			total_msg = total_msg .. msg
			while total_msg:len() > 0 do
				local one_pack = unpack_msg()
				if not one_pack then break end
				skynet.fork(dispatch,fd,json_util.unpack(one_pack))
			end
		end

		websocket.close(fd)
	end)

	return function() 
		is_cancel = true
	end
end

return M 