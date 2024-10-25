---------------------------更新前----------------------

local M = {}

function M.hello()
    return "hello skynet-fly"
end

return M


---------------------------第一次热更修改----------------------
--[[
local M = {}

function M.hello()
    return "hello skynet-fly>>>>>>1"
end

return M
]]
---------------------------第二次热更修改----------------------
--[[
local M = {}

function M.hello()
    return "hello skynet-fly>>>>>>2"
end

return M
]]