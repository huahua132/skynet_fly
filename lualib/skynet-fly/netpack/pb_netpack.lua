local netpack_base = require "skynet-fly.netpack.netpack_base"
local file_util = require "skynet-fly.utils.file_util"
local protoc = require "skynet-fly.3rd.protoc"
local pb = require "pb"

local string = string
local pcall = pcall
local assert = assert
local tostring = tostring
local setmetatable = setmetatable

local g_instance_map = {}

local M = {}

function M.new(name)
	local m_name = name or ""
	local m_loaded = {}
	local m_pack_id_name = {}
	
	local ret_M = {}
	--------------------------------------------------------------------------
	--加载指定路径pb文件
	--------------------------------------------------------------------------
	function ret_M.load(rootpath)
		for file_name,file_path,file_info in file_util.diripairs(rootpath) do
			if string.find(file_name,".proto",nil,true) then
				protoc:loadfile(file_path)
			end
		end
	
		--记录加载过的message名称
		for name,basename,type in pb.types() do
			if not string.find(name,".google.protobuf",nil,true) then
				m_loaded[name] = true
			end
		end
	
		return m_loaded
	end
	--------------------------------------------------------------------------
	--按包名方式编码
	--------------------------------------------------------------------------
	function ret_M.encode(name,body)
		assert(name)
		assert(body)
		if not m_loaded[name] then
			return nil, m_name .. " encode not exists " .. name
		end

		return pcall(pb.encode,name,body)
	end
	--------------------------------------------------------------------------
	--按包名方式解码
	--------------------------------------------------------------------------
	function ret_M.decode(name, pstr)
		assert(name)
		assert(pstr)
		if not m_loaded[name] then
			return nil, m_name .. "decode not exists " .. name
		end

		return pcall(pb.decode,name,pstr)
	end

	--------------------------------------------------------------------------
	--按包名方式打包
	--------------------------------------------------------------------------
	ret_M.pack = netpack_base.create_pack(ret_M.encode)

	--------------------------------------------------------------------------
	--按包名方式解包
	--------------------------------------------------------------------------
	ret_M.unpack = netpack_base.create_unpack(ret_M.decode)

	--------------------------------------------------------------------------
	--设置协议号包名映射
	--------------------------------------------------------------------------
	function ret_M.set_packname_id(packid, name)
		assert(m_loaded[name], m_name .. " not exists name = " .. tostring(name))													   --包名不存在
		assert(not m_pack_id_name[packid], m_name .. " is exists packid=>name = " .. tostring(packid) .. ':' .. tostring(m_pack_id_name[packid])) --已经有映射了
	
		m_pack_id_name[packid] = name
	end

	--------------------------------------------------------------------------
	--按协议号方式编码
	--------------------------------------------------------------------------
	function ret_M.encode_by_id(packid, body)
		assert(packid)
		assert(body)
		local name = m_pack_id_name[packid]
		if not name then
			return nil, m_name .. " not exists packid = " .. packid
		end
		if not m_loaded[name] then
			return nil,m_name .. " encode not exists " .. name
		end
	
		return pcall(pb.encode, name, body)
	end

	--------------------------------------------------------------------------
	--按协议号方式解码
	--------------------------------------------------------------------------
	function ret_M.decode_by_id(packid, pstr)
		assert(packid)
		assert(pstr)
		local name = m_pack_id_name[packid]
		if not name then
			return nil, m_name .. " not exists packid = " .. packid
		end

		if not m_loaded[name] then
			return nil, m_name .. " decode not exists " .. name
		end

		return pcall(pb.decode, name, pstr)
	end

	--------------------------------------------------------------------------
	--按协议号方式打包
	--------------------------------------------------------------------------
	ret_M.pack_by_id = netpack_base.create_pack_by_id(ret_M.encode_by_id)

	--------------------------------------------------------------------------
	--按协议号方式解包
	--------------------------------------------------------------------------
	ret_M.unpack_by_id = netpack_base.create_unpack_by_id(ret_M.decode_by_id)

	return ret_M
end

--常驻实例
function M.instance(name)
	if not g_instance_map[name] then
		g_instance_map[name] = M.new(name)
	end

	return g_instance_map[name]
end

local g_default = M.new('default')

local mata = {__index = g_default}
setmetatable(M, mata)

return M