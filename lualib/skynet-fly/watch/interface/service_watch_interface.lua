
local skynet = require "skynet"

local setmetatable = setmetatable

local M = {}
local mt = {__index = M}
--skynet服务 接口 传递别名或者handle_id
function M:new(name_or_handle)
    local t = {
        server = name_or_handle
    }

    setmetatable(t, mt)
    return t
end

function M:send(...)
    skynet.send(self.server, 'lua', ...)
end

function M:call(...)
    return skynet.call(self.server, 'lua', ...)
end

return M