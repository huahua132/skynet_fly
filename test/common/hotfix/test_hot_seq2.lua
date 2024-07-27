local test_hot_seq1 = hotfix_require("common.hotfix.test_hot_seq1")
local hot_seq2_interface = hotfix_require("common.hotfix.hot_seq2_interface")
local log = require "skynet-fly.log"

local M = {}

--------------------------test1------------------------
--[[
    引用了 seq1 的变量，热更后，应该正确使用新版本
]]
local a = test_hot_seq1.a

function M.test1()
    return a, test_hot_seq1.a
end

--[[
    预期结果:
    a是旧版本，test_hot_seq1.a是新版本
]]
--------------------------test1------------------------

--------------------------test2------------------------
--[[
    重写接口，预期可以更新
]]
--热更前
function hot_seq2_interface.test2()
    return "old test2"
end

--热更后
-- function hot_seq2_interface.test2()
--     return "new test2"
-- end

--[[
    预期结果:可以热更
]]

function M.hotfix()
    log.info("执行热更了 ",MODULE_NAME)
    error(222)
end

return M