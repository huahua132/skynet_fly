-- combat_logic_module 战斗逻辑模块（示例专用）：挂在 fight_world 上的逐帧驱动
-- 职责：
--   1) 装配战场上下文（为每个英雄注入敌方英雄 id 集合）
--   2) 每帧清理已死亡英雄（延迟到实体模块帧末统一移除）、判定胜负
-- 英雄逐帧 AI（锁定/追击/攻击）在各 hero_comp:on_update 中完成（实体组件更新阶段）。
-- 本模块的 on_update 在实体组件更新之后执行（后添加到 world 的模块），用于收尾判定。
local MODULE_NAME = "combat_logic_module"

local classic = require "skynet-fly.classic"
local log = require "skynet-fly.log"
local fixed = require "skynet-fly.fixed"

local M = classic:extend()

function M:on_init()
    self._heroes = {}         -- entity_id → hero_comp（全部存活英雄）
    self._by_team = {}        -- team → { [entity_id]=true }
    self._running = false
    self._end_cb = nil        -- 战斗结束回调（combat_world 注入）
    self._frame_log_throttle = 0
    self._pending_begin = nil -- { hero_entities=..., end_cb=... }
end

function M:on_remove()
    self._heroes = {}
    self._by_team = {}
    self._running = false
    self._end_cb = nil
    self._pending_begin = nil
end

-- 请求开始战斗（由 combat_world 在创建 hero 实体后调用）
-- 实体 create_entity 是挂起态，组件需等到实体模块帧末 flush 才装配，故延迟到某帧已 flush 后再真开始
function M:request_begin(hero_entities, end_cb)
    self._pending_begin = { hero_entities = hero_entities, end_cb = end_cb }
end

-- 真正的开始：等所有英雄实体在实体模块就绪（flush 完成）后执行
function M:_try_begin()
    local pending = self._pending_begin
    if not pending then return end
    local world = self._world
    local entity_module = world.entity_module
    for _, entity in ipairs(pending.hero_entities) do
        if not entity_module:get_entity(entity.id) then
            return   -- 尚未 flush 完成，等下一帧
        end
    end

    self._pending_begin = nil
    self._heroes = {}
    self._by_team = {}
    self._running = true
    self._end_cb = pending.end_cb

    -- 先建立队伍索引（组件已装配，get_component 可安全取 hero_comp）
    for _, entity in ipairs(pending.hero_entities) do
        local comp = entity:get_component("hero_comp")
        if comp then
            self._heroes[entity.id] = comp
            if not self._by_team[comp.team] then self._by_team[comp.team] = {} end
            self._by_team[comp.team][entity.id] = true
        end
    end
    -- 再为每个英雄注入敌方 id 集合（供随机锁定）
    for id, comp in pairs(self._heroes) do
        local enemies = {}
        for team, ids in pairs(self._by_team) do
            if team ~= comp.team then
                for eid in pairs(ids) do
                    enemies[#enemies + 1] = eid
                end
            end
        end
        comp._enemy_ids = enemies
    end
    log.info(string.format("[%s] 战斗开始，共 %d 名英雄参战", MODULE_NAME, #pending.hero_entities))
end

function M:on_update()
    if not self._running then
        -- 尚在等待开局时可尝试真正开始
        self:_try_begin()
        if not self._running then return end
    end
    local world = self._world
    local entity_module = world.entity_module

    -- 1) 收集已死亡英雄（hero_comp:is_dead 判断），延迟移除
    local dead = {}
    for id, comp in pairs(self._heroes) do
        if comp._dead or comp:is_dead() then
            dead[#dead + 1] = id
        end
    end
    for _, id in ipairs(dead) do
        local comp = self._heroes[id]
        if comp then
            self._heroes[id] = nil
            self._by_team[comp.team][id] = nil
            if not next(self._by_team[comp.team]) then
                self._by_team[comp.team] = nil
            end
            entity_module:remove_entity(id)   -- 帧末 flush 真正移除
            log.info(string.format("[%s] 英雄 entity[%d](team%d) 阵亡", MODULE_NAME, id, comp.team))
        end
    end

    -- 2) 判定胜负：某队全灭即分出胜负
    local team_counts = {}
    local total_alive = 0
    for team, ids in pairs(self._by_team) do
        local n = 0
        for _ in pairs(ids) do n = n + 1 end
        team_counts[team] = n
        total_alive = total_alive + n
    end
    if total_alive == 0 then
        self:finish_battle(0)   -- 同归于尽
        return
    end
    if #self._heroes <= 0 then
        self:finish_battle(0)
        return
    end
    -- 找出仍存活的队伍
    local alive_teams = 0
    local last_team = nil
    for team, n in pairs(team_counts) do
        if n > 0 then
            alive_teams = alive_teams + 1
            last_team = team
        end
    end
    if alive_teams <= 1 then
        self:finish_battle(alive_teams == 1 and last_team or 0)
        return
    end

    -- 3) 节流打印战况（约每 30 帧一次）
    self._frame_log_throttle = self._frame_log_throttle + 1
    if self._frame_log_throttle >= 30 then
        self._frame_log_throttle = 0
        local parts = {}
        local world_time = fixed.to_float(world.total_time)
        for team, ids in pairs(self._by_team) do
            local n = 0
            for _ in pairs(ids) do n = n + 1 end
            parts[#parts + 1] = string.format("team%d×%d", team, n)
        end
        log.info(string.format("[combat] t=%.1fs frame=%d 存活: %s", world_time, world.frame_count, table.concat(parts, " ")))
    end
end

function M:finish_battle(winner_team)
    if not self._running then return end
    self._running = false
    local world = self._world
    log.info(string.format(
        "[%s] 战斗结束 winner_team=%s 帧数=%d 时长=%.2fs",
        MODULE_NAME,
        winner_team and tostring(winner_team) or "平局",
        world.frame_count,
        fixed.to_float(world.total_time)))
    world:stop()   -- 停止世界定时器
    if self._end_cb then
        local cb = self._end_cb
        self._end_cb = nil
        cb(winner_team)
    end
end

return M
