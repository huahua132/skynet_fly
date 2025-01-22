---#API
---#content ---
---#content title: 旧数据处理
---#content date: 2024-06-29 22:00:00
---#content categories: ["skynet_fly API 文档","热更脚本"]
---#content category_bar: true
---#content tags: [skynet_fly_api]
---#content ---
---#content [state_data](https://github.com/huahua132/skynet_fly/blob/master/lualib/skynet-fly/hotfix/state_data.lua)

---#content不想被热更重置的状态数据，我们可以通过这个模块来分配表
local assert = assert
local debug_getinfo = debug.getinfo

local g_map = {}

local M = {}

---#desc 分配一个局部表
---@param tabname string 表名
---@return table
function M.alloc_table(tabname)
    local info = debug_getinfo(2,"S")
    local key = info.short_src .. '.' .. tabname        --关联调用处的文件路径，避免多模块tabname冲突问题
    return M.global_table(key)
end

---#desc 分配一个公共表
---@param tabname string 表名
---@return table
function M.global_table(tab_name)
    if not g_map[tab_name] then
        g_map[tab_name] = {}
    end
    return g_map[tab_name]
end

return M
