local math_util = require "skynet-fly.utils.math_util"

local assert = assert
local spack = string.pack
local tostring = tostring

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
		local pbmsgbuff = spack(">I2",name:len()) .. name .. str
		return pbmsgbuff
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
			return nil, tostring(body) .. 'name:' .. name
		end
	
		return name,body
	end
end

--------------------------------------------------------------------------
--协议号方式打包 
--------------------------------------------------------------------------
function M.create_pack_by_id(encode)
	return function(packid, body)
		assert(packid and packid <= math_util.uint16max, "invaild packid = " .. tostring(packid))
		assert(body)

		local ok,str = encode(packid, body)   --消息体打包
		if not ok then
			return nil,str
		end
		--结构【大端无符号2字节记录协议号 + 消息体】
		local pbmsgbuff = spack(">I2",packid) .. str
		return pbmsgbuff
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
			return nil, tostring(body) .. 'packid:' .. packid
		end
	
		return packid, body
	end
end

return M