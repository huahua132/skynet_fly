------------------------------test1-------------------------
--测试热更局部变量的情况

--热更前
local a = 1
local tab = {b = 1}

--热更后
-- local a = 100
-- local tab = {a = 100}

local M = {}

--函数直接应用的情况
function M.hello()
    return "heelo " .. a, tab
end

--[[
    结论: 可以热更
]]
------------------------------test1-------------------------

------------------------------test2-------------------------
--[[
    --返回闭包函数
]]
function M.create_func()
    --热更前
    -- return function()
    --     return "heelo a"
    -- end
    --热更后
    return function()
        return "heelo b"
    end
end

--[[
    结论: 之前已经被创建的匿名函数没法热更，因为已经不会经过 create_func了
]]
------------------------------test2-------------------------

return M