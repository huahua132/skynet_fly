local netpack_base = require "skynet-fly.netpack.netpack_base"
local file_util = require "skynet-fly.utils.file_util"
local protoc = require "skynet-fly.3rd.protoc"
local pb = require "pb"

local string = string
local pcall = pcall
local assert = assert
local tostring = tostring

local M = {}

local g_loaded = {}
local g_pack_id_name = {}   --协议号映射包名
--------------------------------------------------------------------------
--加载指定路径pb文件
--------------------------------------------------------------------------
function M.load(rootpath)
	for file_name,file_path,file_info in file_util.diripairs(rootpath) do
		if string.find(file_name,".proto",nil,true) then
			protoc:loadfile(file_path)
		end
	end

	--记录加载过的message名称
	for name,basename,type in pb.types() do
		if not string.find(name,".google.protobuf",nil,true) then
			g_loaded[name] = true
		end
	end

	return g_loaded
end
--------------------------------------------------------------------------
--按包名方式编码
--------------------------------------------------------------------------
function M.encode(name,body)
	assert(name)
	assert(body)
	if not g_loaded[name] then
		return nil,"encode not exists " .. name
	end

	return pcall(pb.encode,name,body)
end
--------------------------------------------------------------------------
--按包名方式解码
--------------------------------------------------------------------------
function M.decode(name,pstr)
	assert(name)
	assert(pstr)
	if not g_loaded[name] then
		return nil,"decode not exists " .. name
	end

	return pcall(pb.decode,name,pstr)
end
--------------------------------------------------------------------------
--按包名方式打包
--------------------------------------------------------------------------
M.pack = netpack_base.create_pack(M.encode)
--------------------------------------------------------------------------
--按包名方式解包
--------------------------------------------------------------------------
M.unpack = netpack_base.create_unpack(M.decode)


--------------------------------------------------------------------------
--设置协议号包名映射
--------------------------------------------------------------------------
function M.set_packname_id(packid, name)
	assert(g_loaded[name], "not exists name = " .. tostring(name))													   --包名不存在
	assert(not g_pack_id_name[packid], "is exists packid=>name = " .. tostring(packid) .. ':' .. tostring(g_pack_id_name[packid])) --已经有映射了

	g_pack_id_name[packid] = name
end
--------------------------------------------------------------------------
--按协议号方式编码
--------------------------------------------------------------------------
function M.encode_by_id(packid, packbody)
	assert(packid)
	assert(packbody)
	local name = g_pack_id_name[packid]
	if not name then
		return nil, "not exists packid = " .. packid
	end
	if not g_loaded[name] then
		return nil,"encode not exists " .. name
	end

	return pcall(pb.encode, name, packbody)
end
--------------------------------------------------------------------------
--按协议号方式解码
--------------------------------------------------------------------------
function M.decode_by_id(packid, pstr)
	assert(packid)
	assert(pstr)
	local name = g_pack_id_name[packid]
	if not name then
		return nil, "not exists packid = " .. packid
	end

	if not g_loaded[name] then
		return nil,"decode not exists " .. name
	end

	return pcall(pb.decode, name, pstr)
end

--------------------------------------------------------------------------
--按协议号方式打包
--------------------------------------------------------------------------
M.pack_by_id = netpack_base.create_pack_by_id(M.encode_by_id)
--------------------------------------------------------------------------
--按协议号方式解包
--------------------------------------------------------------------------
M.unpack_by_id = netpack_base.create_unpack_by_id(M.decode_by_id)

return M