local queue = require "skynet.queue"

local setmetatable = setmetatable
local assert = assert

local M = {}
local mata = {__index = M}

function M:new(cap)
    assert(cap > 0)
    local t = {
        cap = cap,
        queue_list = {}
    }

    for i = 1, cap do
        t.queue_list[i] = queue()
    end

    setmetatable(t, mata)
    return t
end

function M:exec(mod_num, func, ...)
    local index = mod_num % self.cap + 1
    local queue = self.queue_list[index]
    return queue(func, ...)
end

return M