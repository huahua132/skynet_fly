local skynet = require "skynet"

local M = {}

local g_frpc_server = nil

local function get_frpc_addr()
    if g_frpc_server then
        return g_frpc_server
    end
    g_frpc_server = skynet.queryservice('frpc_server')
    return g_frpc_server
end

--远程推送
function M.publish(channel_name, ...)
    local msg, sz = skynet.pack(...)
    local addr = get_frpc_addr()
    skynet.send(addr, 'lua', "publish", channel_name, msg, sz)
end

--远程推送同步数据
function M.pubsyn(channel_name, ...)
    local msg, sz = skynet.packstring(...)
    local addr = get_frpc_addr()
    skynet.send(addr, 'lua', "pubsyn", channel_name, msg, sz)
end

return M