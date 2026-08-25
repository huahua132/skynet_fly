-- combat_world 战斗世界编排（示例专用）：2 名玩家准备就绪后创建世界并开始战斗
--   * 房间状态机：等待玩家 → 足额准备 → 开始战斗(创建 fight_world + 生成英雄) → 结束
--   * 两个队伍各 2 名英雄，随机出生在 10×10 地图上，属性随机（血量100-300/攻击10-30/移速0.3-0.6）
--   * 使用确定性伪随机数（LCG，可复现），使回放/校验稳定
local MODULE_NAME = "combat_demo.combat_world"

local log = require "skynet-fly.log"
local fixed = require "skynet-fly.fixed"
local fight_world_manager = hotfix_require "skynet-fly.fight_frame.fight_world_manager"
local hero_entity = hotfix_require "combat.entity.hero_entity"      -- 触发实体类型注册
local collision_comp = hotfix_require "skynet-fly.fight_frame.components.collision_comp" -- 触发组件注册
local combat_logic_module = hotfix_require "combat.module.combat_logic_module"

-- ============================================================
-- 确定性伪随机数（LCG，可复现，避免用全局 math.random 破坏战斗确定性）
-- ============================================================
local RNG = {}
local g_seed = 0

function RNG.set_seed(seed)
    g_seed = seed % 2147483647
    if g_seed <= 0 then g_seed = 1 end
end

function RNG.next_rand()
    g_seed = (g_seed * 48271) % 2147483647
    return g_seed / 2147483647   -- [0,1)
end

RNG.random_float = function(lo, hi)
    return lo + RNG.next_rand() * (hi - lo)
end

RNG.random_int = function(lo, hi)   -- 含端点
    local range = hi - lo + 1
    return lo + math.floor(RNG.next_rand() * range)
end

-- ============================================================
-- 战斗编排对象
-- ============================================================
local CombatWorld = {}
CombatWorld.__index = CombatWorld

function CombatWorld.new(room_id, player_num, battle_cfg, seed)
    local self = setmetatable({}, CombatWorld)
    self.room_id = room_id or 1
    self.player_num = player_num or 2
    self.battle_cfg = battle_cfg or {}         -- { map_size=10, hero_per_player=2, attack_range=0.5, attack_cd=5 }
    self.seed = seed or 20240101
    self.players = {}     -- player_id → { team=... , ready=true }
    self.heroes = {}      -- entity_id → hero_comp
    self.world = nil
    self.state = "idle"   -- idle → starting → running → finished
    self.battle_frames = 0
    self.winner = nil
    return self
end

-- 向世界注册类型：通过文件顶层 hotfix_require 加载导致每个类型自注册，
-- 无需额外 preload（保留占位注释便于理解）。
-- ============================================================
-- 玩家准备逻辑
-- ============================================================

-- 已准备玩家数
local function count_ready(players)
    local n = 0
    for _, p in pairs(players) do
        if p.ready then n = n + 1 end
    end
    return n
end

-- 玩家进入（分配队伍）
function CombatWorld:add_player(player_id)
    if self.players[player_id] then return false end
    local team = #self.players + 1
    self.players[player_id] = { team = team, ready = false, hero_ids = {} }
    log.info(string.format("[%s] 玩家[%s] 进入房间[%d]，队伍 %d (已 %d/%d)",
        MODULE_NAME, tostring(player_id), self.room_id, team, #self.players, self.player_num))
    return true
end

-- 玩家请求准备；两方都准备好后自动开始
function CombatWorld:request_ready(player_id)
    local p = self.players[player_id]
    if not p then
        return false, "player not in room"
    end
    if self.state == "running" or self.state == "starting" then
        return false, "battle already started"
    end
    p.ready = true
    log.info(string.format("[%s] 玩家[%s] 请求准备，已准备 %d/%d",
        MODULE_NAME, tostring(player_id), count_ready(self.players), self.player_num))
    if count_ready(self.players) >= self.player_num then
        self:start_battle()
    end
    return true
end

-- ============================================================
-- 开局：创建世界 + 生成英雄
-- ============================================================
function CombatWorld:start_battle()
    if self.state == "running" or self.state == "starting" then return end
    self.state = "starting"

    self.battle_cfg.map_size = self.battle_cfg.map_size or 10
    self.battle_cfg.hero_per_player = self.battle_cfg.hero_per_player or 2
    self.battle_cfg.attack_range = self.battle_cfg.attack_range or 0.5
    self.battle_cfg.attack_cd = self.battle_cfg.attack_cd or 5

    RNG.set_seed(self.seed)
    log.info(string.format("[%s] 开局! 房间[%d] seed=%d 地图 %d×%d，每位玩家 %d 英雄",
        MODULE_NAME, self.room_id, self.seed, self.battle_cfg.map_size,
        self.battle_cfg.map_size, self.battle_cfg.hero_per_player))
    self:_create_world()
end

function CombatWorld:_create_world()
    -- world instance 仅提供 fight_world_manager 需要的 GetGuid（世界ID 用房间号）
    local instance = { GetGuid = function() return self.room_id end }
    local world = fight_world_manager.add_world(instance)
    self.world = world
    -- 加入战斗逻辑模块（后加入 → 每帧在实体更新之后执行）
    world:add_module("combat_logic_module", combat_logic_module)
    self.world = world

    -- 生成英雄
    local hero_entities = {}
    for player_id, p in pairs(self.players) do
        for i = 1, self.battle_cfg.hero_per_player do
            local entity = self:_spawn_hero(p.team, player_id)
            if entity then
                hero_entities[#hero_entities + 1] = entity
                p.hero_ids[#p.hero_ids + 1] = entity.id
            end
        end
    end

    -- 战斗逻辑模块接管（注入敌方集合 + 结束回调；request_begin 待实体 flush 完成后自行开始）
    world.combat_logic_module:request_begin(hero_entities, function(winner_team)
        self:_on_battle_end(winner_team)
    end)

    self.state = "running"
    log.info(string.format("[%s] 战斗运行中，world[%d] 英雄数=%d",
        MODULE_NAME, self.room_id, #hero_entities))
end

-- 随机生成一名英雄（含随机属性，全部入参定点化）
function CombatWorld:_spawn_hero(team, player_id)
    local map_size = self.battle_cfg.map_size
    local x = RNG.random_float(0.5, map_size - 0.5)
    local y = RNG.random_float(0.5, map_size - 0.5)
    local hp = RNG.random_int(100, 300)
    local atk = RNG.random_int(10, 30)
    local spd = RNG.random_float(0.3, 0.6)

    local entity_module = self.world.entity_module
    local entity = entity_module:create_entity("hero")
    if not entity then
        log.error(string.format("[%s] 生成英雄失败 hero entity 未注册", MODULE_NAME))
        return nil
    end
    entity.owner = player_id
    entity._init_pos = { x, y }                -- 待 on_init_after 时写入 zc_position_comp
    -- 战斗属性：create_entity 返回的实体为挂起态（组件 on_init 待帧末 flush），
    -- 故先把属性写到 entity._btl，由 hero_entity:on_init 在装配阶段注入 hero_comp
    entity._btl = {
        team = team,
        hp = hp,
        attack = atk,
        speed = spd,
        attack_range = self.battle_cfg.attack_range,
        attack_cd = self.battle_cfg.attack_cd,
    }

    log.info(string.format("[%s] 生成英雄 entity[%d] team=%d 玩家[%s] pos=(%.2f,%.2f) hp=%d atk=%d spd=%.2f",
        MODULE_NAME, entity.id, team, tostring(player_id), x, y, hp, atk, spd))
    return entity
end

function CombatWorld:_on_battle_end(winner_team)
    self.state = "finished"
    self.winner = winner_team
    local winner_player = nil
    for player_id, p in pairs(self.players) do
        if p.team == winner_team then winner_player = player_id end
    end
    log.info(string.format("[%s] 房间[%d] 战斗结束，获胜方=%s",
        MODULE_NAME, self.room_id, winner_player and tostring(winner_player) or "平局"))
end

-- ============================================================
-- 查询接口
-- ============================================================
function CombatWorld:get_state()
    local heroes = {}
    local entity_module = self.world and self.world.entity_module
    if entity_module then
        for _, p in pairs(self.players) do
            for _, hid in ipairs(p.hero_ids) do
                local e = entity_module:get_entity(hid)
                if e then
                    local hc = e:get_component("hero_comp")
                    if hc and hc.alive and not hc:is_dead() then
                        local pc = e:get_component("zc_position_comp")
                        local fx, fy = pc and pc:get_float_position() or 0, 0
                        heroes[#heroes + 1] = {
                            id = hid, team = hc.team,
                            hp = fixed.to_int_round(hc.hp),
                            x = math.floor(fx * 100) / 100,
                            y = math.floor(fy * 100) / 100,
                        }
                    end
                end
            end
        end
    end
    return {
        state = self.state,
        winner = self.winner,
        frame = self.world and self.world.frame_count or 0,
        total_time = self.world and fixed.to_float(self.world.total_time) or 0,
        heroes = heroes,
    }
end

return CombatWorld
