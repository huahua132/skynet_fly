local state_data = require "skynet-fly.hotfix.state_data"

local state_map = state_data.alloc_table("state_map")

local M = {}

-------------------------------test1----------------------------
--[[
    有些状态数据，我们并不想随着热更被重置
]]

function M.test1()
    if not state_map.a then
        state_map.a = 0
    end
    state_map.a = state_map.a + 1
    return state_map.a
end

--[[
    预期结果: 热更后数据不能被重置
]]
return M