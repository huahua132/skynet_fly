local json = require "cjson"

local string = string
local x_pcall = x_pcall
local assert = assert

local M = {}


function M.encode(tab)
	assert(tab)

	return x_pcall(json.encode,tab)
end

function M.decode(pstr)
	assert(pstr)
	return x_pcall(json.decode,pstr)
end

function M.pack(name,tab)
	assert(name)
	assert(tab)

	local ok,str = M.encode(tab)
	if not ok then
		return nil,str
	end

	local pbmsgbuff = string.pack(">I2",name:len()) .. name .. str
	return pbmsgbuff
end

function M.unpack(msgbuff)
	assert(msgbuff)
	local name_sz = (msgbuff:byte(1) << 8) + msgbuff:byte(2)
	local packname = msgbuff:sub(3,3 + name_sz - 1)
	local pack_str = msgbuff:sub(3 + name_sz)

	local ok,tab = M.decode(pack_str)
	if not ok then
		return nil,tab
	end

	return packname,tab
end

return M