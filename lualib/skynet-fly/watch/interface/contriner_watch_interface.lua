local contriner_client = require "skynet-fly.client.contriner_client"
local setmetatable = setmetatable

local M = {}
local mt = {__index = M}
--可热更模块接口
function M:new(mod_name, instance_name)
    local t = {
        cli = contriner_client:new(mod_name, instance_name)
    }

    setmetatable(t, mt)
    return t
end

function M:send(...)
    return self.cli:mod_send(...)
end

function M:call(...)
    return self.cli:mod_call(...)
end

return M