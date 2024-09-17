local pb_netpack = require "skynet-fly.netpack.pb_netpack"
local sp_netpack = require "skynet-fly.netpack.sp_netpack"
local string_util = require "skynet-fly.utils.string_util"
local msg_id = require "enum.msg_id"

local pairs = pairs

local M = {}

function M.set_packname_id()
    for packname, pack_id in pairs(msg_id) do
        pb_netpack.set_packname_id(pack_id, '.' .. packname:gsub("_","."))
    end
end

function M.set_sp_packname_id()
    for packname, pack_id in pairs(msg_id) do
        local sp_str = string_util.split(packname, '_')
        sp_netpack.set_packname_id(pack_id, sp_str[2])
    end
end

return M