-- fight_register_type 类型注册缓存
-- 职责：集中维护实体/组件等类型的注册缓存，提供 register/get 接口。
-- 用途：替代原来依赖游戏宿主全局函数 fight_register_type/FightGetRegisterType 的方式，
--       组件/实体在本帧框架内自注册，_create_component/create_entity 通过同一缓存查询。
--
-- 用法：
--   local fight_register_type = require "skynet-fly.fight_frame.fight_register_type"
--   fight_register_type.register("component", type_name, class_name)
--   local cls = fight_register_type.get("component", type_name)

local g_cache = {}   -- kind -> { name -> class }

local M = {}

---注册类型到缓存（同名重复注册直接覆盖）
---@param kind string 类型归属（entity / component 等）
---@param name string 类型名
---@param cls table 类对象
function M.register(kind, name, cls)
    if not kind or not name or not cls then return end
    if not g_cache[kind] then g_cache[kind] = {} end
    g_cache[kind][name] = cls
end

---查询已注册类型
---@param kind string 类型归属
---@param name string 类型名
---@return table|nil
function M.get(kind, name)
    if not kind or not name then return nil end
    local k = g_cache[kind]
    if not k then return nil end
    return k[name]
end

return M
