---#API
---#content ---
---#content title: 模块信息与配置
---#content date: 2024-06-29 22:00:00
---#content categories: ["skynet_fly API 文档","可热更服务模块"]
---#content category_bar: true
---#content tags: [skynet_fly_api]
---#content ---
---#content [module_info](https://github.com/huahua132/skynet_fly/blob/master/lualib/skynet-fly/etc/module_info.lua)

local M = {}

local g_cfg = nil           --可热更模块配置
local g_base_info = {}      --基本信息

function M.set_cfg(cfg)
    g_cfg = cfg
end

---#desc 获取load_mods default_cfg|mod_cfgs 绑定的配置信息
---@return table
function M.get_cfg()
    return g_cfg
end

function M.set_base_info(base_info)
    g_base_info = base_info
end

---#desc 获取可热更模块的基础信息 [module_name]可热更模块名 [index]启动索引 [launch_date]启动日期 [launch_time]启动时间戳 [version]版本号 [is_record_on]是否记录录像
---@return table
function M.get_base_info()
    return g_base_info
end

return M