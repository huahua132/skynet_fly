
local setmetatable = setmetatable

local M = {}
local mt = {__index = M}
--可热更模块接口
function M:new(contriner_client)
    local t = {
        cli = contriner_client
    }

    setmetatable(t, mt)
    return t
end

function M:send(...)
    return self.cli:mod_send(...)
end

function M:call(cmd, ...)
    return self.cli:mod_call(...)
end

return M