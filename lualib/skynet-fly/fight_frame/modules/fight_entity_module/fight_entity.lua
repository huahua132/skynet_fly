-- fight_entity 所有实体的基类（原 entity 数据容器 + 业务对象合并）
-- 实体通过 classic：fight_entity:extend() 继承本基类（子类可覆写 new，须自调 super.new 链式构造）：
--   * 容器能力：components/_update_components + add_component/get_component/has_component/remove_component
--   * 组件装配：实体 on_init 里 self:add_component(...)（组件即时 on_init，宿主 _entity/_world 由 add_component 设置）
--   * 组件更新：模块每帧调 update_components() 遍历组件 on_update；实体自身 on_update 独立覆写
--   * 组件清理：模块移除实体时调 remove_components() 遍历组件 on_remove
-- 注意：组件 on_init 由 add_component 即时触发，基类不再提供遍历 on_init 的 on_init（避免 collision_comp 等重复注册）
local MODULE_NAME = "fight_entity"

-- 用 classic 定义实体基类
local classic = require "skynet-fly.classic"
local log = require "skynet-fly.log"
local entity = classic:extend()

entity.new = function(self, entity_id, entity_type)
    self.id = entity_id
    self.type = entity_type
    self.components = {}
    self._update_components = {}
end

function entity:add_component(component_type, ...)
    if type(component_type) ~= "string" then
        return false
    end

    if not self._world then
        log.error(string.format("%s.add_component: entity [%s] not in world", MODULE_NAME, self.id))
        return false
    end
    local component = self._world.entity_module:_create_component(component_type, ...)
    if not component then
        return false
    end
    if not component.component_type then
        log.error(MODULE_NAME .. ".add_component: invalid component")
        return false
    end
    if self.components[component.component_type] then
        log.warn(string.format("%s.add_component: component [%s] already exists on entity [%s]", MODULE_NAME, component.component_type, self.id))
        return false
    end
    component._entity = self
    component._world = self._world
    if component.on_init then
        component:on_init()
    end
    self.components[component.component_type] = component
    if component.on_update then
        self._update_components[#self._update_components + 1] = component
    end
    return true
end

function entity:remove_component(component_type)
    local component = self.components[component_type]
    if not component then
        log.warn(string.format("%s.remove_component: component [%s] not found on entity [%s]", MODULE_NAME, component_type, self.id))
        return false
    end
    self.components[component_type] = nil
    for i, c in ipairs(self._update_components) do
        if c.component_type == component_type then
            table.remove(self._update_components, i)
            break
        end
    end
    if component.on_remove then
        component:on_remove()
    end
    component._entity = nil
    component._world = nil
    return true
end

function entity:get_component(component_type)
    return self.components[component_type]
end

function entity:has_component(component_type)
    return self.components[component_type] ~= nil
end

-- 更新全部组件（模块每帧对 update 列表实体调用；实体自身 on_update 独立）
function entity:update_components()
    for _, component in ipairs(self._update_components) do
        component:on_update()
    end
end

-- 组件装配完成后回调（模块在 impl:on_init() 后调用）：
-- 遍历全部组件调用各自 on_init_after——此时所有组件均已挂载到实体容器，
-- 组件 on_init_after 里 get_component 可安全获取自身及任何其他组件（on_init 阶段组件未挂载拿不到）
-- 子类覆写时须 self:super("on_init_after") 保留组件遍历（或自行遍历 self.components）
function entity:on_init_after()
    for _, component in pairs(self.components) do
        if component.on_init_after then
            component:on_init_after()
        end
    end
end

-- 清理全部组件（模块移除实体时调用：遍历组件 on_remove + 清空 update 列表）
function entity:remove_components()
    for _, component in pairs(self.components) do
        if component.on_remove then
            component:on_remove()
        end
        component._entity = nil
        component._world = nil
    end
    self.components = {}
    self._update_components = {}
end

return entity
