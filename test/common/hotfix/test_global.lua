local log = require "skynet-fly.log"

local M = {}
------------------------test1------------------------
--[[
    测试对全局变量的影响，预期是不能改变全局环境
]]
--热更前
--test_global_a = 1

--热更后
test_global_a = 200

function M.test1()
    return test_global_a
end

--[[
    预期结果:不改变全局变量
]]
------------------------test1------------------------

------------------------test2------------------------
--[[
    新增全局变量,预期不能新增
]]
--热更前
test_global_b = nil

--热更后
test_global_b = 100

function M.test2()
    return test_global_b
end

--[[
    预期结果:不能新增
]]
------------------------test2------------------------

------------------------test3------------------------
--[[
    不能热更全局函数
]]

--热更前 
-- function global_func()
--     return "old_global_func"
-- end

--热更后
function global_func()
    return "new_global_func"
end

function M.test3()
    return global_func()
end

--[[
    预期结果:不能热更
]]

------------------------test3------------------------

------------------------test4------------------------
--[[
    新增全局函数
]]

--热更前
global_func_a = nil

--热更后
global_func_a = function()

end

function M.test4()
    return global_func_a
end

--[[
    预期结果:不能热更
]]
return M