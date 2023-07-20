local assert = assert
local spack = string.pack

local M = {}

function M.create_pack(encode)
	return function(name,tab)
		assert(name)
		assert(tab)
	
		local ok,str = encode(name,tab)
		if not ok then
			return nil,str
		end
	
		local pbmsgbuff = spack(">I2",name:len()) .. name .. str
		return pbmsgbuff
	end
end

function M.create_unpack(decode)
	return function(msgbuff)
		assert(msgbuff)
		local name_sz = (msgbuff:byte(1) << 8) + msgbuff:byte(2)
		local packname = msgbuff:sub(3,3 + name_sz - 1)
		local pack_str = msgbuff:sub(3 + name_sz)
	
		local ok,tab = decode(packname,pack_str)
		if not ok then
			return nil,tab
		end
	
		return packname,tab
	end
end

return M