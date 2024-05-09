local skynet = require "skynet"
local socket = require "skynet.socket"
local netpack = require "skynet.netpack"
local websocket = require "http.websocket"
local log = require "skynet-fly.log"

local pcall = pcall
local string = string
local assert = assert
local tinsert = table.insert
local pairs = pairs

local M = {}

-------------------------------------------------------
--基于skynet gate 的消息发送
-------------------------------------------------------
function M.create_gate_send(pack)
	return function(gate,fd,header,body)
		assert(fd)
		assert(header)
		assert(body)
	
		local msg,err = pack(header,body)
		if not msg then
			log.error("util_net_base.pack err ",header,body,err)
			return
		end
	
		return socket.write(fd,netpack.pack(msg))
	end
end

-------------------------------------------------------
--基于skynet gate 的消息广播
-------------------------------------------------------
function M.create_gate_broadcast(pack)
	return function(gate_list,fd_list,header,body)
		assert(fd_list and #fd_list > 0)
		assert(header)
		assert(body)

		local msg,err = pack(header,body)
		if not msg then
			log.error("util_net_base.pack err ",header,body,err)
			return
		end

		for i = 1,#fd_list do
			--netpack.pack会分配内存，write会释放内存，所以必须一个write一个包
			socket.write(fd_list[i], netpack.pack(msg))
		end
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
		
		local header,body = unpack(msgstr)
		if not header then
			log.error("unpack err ",body)
			return
		end
	
		return header,body
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
		return function(gate,fd,header,body)
			assert(fd)
			assert(header)
			assert(body)
		
			local msg,err = pack(header,body)
			if not msg then
				log.error("util_net_base.pack err ",header,body,err)
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

local function create_ws_gate_broadcast(type)
	local send_type = 'broadcast_' .. type
	return function(pack)
		return function(gate_list,fd_list,header,body)
			assert(gate_list and #gate_list > 0)
			assert(fd_list and #fd_list > 0)
			assert(header)
			assert(body)
			
			local msg,err = pack(header,body)
			if not msg then
				log.error("util_net_base.pack err ",header,body,err)
				return
			end

			--大端2字节表示包长度
			local send_buffer = string.pack(">I2",msg:len()) .. msg

			local gate_fd_list = {}
			for i = 1,#fd_list do
				local fd = fd_list[i]
				local gate = gate_list[i]
				if not gate_fd_list[gate] then
					gate_fd_list[gate] = {}
				end
				tinsert(gate_fd_list[gate], fd)
			end

			for gate, fd_list in pairs(gate_fd_list) do
				skynet.send(gate,'lua', send_type, fd_list, send_buffer)
			end
		end
	end
end

M.create_ws_gate_send_text = create_ws_gate_send('text')

M.create_ws_gate_send_binary = create_ws_gate_send('binary')

M.create_ws_gate_broadcast_text = create_ws_gate_broadcast('text')

M.create_ws_gate_broadcast_binary = create_ws_gate_broadcast('binary')

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

		local header,body = unpack(msgstr)
		if not header then
			log.error("unpack err ",body)
			return
		end

		return header,body
	end
end

return M