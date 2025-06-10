local netpack_base = require "skynet-fly.netpack.netpack_base"
local file_util = require "skynet-fly.utils.file_util"
local sproto = require "sproto"
local parser = require "sprotoparser"

local string = string
local pcall = pcall
local assert = assert
local tostring = tostring
local io = io

local g_instance_map = {}

local M = {}

function M.new(name)
    local m_name = name or ""
    local m_is_pcode = false
    local m_sp = nil
    local m_pack_id_name = {}   --协议号映射包名
    local m_sp_str = ""

    local ret_M = {}
    --------------------------------------------------------------------------
    --加载指定路径pb文件
    --------------------------------------------------------------------------
    function ret_M.load(rootpath)
        for file_name,file_path,file_info in file_util.diripairs(rootpath) do
            if string.find(file_name,".sproto",nil,true) then
                m_sp_str = m_sp_str .. io.open(file_path, 'r'):read('a') .. '\n'
            end
        end
        local pbin = parser.parse(m_sp_str, m_name)
        m_sp = sproto.new(pbin)
    end

    --------------------------------------------------------------------------
    --设置已压缩方式打包解包
    --------------------------------------------------------------------------
    function ret_M.set_pcode()
        m_is_pcode = true
    end

    --------------------------------------------------------------------------
    --按包名方式编码
    --------------------------------------------------------------------------
    function ret_M.encode(name, body)
        assert(name)
        assert(body)

        if not m_is_pcode then
            return pcall(m_sp.encode, m_sp, name, body)
        else
            return pcall(m_sp.pencode, m_sp, name, body)
        end
    end

    --------------------------------------------------------------------------
    --按包名方式解码
    --------------------------------------------------------------------------
    function ret_M.decode(name, pstr)
        assert(name)
        assert(pstr)
    
        if not m_is_pcode then
            return pcall(m_sp.decode, m_sp, name, pstr)
        else
            return pcall(m_sp.pdecode, m_sp, name, pstr)
        end
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
            return nil, "not exists packid = " .. packid
        end
    
        if not m_is_pcode then
            return pcall(m_sp.encode, m_sp, name, body)
        else
            return pcall(m_sp.pencode, m_sp, name, body)
        end
    end
    --------------------------------------------------------------------------
    --按协议号方式解码
    --------------------------------------------------------------------------
    function ret_M.decode_by_id(packid, pstr)
        assert(packid)
        assert(pstr)
        local name = m_pack_id_name[packid]
        if not name then
            return nil, "not exists packid = " .. packid
        end
        
        if not m_is_pcode then
            return pcall(m_sp.decode, m_sp, name, pstr)
        else
            return pcall(m_sp.pdecode, m_sp, name, pstr)
        end
    end
    --------------------------------------------------------------------------
    --按协议号方式打包
    --------------------------------------------------------------------------
    ret_M.pack_by_id = netpack_base.create_pack_by_id(ret_M.encode_by_id)
    --------------------------------------------------------------------------
    --按协议号方式解包
    --------------------------------------------------------------------------
    ret_M.unpack_by_id = netpack_base.create_unpack_by_id(ret_M.decode_by_id)
    --------------------------------------------------------------------------
    --按rpc方式打包
    --------------------------------------------------------------------------
    ret_M.pack_by_rpc = netpack_base.create_pack_by_rpc(ret_M.encode_by_id)
    --------------------------------------------------------------------------
    --按rpc方式解包
    --------------------------------------------------------------------------
    ret_M.unpack_by_rpc = netpack_base.create_unpack_by_rpc(ret_M.decode_by_id)

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