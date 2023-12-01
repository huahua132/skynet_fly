local json = require "cjson"
local netpack_base = require "netpack_base"

local pcall = pcall
local assert = assert

local M = {}


function M.encode(name,tab)
	assert(tab)
	return pcall(json.encode,tab)
end

function M.decode(name,pstr)
	assert(pstr)
	return pcall(json.decode,pstr)
end

M.pack = netpack_base.create_pack(M.encode)

M.unpack = netpack_base.create_unpack(M.decode)

return M