local skynet = require "skynet"

local M = {}

--远程推送
function M.publish(channel_name, ...)
    local msg, sz = skynet.pack(...)
    skynet.send('.frpc_server', 'lua', "publish", channel_name, msg, sz)
end

--远程推送同步数据
function M.pubsyn(channel_name, ...)
    local msg, sz = skynet.packstring(...)
    skynet.send('.frpc_server', 'lua', "pubsyn", channel_name, msg, sz)
end

return M