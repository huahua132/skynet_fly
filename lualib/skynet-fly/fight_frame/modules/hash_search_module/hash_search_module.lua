-- hash_search_module 空间哈希搜索模块（C# HashSearchModule 移植）
-- World 模块：管理多个搜索实例（search_type → HashSearchInstance），注册/注销/查询搜索对象，供 AI/防御塔寻敌
local classic = require "skynet-fly.classic"
local hash_search_instance = hotfix_require "skynet-fly.fight_frame.hash_search.hash_search_instance"

-- 建筑搜索类型基值（对齐 hash_search_ctrl：Building=10，BuildingTeamN=10+N）
local BUILDING_SEARCH_TYPE_BASE = 10

local hash_search_module = classic:extend()

function hash_search_module:on_init()
    self._instances = {}   -- search_type → HashSearchInstance
    self._search_obj_map = {} -- 实体id → 搜索对象包装（反查）
    self._search_obj_buckets = {} -- 实体id → 注册的 search_type 集合（供 update_entity 精准更新）
    self._nearest_cache = {} -- get_nearest 最近对象缓存（search_type → { obj, dead=true }，惰性建立）
    -- 建筑桶版本号：建筑注册/注销时自增，供上层（hero AI 最近建筑缓存）感知建筑集合变化
    self._building_epoch = 0
end

function hash_search_module:on_remove()
    self._instances = {}
    self._search_obj_map = {}
    self._search_obj_buckets = {}
    self._nearest_cache = {}
    self._building_epoch = 0
end

-- 建筑桶版本号：建筑集合变化计数，调用方记录此值，变化则缓存失效
function hash_search_module:get_building_epoch()
    return self._building_epoch
end

-- ============ 实例管理 ============

-- 初始化搜索实例（C# InitSearchInstance）
-- search_type: 数字搜索类型；init_capacity: 初始容量（占位，Lua 表动态扩容）
function hash_search_module:init_search_instance(search_type, init_capacity)
    if self._instances[search_type] then return end
    local instance = hash_search_instance()
    instance.search_type = search_type
    self._instances[search_type] = instance
end

-- 获取搜索实例（C# GetSearchInstance）
function hash_search_module:get_search_instance(search_type)
    return self._instances[search_type]
end

-- 获取搜索接口（C# GetSearch：兼容客户端返回 ISearch）
function hash_search_module:get_search(search_type)
    return self._instances[search_type]
end

-- ============ 搜索对象适配 ============

-- 包装实体为搜索对象（id + get_pos）；位置直读 position_comp 字段（x/y），取不到时回退方法读取
function hash_search_module:_adapt_search_obj(entity)
    if not entity then return nil end
    local wrapper = self._search_obj_map[entity.id]
    if wrapper then return wrapper end

    local pos_comp = entity:get_component("zc_position_comp")
    if pos_comp then
        wrapper = {
            id = entity.id,
            entity = entity,
            _pos_comp = pos_comp,
            get_pos = function(self)
                return self._pos_comp.x, self._pos_comp.y
            end,
        }
    else
        wrapper = {
            id = entity.id,
            entity = entity,
            get_pos = function(self)
                local pc = self.entity:get_component("zc_position_comp")
                if pc then
                    return pc:get_position()
                end
                return 0, 0
            end,
        }
    end
    self._search_obj_map[entity.id] = wrapper
    return wrapper
end

-- ============ 注册/注销/更新 ============

-- 注册搜索对象（C# HashSearchCtrl.RegisterSearchObj 简化：注册到全部 + 队伍桶）
-- entity: 实体 impl；search_type: 基础类型（如 Infantry/Building）；team: 队伍号（>0 注册队伍桶）
function hash_search_module:register_search_obj(entity, search_type, team)
    if not entity or not search_type then return end
    local wrapper = self:_adapt_search_obj(entity)
    local base_instance = self._instances[search_type]
    if base_instance then
        base_instance:register_search_obj(wrapper)
    end
    local buckets = self._search_obj_buckets[entity.id]   -- 记录注册桶，供 update_entity 精准更新
    if not buckets then
        buckets = {}
        self._search_obj_buckets[entity.id] = buckets
    end
    buckets[search_type] = true
    -- 队伍专属桶：InfantryTeamN = 2 + team
    if team and team > 0 then
        local team_type = search_type + team
        local team_instance = self._instances[team_type]
        if team_instance then
            team_instance:register_search_obj(wrapper)
        end
        buckets[team_type] = true
    end
    -- 新对象进桶 → 失效最近对象缓存（新对象可能比缓存对象更近）
    self._nearest_cache[search_type] = nil
    if team and team > 0 then
        self._nearest_cache[search_type + team] = nil
    end
    -- 建筑注册 → 自增建筑桶版本号（上层"最近建筑"缓存据此失效）
    if search_type >= BUILDING_SEARCH_TYPE_BASE then
        self._building_epoch = self._building_epoch + 1
    end
end

-- 注销搜索对象（C# HashSearchCtrl.UnRegisterSearchObj）
function hash_search_module:unregister_search_obj(entity, search_type, team)
    if not entity or not search_type then return end
    local wrapper = self._search_obj_map[entity.id]
    if not wrapper then return end

    local base_instance = self._instances[search_type]
    if base_instance then
        base_instance:unregister_search_obj(wrapper)
    end
    if team and team > 0 then
        local team_type = search_type + team
        local team_instance = self._instances[team_type]
        if team_instance then
            team_instance:unregister_search_obj(wrapper)
        end
    end
    -- 清理注册桶记录（空则删）
    local buckets = self._search_obj_buckets[entity.id]
    if buckets then
        buckets[search_type] = nil
        if team and team > 0 then buckets[search_type + team] = nil end
        if not next(buckets) then self._search_obj_buckets[entity.id] = nil end
    end
    self._search_obj_map[entity.id] = nil
    -- 对象从桶移除 → 失效其所在桶的最近对象缓存（可能缓存了本对象或"无"状态）
    self._nearest_cache[search_type] = nil
    if team and team > 0 then
        self._nearest_cache[search_type + team] = nil
    end
    -- 建筑注销 → 自增建筑桶版本号（上层"最近建筑"缓存据此失效）
    if search_type >= BUILDING_SEARCH_TYPE_BASE then
        self._building_epoch = self._building_epoch + 1
    end
end

-- 更新搜索对象网格（位置变化后调用，C# UpdateSearchObj；单桶）
function hash_search_module:update_search_obj(entity, search_type, team)
    if not entity or not search_type then return false end
    local wrapper = self._search_obj_map[entity.id]
    if not wrapper then return false end

    local success = false
    local base_instance = self._instances[search_type]
    if base_instance then
        success = base_instance:update_search_obj(wrapper) or success
    end
    if team and team > 0 then
        local team_type = search_type + team
        local team_instance = self._instances[team_type]
        if team_instance then
            success = team_instance:update_search_obj(wrapper) or success
        end
    end
    return success
end

-- 精准更新实体的网格位置（实体移动后调用）：更新其在所有已注册桶中的归属网格
-- 替代"调用方需知道 search_type/team"的 update_search_obj；桶记录在 register_search_obj 时维护
function hash_search_module:update_entity(entity)
    if not entity or not entity.id then return false end
    local buckets = self._search_obj_buckets[entity.id]
    if not buckets then return false end
    local wrapper = self._search_obj_map[entity.id]
    if not wrapper then return false end

    local success = false
    for search_type in pairs(buckets) do
        local instance = self._instances[search_type]
        if instance then
            success = instance:update_search_obj(wrapper) or success
        end
    end
    return success
end

-- ============ 查询 ============

-- 是否范围内有对象（C# IsHaveInRange）
function hash_search_module:is_have_in_range(search_type, pos_x, pos_y, radius, angle, forward_x, forward_z)
    local instance = self._instances[search_type]
    if not instance then return false end
    return instance:is_have_in_range(pos_x, pos_y, radius, angle, forward_x, forward_z)
end

-- 获取最近对象（C# GetNearest）：缓存"最近命中"作 hint_obj 种子传给实例搜索，命中则省螺旋扫描；
-- radius 语义不变（种子按当前查询点重新判定距离），跨 search_type 不共享缓存
function hash_search_module:get_nearest(search_type, pos_x, pos_y, radius, angle, forward_x, forward_z)
    local instance = self._instances[search_type]
    if not instance then return nil end
    if angle and angle > 0 then
        return instance:get_nearest(pos_x, pos_y, radius, angle, forward_x, forward_z)   -- 带扇形朝向：不走缓存
    end

    local cache = self._nearest_cache[search_type]
    if not cache then
        cache = {}
        self._nearest_cache[search_type] = cache
    end
    -- 缓存命中：上次命中对象存活且仍在桶内 → 作种子传给实例（省螺旋扫描，精度不变）
    if cache.obj and not cache.dead
        and instance._all_search_obj_dict[cache.obj.id] == cache.obj then
        local nearest = instance:get_nearest(pos_x, pos_y, radius, nil, nil, nil, cache.obj)
        cache.obj = nearest   -- 刷新缓存（若有更近对象则换新）
        return nearest
    end
    cache.obj = nil
    cache.dead = nil

    local nearest = instance:get_nearest(pos_x, pos_y, radius, angle, forward_x, forward_z)
    if nearest then
        cache.obj = nearest
        cache.dead = false
    else
        cache.dead = true   -- 记录"无命中"（避免下次空转搜索）；下次注册/注销失效
    end
    return nearest
end

-- 遍历范围内对象（C# ForeachRange）
function hash_search_module:foreach_range(search_type, pos_x, pos_y, radius, action, angle, forward_x, forward_z)
    local instance = self._instances[search_type]
    if not instance then return end
    instance:foreach_range(pos_x, pos_y, radius, action, angle, forward_x, forward_z)
end

return hash_search_module
