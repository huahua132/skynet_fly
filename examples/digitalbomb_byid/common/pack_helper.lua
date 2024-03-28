local pb_netpack = require "skynet-fly.netpack.pb_netpack"
local msg_id = require "enum.msg_id"

local pairs = pairs

local M = {}

function M.set_packname_id()
    for packname, pack_id in pairs(msg_id) do
        pb_netpack.set_packname_id(pack_id, '.' .. packname:gsub("_","."))
    end
end

return M