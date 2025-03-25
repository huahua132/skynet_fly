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
local type = type

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
		
		if type(msg) == 'string' then
			return socket.write(fd,netpack.pack(msg))
		else
			for i = 1, #msg do
				socket.lwrite(fd, netpack.pack(msg[i]))
			end
		end
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

		local is_str_msg = type(msg) == 'string'
		
		for i = 1,#fd_list do
			--netpack.pack会分配内存，write会释放内存，所以必须一个write一个包
			if is_str_msg then
				--广播全部用低权重通道吧
				socket.lwrite(fd_list[i], netpack.pack(msg))
			else
				for i = 1, #msg do
					socket.lwrite(fd_list[i], netpack.pack(msg[i]))
				end
			end
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
			return nil, "The length must be greater than 2 sz=" .. sz
		end
		
		local header,body = unpack(msgstr)
		if not header then
			return nil, body
		end

		return header,body
	end
end
--------------------------------------------------------
--通用的客户端消息接收处理
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
local function create_ws_gate_send(m_type)
	local send_type = 'send_' .. m_type
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
		
			if not gate then
				if websocket.is_close(fd) then
					log.warn("send not exists fd ",fd)
				else
					if type(msg) == 'string' then
						websocket.write(fd,string.pack(">I2",msg:len()) .. msg, m_type)
					else
						for i = 1, #msg do
							websocket.write(fd,string.pack(">I2",msg[i]:len()) .. msg[i], m_type)
						end
					end
				end
			else
				if type(msg) == 'string' then
					skynet.send(gate,'lua',send_type,fd,string.pack(">I2",msg:len()) .. msg)
				else
					for i = 1, #msg do
						skynet.send(gate,'lua',send_type,fd,string.pack(">I2",msg[i]:len()) .. msg[i])
					end
				end
			end
		end
	end
end

local function create_ws_gate_broadcast(m_type)
	local send_type = 'broadcast_' .. m_type
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

			local gate_fd_list = {}
			for i = 1,#fd_list do
				local fd = fd_list[i]
				local gate = gate_list[i]
				if not gate_fd_list[gate] then
					gate_fd_list[gate] = {}
				end
				tinsert(gate_fd_list[gate], fd)
			end

			--大端2字节表示包长度
			local is_str_msg = false
			if type(msg) == 'string' then
				msg = string.pack(">I2",msg:len()) .. msg
				is_str_msg = true
			else
				for i = 1, msg do
					msg[i] = string.pack(">I2",msg[i]:len()) .. msg[i]
				end
			end

			for gate, fd_list in pairs(gate_fd_list) do
				if is_str_msg then
					skynet.send(gate,'lua', send_type, fd_list, msg)
				else
					for i = 1, msg do
						skynet.send(gate,'lua', send_type, fd_list, msg[i])
					end
				end
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
			return nil, "The length must be greater than 2 sz=" .. sz
		end
		
		local msgsz = (msgstr:byte(1) << 8) + msgstr:byte(2)
		msgstr = msgstr:sub(3)
		sz = msgstr:len()
		if msgsz ~= sz then
			return nil, string.format("Inconsistent length msgsz[%s] sz[%s]", msgsz, sz)
		end

		local header,body = unpack(msgstr)
		if not header then
			return nil, body
		end

		return header,body
	end
end

return M