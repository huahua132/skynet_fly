local util = require "util"
local protoc = require "protoc"
local pb = require "pb"

local string = string
local x_pcall = x_pcall
local assert = assert

local M = {}

local g_loaded = {}

function M.load(rootpath)
	for file_name,file_path,file_info in util.diripairs(rootpath) do
		if string.find(file_name,".proto",nil,true) then
			protoc:loadfile(file_path)
		end
	end

	for name,basename,type in pb.types() do
		if not string.find(name,".google.protobuf",nil,true) then
			g_loaded[name] = true
		end
	end

	return g_loaded
end

function M.encode(name,tab)
	assert(name)
	assert(tab)
	if not g_loaded[name] then
		return nil,"encode not exists " .. name
	end

	return x_pcall(pb.encode,name,tab)
end

function M.decode(name,pstr)
	assert(name)
	assert(pstr)
	if not g_loaded[name] then
		return nil,"decode not exists " .. name
	end

	return x_pcall(pb.decode,name,pstr)
end

function M.pack(name,tab)
	assert(name)
	assert(tab)
	if not g_loaded[name] then
		return nil,"pack not exists " .. name
	end
	
	local ok,pbstr = M.encode(name,tab)
	if not ok then
		return nil,pbstr
	end

	local pbmsgbuff = string.pack(">I2",name:len()) .. name .. pbstr
	return pbmsgbuff
end

function M.unpack(pbmsgbuff)
	assert(pbmsgbuff)
	local name_sz = (pbmsgbuff:byte(1) << 8) + pbmsgbuff:byte(2)
	local packname = pbmsgbuff:sub(3,3 + name_sz - 1)
	local pack_str = pbmsgbuff:sub(3 + name_sz)
	local ok,tab = M.decode(packname,pack_str)
	if not ok then
		return nil,tab
	end

	return packname,tab
end

return M