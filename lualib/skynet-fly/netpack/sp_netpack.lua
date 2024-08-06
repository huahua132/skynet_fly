local netpack_base = require "skynet-fly.netpack.netpack_base"
local file_util = require "skynet-fly.utils.file_util"
local sproto = require "sproto"

local string = string
local pcall = pcall
local assert = assert
local tostring = tostring
local io = io

local M = {}

local g_is_pcode = false
local g_sp = nil

local g_pack_id_name = {}   --协议号映射包名
--------------------------------------------------------------------------
--加载指定路径pb文件
--------------------------------------------------------------------------
function M.load(rootpath)
    local sp_str = ""
	for file_name,file_path,file_info in file_util.diripairs(rootpath) do
		if string.find(file_name,".sproto",nil,true) then
			sp_str = sp_str .. io.open(file_path, 'r'):read('a') .. '\n'
		end
	end

    g_sp = sproto.parse(sp_str)
end

--设置已压缩方式打包解包
function M.set_pcode()
    g_is_pcode = true
end
--------------------------------------------------------------------------
--按包名方式编码
--------------------------------------------------------------------------
function M.encode(name,body)
	assert(name)
	assert(body)

    if not g_is_pcode then
        return pcall(g_sp.encode, g_sp, name, body)
    else
        return pcall(g_sp.pencode, g_sp, name, body)
    end
end
--------------------------------------------------------------------------
--按包名方式解码
--------------------------------------------------------------------------
function M.decode(name,pstr)
	assert(name)
	assert(pstr)

    if not g_is_pcode then
        return pcall(g_sp.decode, g_sp, name, pstr)
    else
        return pcall(g_sp.pdecode, g_sp, name, pstr)
    end
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
function M.set_packname_id(packid, name)												   --包名不存在
	assert(not g_pack_id_name[packid], "is exists packid=>name = " .. tostring(packid) .. ':' .. tostring(g_pack_id_name[packid])) --已经有映射了

	g_pack_id_name[packid] = name
end
--------------------------------------------------------------------------
--按协议号方式编码
--------------------------------------------------------------------------
function M.encode_by_id(packid, body)
	assert(packid)
	assert(body)
	local name = g_pack_id_name[packid]
	if not name then
		return nil, "not exists packid = " .. packid
	end

    if not g_is_pcode then
        return pcall(g_sp.encode, g_sp, name, body)
    else
        return pcall(g_sp.pencode, g_sp, name, body)
    end
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
    
    if not g_is_pcode then
        return pcall(g_sp.decode, g_sp, name, pstr)
    else
        return pcall(g_sp.pdecode, g_sp, name, pstr)
    end
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