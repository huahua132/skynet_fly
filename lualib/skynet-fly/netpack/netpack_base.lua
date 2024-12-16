local math_util = require "skynet-fly.utils.math_util"

local assert = assert
local spack = string.pack
local sunpack = string.unpack
local tostring = tostring
local tinsert = table.insert
local mceil = math.ceil
local sfmt = string.format

local M = {}

--------------------------------------------------------------------------
--包名方式打包 
--------------------------------------------------------------------------
function M.create_pack(encode)
	return function(name,body)
		assert(name)
		assert(body)
	
		local ok,str = encode(name,body)   --消息体打包
		if not ok then
			return nil,str
		end
		--结构【大端无符号2字节记录包名长度 + 包名 + 消息体】
		local msgbuff = spack(">I2",name:len()) .. name .. str
		return msgbuff
	end
end

--------------------------------------------------------------------------
--包名方式解包 
--------------------------------------------------------------------------
function M.create_unpack(decode)
	return function(msgbuff)
		assert(msgbuff)
		local name_sz = (msgbuff:byte(1) << 8) + msgbuff:byte(2) --大端无符号2字节记录包名长度
		local name = msgbuff:sub(3,3 + name_sz - 1)			 --包名
		local pack_str = msgbuff:sub(3 + name_sz)			     --消息体
		local ok,body = decode(name,pack_str)				 --消息体解包
		if not ok then
			return nil, tostring(body) .. ' name:' .. name
		end
	
		return name,body
	end
end

--------------------------------------------------------------------------
--协议号方式打包 
--------------------------------------------------------------------------
function M.create_pack_by_id(encode)
	return function(packid, body)
		assert(packid and packid <= math_util.uint16max, "invalid packid = " .. tostring(packid))
		assert(body)

		local ok,str = encode(packid, body)   --消息体打包
		if not ok then
			return nil,str
		end
		--结构【大端无符号2字节记录协议号 + 消息体】
		local msgbuff = spack(">I2",packid) .. str
		return msgbuff
	end
end

--------------------------------------------------------------------------
--协议号方式解包 
--------------------------------------------------------------------------
function M.create_unpack_by_id(decode)
	return function(msgbuff)
		assert(msgbuff)
		local packid = (msgbuff:byte(1) << 8) + msgbuff:byte(2) --大端无符号2字节协议号
		local pack_str = msgbuff:sub(3)			 				--消息体
	
		local ok,body = decode(packid, pack_str)				 --消息体解包
		if not ok then
			return nil, tostring(body) .. ' packid:' .. packid
		end
	
		return packid, body
	end
end

--------------------------------------------------------------------------
--支持客户端RPC、服务端发送大包的协议
--------------------------------------------------------------------------
--[[
	前言声明
		无特殊备注整数均为无符号
		无特殊备注的整数均已大端无符号打包
		不支持客户端发送大包的原因是 可能利用此行为进行攻击服务器，导致服务器内存耗尽

	packtype 描述:包类型   占用字节:1  字段描述: (0-整包  1包头  2包体  3包尾)
	msgtype  描述:消息类型 占用字节:1  字段描述: (0-服务端推送 1-客户端推送 2-客户端请求 3-服务端回复 4-服务器出错)
	packid   描述:包ID     占用字节:2  字段描述: 包体ID
	session  描述:会话号   占用字节:4  字段描述: (服务端推送时用于标识同一包体，客户端推送为0即可(不能发送大包)，客户端请求(奇数)达到(4,294,967,295)时客户端应该直接切换到1,避免服务端使用溢出后的0进行回复, 服务端回复，服务端出错(偶数,奇数基础上1))
	msgbody  描述:消息内容 占用字节:包总长度-8   字段描述：包头时为4字节的消息内容长度
]]
--包类型定义 
local PACK_TYPE = {
	WHOLE = 0,  --整包
	HEAD  = 1,  --包头
	BODY  = 2,  --包体
	TAIL  = 3,  --包尾
}

M.PACK_TYPE = PACK_TYPE

--消息类型定义
local MSG_TYPE = {
	SERVER_PUSH = 0,
	CLIENT_PUSH = 1,
	CLIENT_REQ  = 2,
	SERVER_RSP  = 3,
	SERVER_ERR  = 4,
}
M.MSG_TYPE = MSG_TYPE

function M.create_pack_by_rpc(encode)
	return function(packid, body)
		assert(packid and packid <= math_util.uint16max, "invalid packid = " .. tostring(packid))
		assert(body, "not body")
		local msgtype = assert(body.msgtype, "body not msgtype")
		assert(msgtype >= MSG_TYPE.SERVER_PUSH and msgtype <= MSG_TYPE.SERVER_ERR, "invalid msgtype:" .. msgtype)
		local session = assert(body.session, "body not session")
		assert(session >= 0 and session <= math_util.uint32max, "invalid session:" .. session)
		local msgbody = assert(body.msgbody, "not msgbody")
		local ok,str = encode(packid, msgbody)   --消息内容打包
		if not ok then
			return nil,str
		end
		--打包
		--小于32k一个整包搞定
		local msg_len = str:len()
		if msg_len <= math_util.int16max then
			return spack(">I1>I1>I2>I4", PACK_TYPE.WHOLE, msgtype, packid, session) .. str
		else
			--大于32k分包
			local head = spack(">I1>I1>I2>I4>I4", PACK_TYPE.HEAD, msgtype, packid, session, msg_len)
			local body = spack(">I1>I1>I2>I4", PACK_TYPE.BODY, msgtype, packid, session)
			local tail = spack(">I1>I1>I2>I4", PACK_TYPE.TAIL, msgtype, packid, session)
			local msgbuff_list = {head}
			local offset = math_util.int16max
			local batch = mceil(msg_len / math_util.int16max)
			
			for i = 1, batch do
				local msg = str:sub((i - 1) * offset + 1, i * offset)
				if i ~= batch then
					tinsert(msgbuff_list, body .. msg)
				else
					tinsert(msgbuff_list, tail .. msg)
				end
			end

			return msgbuff_list
		end
	end
end

function M.create_unpack_by_rpc(decode)
	return function(msgbuff)
		assert(msgbuff)
		local packtype, msgtype, packid, session, offset = sunpack(">I1>I1>I2>I4", msgbuff)
		assert(packid and packid <= math_util.uint16max, "invalid packid = " .. tostring(packid))
		assert(msgtype >= MSG_TYPE.SERVER_PUSH and msgtype <= MSG_TYPE.SERVER_ERR, "invalid msgtype:" .. msgtype)
		assert(packtype >= PACK_TYPE.WHOLE and packtype <= PACK_TYPE.TAIL, "invalid packtype:" .. packtype)
		assert(session >= 0 and session <= math_util.uint32max, "invalid session:" .. session)

		local body = {
			packtype = packtype,
			msgtype = msgtype,
			session = session,
		}
		if packtype ~= PACK_TYPE.HEAD then
			body.msgstr = msgbuff:sub(offset)
			if packtype == PACK_TYPE.WHOLE or packtype == PACK_TYPE.TAIL then
				body.decode_func = decode
			end
			return packid, body
		else
			body.msgsz = sunpack(">I4", msgbuff, offset)
			return packid, body
		end
	end
end

return M