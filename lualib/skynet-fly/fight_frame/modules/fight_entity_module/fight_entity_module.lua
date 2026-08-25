-- fight_entity_module World模块：管理实体和组件注册、创建、生命周期
-- 实体继承 fight_entity 基类（容器即实体）；_update_list 只含需每帧更新的实体（_has_update 判定）
local MODULE_NAME = "fight_entity_module"

-- 用 classic 定义实体模块
local classic = require "skynet-fly.classic"
local log = require "skynet-fly.log"
local fight_register_type = require "skynet-fly.fight_frame.fight_register_type"
local M = classic:extend()

function M:on_init()
    self._entities = {}
    self._entity_types = {}
    self._update_list = {}      -- 需每帧更新的实体（按 on_init 时 _has_update 判定）
    self._update_idx = {}       -- 实体id → _update_list 索引（swap-remove 用，删除 O(1)）
    self._pending_adds = {}
    self._pending_removes = {}
    self._next_entity_id = 1
    -- 实体移除帧同步事件名（可选注入：业务模块挂载后设置，nil 时不触发——框架默认不依赖业务事件）
    self._remove_entity_event_name = nil
end

function M:on_remove()
    for _, impl in pairs(self._entities) do
        if impl.on_remove then
            impl:on_remove()
        end
        impl:remove_components()
        impl._world = nil
    end
    self._entities = {}
    self._entity_types = {}
    self._update_list = {}
    self._update_idx = {}
    self._pending_adds = {}
    self._pending_removes = {}
    self._remove_entity_event_name = nil
end

function M:on_update()
    for _, impl in ipairs(self._update_list) do
        impl:update_components()      -- 容器遍历组件 on_update
        if impl.on_update then
            impl:on_update()
        end
    end
    -- 帧末统一 flush：create_entity/remove_entity 延迟到此处处理，避免碰撞回调 dispatch 中立即移除实体崩溃
    self:_flush_pending()
end

-- 创建实体（entity_type: 已注册的实体类型字符串；实体ID由模块内部递增分配）
-- classic 实例化：子类 new 须自调 super.new 链式构造（fight_entity 基类 new 初始化 id/type/components）
function M:create_entity(entity_type)
    if not entity_type or type(entity_type) ~= "string" then
        log.error(string.format("%s.create_entity: invalid entity_type [%s]", MODULE_NAME, tostring(entity_type)))
        return nil
    end
    local entity_class = fight_register_type.get("entity", entity_type)
    if not entity_class then
        log.error(string.format("%s.create_entity: entity_type [%s] not registered", MODULE_NAME, entity_type))
        return nil
    end
    local entity_id = self._next_entity_id   -- 内部递增分配实体 ID（不使用 DBNewGuid）
    self._next_entity_id = self._next_entity_id + 1
    local impl = entity_class(entity_id)
    impl._world = self._world
    -- 延迟到帧末 _flush_pending 统一装配（on_init + on_init_after）：调用方可先 setup 缓存参数，装配后应用
    self._pending_adds[#self._pending_adds + 1] = impl
    return impl
end

function M:_create_component(component_type, ...)
    local component_class = fight_register_type.get("component", component_type)
    if not component_class then
        log.error(string.format("%s._create_component: component_type [%s] not registered", MODULE_NAME, component_type))
        return nil
    end
    return component_class(...)
end

-- 移除实体：延迟到帧末 flush，避免 dispatch 中立即移除导致正在执行的方法崩溃
function M:remove_entity(entity_id)
    if not entity_id then
        log.error(string.format("%s.remove_entity: entity_id is nil", MODULE_NAME))
        return
    end
    self._pending_removes[#self._pending_removes + 1] = entity_id
end

function M:get_entity(entity_id)
    return self._entities[entity_id]
end

function M:get_entities_by_type(entity_type)
    local type_entities = self._entity_types[entity_type]
    if not type_entities then
        return {}
    end
    local result = {}
    for entity_id in pairs(type_entities) do
        result[#result + 1] = self._entities[entity_id]
    end
    return result
end

function M:get_entity_count()
    local count = 0
    for _ in pairs(self._entities) do
        count = count + 1
    end
    return count
end

-- 获取所有实体（表：entity_id → impl；供 AI/塔 搜索目标遍历用）
function M:get_all_entities()
    return self._entities
end

-- 获取需每帧更新的实体列表（调试/统计用）
function M:get_update_list()
    return self._update_list
end

-- 是否需每帧更新：实体自身/基类覆写 on_update，或任一组件有 on_update
-- fight_entity 基类的组件更新方法叫 update_components（on_update 未覆写则为 nil），不会误判
function M:_has_update(impl)
    if impl.on_update then
        return true
    end
    local components = impl.components
    if components then
        for _, comp in pairs(components) do
            if comp.on_update then
                return true
            end
        end
    end
    return false
end

function M:_do_add_entity(impl)
    if self._entities[impl.id] then
        log.warn(string.format("%s._do_add_entity: entity [%s] already exists", MODULE_NAME, impl.id))
        return
    end
    self._entities[impl.id] = impl
    if not self._entity_types[impl.entity_type] then
        self._entity_types[impl.entity_type] = {}
    end
    self._entity_types[impl.entity_type][impl.id] = true

    if impl.on_init then
        impl:on_init()   -- 装配组件（add_component 即时触发组件 on_init）
    end
    if impl.on_init_after then
        impl:on_init_after()   -- 组件装配完成后回调，此时 get_component 可安全获取
    end
    if self:_has_update(impl) then
        local idx = #self._update_list + 1
        self._update_list[idx] = impl
        self._update_idx[impl.id] = idx
    end
end

function M:_do_remove_entity(entity_id)
    local impl = self._entities[entity_id]
    if not impl then
        return
    end
    if impl.on_remove then
        impl:on_remove()
    end
    impl:remove_components()
    impl._world = nil

    self._entities[entity_id] = nil
    -- 帧同步采集：移除实体（entity_id, team；frame_sync_module 监听收集）
    -- 注意：此处为帧末 _flush_pending 汇聚点，实体已从 _entities 移除但 impl 引用仍可用
    -- 事件名由业务模块挂载后注入（self._remove_entity_event_name），默认 nil 不触发（框架层不依赖业务事件）
    local remove_ev = self._remove_entity_event_name
    if remove_ev then
        local world = self._world
        if world and world.event_module and world.event_module.trigger_event then
            world.event_module:trigger_event(remove_ev, entity_id, impl.owner or 0)
        end
    end
    -- swap-remove（O(1)，更新列表顺序无关）：用 _update_idx 定位被删实体，末尾元素填补被删位置
    local idx = self._update_idx[entity_id]
    if idx then
        local last = self._update_list[#self._update_list]
        self._update_list[idx] = last
        self._update_list[#self._update_list] = nil
        if last then
            self._update_idx[last.id] = idx   -- 被移动的末尾元素更新索引
        end
        self._update_idx[entity_id] = nil
    end
    local type_entities = self._entity_types[impl.entity_type]
    if type_entities then
        type_entities[entity_id] = nil
        if not next(type_entities) then
            self._entity_types[impl.entity_type] = nil
        end
    end
end

function M:_flush_pending()
    for _, entity_id in ipairs(self._pending_removes) do
        self:_do_remove_entity(entity_id)
    end
    self._pending_removes = {}

    for _, impl in ipairs(self._pending_adds) do
        self:_do_add_entity(impl)
    end
    self._pending_adds = {}
end

return M
