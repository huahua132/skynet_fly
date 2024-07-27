local M = {}

--------------------test1--------------
--[[
    测试不改变函数名，热更的情况
]]

--热更前
-- local function localfunc()
--     return "localfunc old"
-- end

--热更后
local function localfunc()
    return "localfunc new"
end

function M.localfunc()
    return localfunc()
end
--[[
    结论：可以热更
]]
------------------test1---------------

------------------test2---------------
--[[
    测试改变函数名，热更的情况
]]

--热更前
local function old_funcname()
    return "old_funcname"
end

--热更后
-- local function new_funcname()
--     return "new_funcname"
-- end

function M.change_func_name()
    --热更前
    -- return old_funcname()
    --热更后
    return new_funcname()
end
--[[
    结论：可以热更
]]
------------------test2---------------

return M