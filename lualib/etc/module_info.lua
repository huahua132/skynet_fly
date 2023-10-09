local M = {}

local g_cfg = nil           --可热更模块配置
local g_base_info = {}      --基本信息

function M.set_cfg(cfg)
    g_cfg = cfg
end

function M.get_cfg()
    return g_cfg
end

function M.set_base_info(base_info)
    g_base_info = base_info
end

function M.get_base_info()
    return g_base_info
end

return M