--不想热更的状态数据
local assert = assert
local debug_getinfo = debug.getinfo

local g_map = {}

local M = {}

function M.alloc_table(tabname)
    local info = debug_getinfo(2,"S")
    local key = info.short_src .. '.' .. tabname        --关联调用处的文件路径，避免多模块tabname冲突问题
    if not g_map[key] then
        g_map[key] = {}
    end
    
    return g_map[key]
end

return M