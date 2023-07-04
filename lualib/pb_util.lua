local util = require "util"
local protoc = require "protoc"
local pb = require "pb"
local log = require "log"

local string = string
local pcall = pcall
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

	return pcall(pb.encode,name,tab)
end

function M.decode(name,pstr)
	assert(name)
	assert(pstr)
	if not g_loaded[name] then
		return nil,"decode not exists " .. name
	end

	return pcall(pb.decode,name,pstr)
end

return M