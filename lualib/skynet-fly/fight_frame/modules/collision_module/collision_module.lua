-- collision_module 碰撞模块，每帧检测碰撞，分发 Enter/Stay/Exit 事件到 collision_comp
-- 单向检测：只有碰撞物（active，collision_comp.passive=false）触发被碰撞物（passive=true）
-- 只对碰撞物触发方分发事件，被碰撞物不收到事件（避免双方都触发）
-- 开战双方过滤：on_update 每帧经 set_filter 注入（bullet↔建筑/英雄需同开战关系）
-- Enter/Exit 严格配对，不会出现 Exit 先于 Enter、孤立 Exit、Exit 后仍有 Stay
local classic = require "skynet-fly.classic"
local log = require "skynet-fly.log"
local collision = hotfix_require "skynet-fly.fight_frame.collision.collision"

-- 用 classic 定义碰撞模块
local M = classic:extend()

function M:on_init()
    self._collision = collision()
    self._prev_pairs = {}
    -- 开战双方过滤：active 为碰撞物（子弹），passive 为被碰撞物（建筑/英雄）
    -- 帧级注入：取子弹 owner 与目标 owner 的开战关系（war_module.getOpponent）
    -- 注：self._world 已由 add_module 在 on_init 前设置，过滤回调里直接访问
    self._filter = nil
    -- pair_key 数值编码基数（与 collision.check_all 的 seen 编码一致，双向组合唯一，见 on_update）
    self._id_big = 1000000
    -- current_set 双缓冲复用（与 _prev_pairs 每帧交换，避免每帧重建 current_set 表）
    self._current_set = {}
end

-- 设置帧级碰撞对过滤器（同开战关系才检测）
function M:set_filter(filter)
    self._filter = filter
end

function M:on_remove()
    for _, pair in pairs(self._prev_pairs) do
        self:_fire_exit(pair)
    end
    self._prev_pairs = {}
    self._current_set = {}
    self._collision:clear()
    self._filter = nil
end

function M:on_update()
    -- 每帧注入开战双方过滤器（world.war_module 存在才过滤）
    if self._filter then
        self._collision:set_filter(self._filter)
    end
    local current_pairs = self._collision:check_all()
    -- 复用双缓冲 current_set：清空上次元素后填充（不重建表，见性能报告 #2）
    local current_set = self._current_set
    for k in pairs(current_set) do current_set[k] = nil end

    -- 双向数值编码（a=min,b=max，与 collision.check_all 的 seen 一致）：替代 id.."_"..other_id 字符串拼接
    local id_big = self._id_big
    for _, pair in ipairs(current_pairs) do
        local a, b = pair[1].id, pair[2].id
        if a > b then a, b = b, a end
        current_set[a * id_big + b] = pair
    end

    for key, pair in pairs(self._prev_pairs) do
        if not current_set[key] then
            self:_fire_exit(pair)
        end
    end

    for _, pair in ipairs(current_pairs) do
        local a, b = pair[1].id, pair[2].id
        if a > b then a, b = b, a end
        local key = a * id_big + b
        if self._prev_pairs[key] then
            self:_fire_stay(pair)
        else
            self:_fire_enter(pair)
        end
    end

    -- 双缓冲交换：current_set 成为新 prev_pairs，旧 prev_pairs 回收到 _current_set（下次复用）
    self._prev_pairs, self._current_set = current_set, self._prev_pairs
end

-- 单向分发：只有主动方（碰撞物，collision_comp.passive=false）收到碰撞事件
-- 被碰撞物（建筑/英雄）不触发事件（由子弹 on_collision_enter 主动触发伤害）
function M:_fire_one_way(pair, evt_name)
    local entity_a = pair[1]
    local entity_b = pair[2]
    -- 主动方 = 碰撞物（passive=false 的一方）
    local active_agent, other_agent = entity_a, entity_b
    if active_agent.passive then
        active_agent, other_agent = entity_b, entity_a
    end
    if active_agent.passive then
        -- 双方都是被碰撞物（不应出现，防御跳过）
        return
    end
    local entity = self._world.entity_module:get_entity(active_agent.id)
    if not entity then return end
    -- get_component 直接返回组件实例（实体即容器：components[component_type]），调用其碰撞事件方法
    local comp = entity:get_component("collision_comp")
    if comp and comp[evt_name] then
        -- 事件参数传被碰撞实体（实体即容器，供 event_comp 触发事件）
        local other_entity = self._world.entity_module:get_entity(other_agent.id)
        comp[evt_name](comp, other_entity or other_agent)
    end
end

function M:_fire_exit(pair)
    self:_fire_one_way(pair, "on_collision_exit")
end

function M:_fire_enter(pair)
    self:_fire_one_way(pair, "on_collision_enter")
end

function M:_fire_stay(pair)
    self:_fire_one_way(pair, "on_collision_stay")
end

-- 注册碰撞代理（entity: 实体；组件需已挂载——由 collision_comp:on_init_after 调用，此时 get_component 可获取）
function M:add_entity(entity)
    local comp = entity:get_component("collision_comp")
    if not comp then
        log.warn(string.format("collision_module.add_entity: no collision_comp type=[%s] id=[%s]", tostring(entity.entity_type), tostring(entity.id)))
        return
    end
    -- 碰撞盒：x/y 为中心，w/h 为半宽半高（C# 碰撞体中心 + CollisionSize/2）
    -- passive=true 表示被碰撞物（建筑/英雄），只被动被触发，不主动触发他人
    -- is_circle=true 表示圆形碰撞盒（w 作半径）
    self._collision:add_agent(entity.id, comp.x, comp.y, comp.w, comp.h, comp.layer, comp.passive, comp.is_circle)
end

function M:remove_entity(entity)
    local eid = entity.id
    local to_remove = {}
    for key, pair in pairs(self._prev_pairs) do
        if pair[1].id == eid or pair[2].id == eid then
            to_remove[#to_remove + 1] = key
        end
    end
    for _, key in ipairs(to_remove) do
        local pair = self._prev_pairs[key]
        self:_fire_exit(pair)
        self._prev_pairs[key] = nil
    end
    self._collision:remove_agent(eid)
end

function M:update_entity(entity)
    local comp = entity:get_component("collision_comp")
    if not comp then
        return
    end
    self._collision:update_agent(entity.id, comp.x, comp.y, comp.w, comp.h)
end

-- 获取碰撞系统（调试面板采集碰撞盒信息用）
function M:get_collision()
    return self._collision
end

-- 获取碰撞 agent 表（供实体装配后同步归属字段到 agent，避免碰撞过滤每帧 get_entity+getOwner）
function M:get_agent_owner(entity_id)
    return self._collision and self._collision._agents[entity_id]
end

function M:set_layer_collision(layer_a, layer_b, enabled)
    self._collision:set_layer_collision(layer_a, layer_b, enabled)
end

return M
