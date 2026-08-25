-- hero_comp 英雄组件（示例专用）：英雄属性数据 + 逐帧 AI（随机锁定敌方英雄，追击并攻击）
-- 属性统一使用 Q16.16 定点数：hp/max_hp/attack/speed/attack_range/attack_cd/last_attack_time，
-- 位置来自同实体 zc_position_comp（fixed），位移与攻击判定全部定点整数运算，保证确定性。
local classic = require "skynet-fly.classic"
local fixed = require "skynet-fly.fixed"
local log = require "skynet-fly.log"
local fight_register_type = require "skynet-fly.fight_frame.fight_register_type"

local hero_comp = classic:extend()
hero_comp.component_type = "hero_comp"

-- setup_btl：实体装配后由业务层调用，注入英雄战斗属性（普通数值入参，内部转定点）
function hero_comp:setup_btl(data)
    -- data: { team, hp, attack, speed, attack_range=0.5, attack_cd=5 }
    self.team = data.team
    self.max_hp = fixed.from_float(data.hp)
    self.attack = fixed.from_float(data.attack)
    self.speed = fixed.from_float(data.speed)     -- 单位/秒（定点）
    self.attack_range = fixed.from_float(data.attack_range or 0.5)
    self.attack_cd = fixed.from_float(data.attack_cd or 5)   -- 秒（定点）
    self.last_attack_time = fixed.from_float(0)    -- 定点秒时间线
    self.alive = true
    self._dead = false
    self._target_id = nil
    self:reset_hp()
end

function hero_comp:reset_hp()
    self.hp = self.max_hp
end

-- 受击（damage 为定点攻击力）
function hero_comp:take_damage(damage)
    if not self.alive then return end
    self.hp = fixed.sub(self.hp, damage)
    if self.hp <= 0 then self.hp = 0 end
end

function hero_comp:is_dead()
    return self.hp <= 0
end

-- 清空目标（死亡/目标失效时）
function hero_comp:clear_target()
    self._target_id = nil
end

-- 随机锁定一个敌方英雄实体（敌人集由战斗逻辑在装配后注入 self._enemy_ids）
-- 为避免依赖全局 math.random 破坏确定性，按 (实体id + 世界帧数) 的确定性取模选取敌人下标。
function hero_comp:lock_random_enemy()
    local ids = self._enemy_ids
    if not ids or #ids == 0 then
        self._target_id = nil
        return nil
    end
    local world = self._world
    local frame = world and world.frame_count or 0
    local pick = ((self._entity.id + frame) % #ids) + 1
    self._target_id = ids[pick]
    return self._target_id
end

-- 逐帧 AI：追击并攻击（world.delta_time 为 Q16.16 秒）
function hero_comp:on_update()
    local world = self._world
    if not self.alive then return end
    local pos = self._entity:get_component("zc_position_comp")
    if not pos then return end
    local delta_time = world.delta_time

    -- 校验当前目标是否失效（死亡/消失），失效则重新随机锁定
    local target = nil
    if self._target_id then
        target = world.entity_module:get_entity(self._target_id)
        if not target then
            self:clear_target()
        end
    end
    if not target then
        self:lock_random_enemy()
        target = self._target_id and world.entity_module:get_entity(self._target_id) or nil
    end
    if not target then return end

    local target_pos = target:get_component("zc_position_comp")
    if not target_pos then return end

    local my_x, my_y = pos:get_position()
    local tgt_x, tgt_y = target_pos:get_position()

    -- 距离（定点）与方向
    local dx = fixed.sub(tgt_x, my_x)
    local dy = fixed.sub(tgt_y, my_y)
    local dist_sq = fixed.add(fixed.mul(dx, dx), fixed.mul(dy, dy))
    local dist = fixed.sqrt(dist_sq)

    if dist > self.attack_range then
        -- 追击：沿方向移动 speed*delta_time 距离
        local move = fixed.mul(self.speed, delta_time)
        if move >= dist then
            -- 一帧内直接贴到目标
            pos:setup(fixed.to_float(tgt_x), fixed.to_float(tgt_y))
        else
            -- dir = target - self，再 unit(move)
            local nx = fixed.div(dx, dist)
            local ny = fixed.div(dy, dist)
            pos:translate(fixed.mul(nx, move), fixed.mul(ny, move))
        end
    else
        -- 在攻击范围内：CD 就绪则攻击
        local now_t = world.total_time
        local cd_elapsed = fixed.sub(now_t, self.last_attack_time)
        if cd_elapsed >= self.attack_cd then
            local tgt_comp = target:get_component("hero_comp")
            if tgt_comp and tgt_comp.alive then
                tgt_comp:take_damage(self.attack)
                self.last_attack_time = now_t
                log.info(string.format(
                    "[combat] hero entity[%d](team%d) 攻击 entity[%d](team%d): -%d hp 剩余=%d",
                    self._entity.id, self.team, target.id, tgt_comp.team,
                    fixed.to_int_round(self.attack), fixed.to_int_round(tgt_comp.hp)))
                if tgt_comp:is_dead() then
                    tgt_comp.alive = false
                    tgt_comp._dead = true
                end
            end
        end
    end
end

-- 通过 fight_register_type 模块自注册组件类型
fight_register_type.register("component", hero_comp.component_type, hero_comp)

return hero_comp
