local skynet = require "skynet"
local socket = require "socket"
local netpack = require "netpack"
local websocket = require "websocket"
local log = require "log"

local pcall = pcall
local string = string
local assert = assert

local M = {}

--------------------------------------------------------
--基于skynet gate 的消息发送
-------------------------------------------------------
function M.create_gate_send(pack)
	return function(gate,fd,name,tab)
		assert(fd)
		assert(name)
		assert(tab)
	
		local msg,err = pack(name,tab)
		if not msg then
			log.error("pb_netpack.pack err ",name,tab,err)
			return
		end
	
		return socket.write(fd,netpack.pack(msg))
	end
end

--------------------------------------------------------
--基于skynet gate 的消息解包
--------------------------------------------------------
function M.create_gate_unpack(unpack)
	return function(msg,sz)
		assert(msg)
		assert(sz)
	
		local msgstr = skynet.tostring(msg,sz)
		if sz < 2 then
			log.info("unpack invalid msg ",msgstr,sz)
			return nil
		end
		
		local packname,tab = unpack(msgstr)
		if not packname then
			log.error("unpack err ",tab)
			return
		end
	
		return packname,tab
	end
end
--------------------------------------------------------
--通用的客户端消息接送处理
--------------------------------------------------------
function M.create_recv(read,unpack)
	return function(fd,dispatch)
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
				local ok,msg = pcall(read,fd)
				if not ok or msg == false then
					log.error("read faild ",fd,msg)
					break
				end
	
				total_msg = total_msg .. msg
				while total_msg:len() > 0 do
					local one_pack = unpack_msg()
					if not one_pack then break end
					skynet.fork(dispatch,fd,unpack(one_pack))
				end
			end
	
			socket.close(fd)
		end)
	
		return function() 
			is_cancel = true
		end
	end
end

--------------------------------------------------------
--基于skynet ws_gate 的消息发送
--------------------------------------------------------
local function create_ws_gate_send(type)
	local send_type = 'send_' .. type
	return function(pack)
		return function(gate,fd,name,tab)
			assert(fd)
			assert(name)
			assert(tab)
		
			local msg,err = pack(name,tab)
			if not msg then
				log.error("pb_netpack.pack err ",name,tab,err)
				return
			end
		
			--大端2字节表示包长度
			local send_buffer = string.pack(">I2",msg:len()) .. msg
		
			if not gate then
				if websocket.is_close(fd) then
					log.warn("send not exists fd ",fd)
				else
					websocket.write(fd,send_buffer,type)
				end
			else
				skynet.send(gate,'lua',send_type,fd,send_buffer)
			end
		end
	end
end

M.create_ws_gate_send_text = create_ws_gate_send('text')

M.create_ws_gate_send_binary = create_ws_gate_send('binary')


--------------------------------------------------------
--基于skynet ws_gate 的消息解包
--------------------------------------------------------
function M.create_ws_gate_unpack(unpack)
	return function(msg,sz)
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

		local packname,tab = unpack(msgstr)
		if not packname then
			log.error("unpack err ",tab)
			return
		end

		return packname,tab
	end
end

return M