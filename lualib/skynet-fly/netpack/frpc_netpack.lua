
local netpack_base = require "skynet-fly.netpack.netpack_base"
local skynet = require "skynet"
local log = require "skynet-fly.log"

local spack = string.pack
local sfind = string.find

local M = {}

--------------------------------------------------------------------------
--这里是集群的消息包处理
--------------------------------------------------------------------------
function M.encode_by_id(packid, packbody)
    local session_id = packbody.session_id          --session_id
    local mod_num = packbody.mod_num
    local module_name = packbody.module_name        --xxx_m               对方的xxx_m
    local lua_msgs = packbody.lua_msgs              --lua消息包

    return true, spack(">I4", session_id) .. spack(">i8", mod_num) .. module_name .. '#' .. lua_msgs
end

function M.decode_by_id(packid, pstr)
    local session_id = (pstr:byte(1) << 24) + (pstr:byte(2) << 16) + (pstr:byte(3) << 8) + pstr:byte(4)
    local mod_num = (pstr:byte(5) << 56) + (pstr:byte(6) << 48) + (pstr:byte(7) << 40) + (pstr:byte(8) << 32) + (pstr:byte(9) << 24) + (pstr:byte(10) << 16) + (pstr:byte(11) << 8) + pstr:byte(12)
    local b,e = sfind(pstr, '#', 13, true)
    if not b then
        log.info("invaild ", pstr)
        return
    end

    local module_name = pstr:sub(13, b - 1)
    local lua_msgs = pstr:sub(e + 1)

    local packbody = {
        session_id = session_id,
        mod_num = mod_num,
        module_name = module_name,
        lua_msgs = lua_msgs
    }

    return true, packbody
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