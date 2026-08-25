-- collision_comp 碰撞组件，挂载到实体后自动注册到碰撞模块，触发碰撞事件
-- 单向检测：碰撞物（passive=false）触发被碰撞物（passive=true），只对碰撞物分发事件
-- 开战双方过滤：框架 collision_module 每帧经 set_filter 注入（子弹↔建筑/英雄需同开战关系）
-- 组件类型通过 fight_register_type 模块自注册
local classic = require "skynet-fly.classic"
local fixed = require "skynet-fly.fixed"
local ENTITY_EVENT = hotfix_require "skynet-fly.fight_frame.event.entity_event_enum"
local fight_register_type = require "skynet-fly.fight_frame.fight_register_type"

-- 用 classic 定义碰撞组件
local collision_comp = classic:extend()
collision_comp.component_type = "collision_comp"
-- 数值（x/y/w/h）统一使用 Q16.16 定点数：new/set_size 接收普通数值并内部转定点。
-- 位置同步来自实体 position_comp（zc_position_comp）的 get_position，须返回定点数以保持确定性。
collision_comp.new = function(self, x, y, w, h, layer, passive, static)
    self.x = fixed.from_float(x or 0)
    self.y = fixed.from_float(y or 0)
    self.w = fixed.from_float(w or 0.5)      -- 半宽（碰撞盒长的一半，默认 0.5 → 长 1）
    self.h = fixed.from_float(h or 0.5)      -- 半高（碰撞盒宽的一半，默认 0.5 → 宽 1）
    self.layer = layer or 0
    self.passive = passive or false   -- true=被碰撞物（建筑/英雄），false=碰撞物（子弹）
    self._static = static or false    -- true=静态实体（位置不变，如建筑），on_update 仅首次同步跳过网格更新
    self._static_synced = false        -- 静态实体首次同步标记
    self._cached_pos_comp = nil -- 位置组件缓存（get_component 哈希查找，on_update 每帧多次调用）
end

-- on_init_after：由实体 on_init_after（Entity 基类遍历组件）在实体全部组件装配完成后调用，
-- 此时组件均已挂载到实体容器，get_component 可安全获取自身/其他组件
-- 位置初始化 + 注册到碰撞模块放这里（on_init 阶段组件尚未挂载，get_component 拿不到自身，碰撞代理会注册失败）
function collision_comp:on_init_after()
    -- 位置：以实体 position_comp 为碰撞盒中心（支持后挂场景；通常由 add_component 后 setup 设置）
    -- 装配完成后缓存 position_comp（组件列表固定，on_update 每帧直接用缓存免哈希查找）
    self._cached_pos_comp = self._entity:get_component("zc_position_comp")
    local pos_comp = self._cached_pos_comp
    if pos_comp then
        local x, y = pos_comp:get_position()
        if not self.x or self.x == 0 then self.x = x or 0 end
        if not self.y or self.y == 0 then self.y = y or 0 end
    end
    -- 注册到碰撞模块（组件已挂载，get_component 可拿到自身）
    local coll_mod = self._world.collision_module
    if coll_mod then
        coll_mod:add_entity(self._entity)
    end
end

function collision_comp:on_remove()
    self._world.collision_module:remove_entity(self._entity)
end

function collision_comp:on_update()
    -- 动态实体（子弹/英雄）：每帧同步位置 + 更新碰撞网格
    -- 静态实体（建筑）：位置不变，仅首次同步一次，之后跳过网格更新（省每帧 _remove_from_grid + _insert_to_grid）
    local pos_comp = self._cached_pos_comp
    if pos_comp then
        local x, y = pos_comp:get_position()
        self.x, self.y = x, y
    end
    if self._static then
        if not self._static_synced then
            self._static_synced = true
            self._world.collision_module:update_entity(self._entity)
        end
        return
    end
    self._world.collision_module:update_entity(self._entity)
end

-- 设置碰撞盒尺寸（半宽半高，C# SetCollisionSize；输入为普通数值，内部转定点）
function collision_comp:set_size(w, h)
    if w then self.w = fixed.from_float(w) end
    if h then self.h = fixed.from_float(h) end
end

-- 设置被动标志（被碰撞物 true / 碰撞物 false；装配后调用）
function collision_comp:set_passive(passive)
    self.passive = passive or false
end

function collision_comp:on_collision_enter(other_entity)
    local event_comp = self._entity:get_component("event_comp")
    if event_comp then
        event_comp:trigger_event(ENTITY_EVENT.on_collision_enter, self._entity, other_entity, self._world)
    end
end

function collision_comp:on_collision_exit(other_entity)
    local event_comp = self._entity:get_component("event_comp")
    if event_comp then
        event_comp:trigger_event(ENTITY_EVENT.on_collision_exit, self._entity, other_entity, self._world)
    end
end

function collision_comp:on_collision_stay(other_entity)
    local event_comp = self._entity:get_component("event_comp")
    if event_comp then
        event_comp:trigger_event(ENTITY_EVENT.on_collision_stay, self._entity, other_entity, self._world)
    end
end

-- 通过 fight_register_type 模块自注册组件类型
fight_register_type.register("component", collision_comp.component_type, collision_comp)

return collision_comp
