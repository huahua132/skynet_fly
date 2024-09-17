--不想热更的状态数据
local assert = assert
local debug_getinfo = debug.getinfo

local g_map = {}

local M = {}

-- 分配一个表
function M.alloc_table(tabname)
    local info = debug_getinfo(2,"S")
    local key = info.short_src .. '.' .. tabname        --关联调用处的文件路径，避免多模块tabname冲突问题
    return M.global_table(key)
end

-- 分配一个公共表
function M.global_table(tab_name)
    if not g_map[tab_name] then
        g_map[tab_name] = {}
    end
    return g_map[tab_name]
end

return M
