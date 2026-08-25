-- hero_entity 英雄实体（示例专用）
-- 组装 zc_position_comp（fixed 坐标）+ event_comp + collision_comp + hero_comp（AI+属性）
-- 实体类型经 fight_register_type 自注册，由 fight_entity_module.create_entity("hero") 创建。
--
-- classic 链式基类构造方式：
--   本实现中 class 表的 super 字段指向父类表，故基类构造用 self.super.new(self, ...)，
--   调父类遍历用 self.super.on_init_after(self)（与框架 fight_frame 文档所述 self:super 等价）。
local MODULE_NAME = "combat_demo.hero_entity"

local fight_entity = hotfix_require "skynet-fly.fight_frame.modules.fight_entity_module.fight_entity"
local fight_register_type = require "skynet-fly.fight_frame.fight_register_type"
-- 加载以下组件模块以触发其自注册（add_component 依赖 fight_register_type 缓存里已注册）
local position_comp = require "combat.component.position_comp"
local event_comp = hotfix_require "skynet-fly.fight_frame.components.event_comp"
local collision_comp = hotfix_require "skynet-fly.fight_frame.components.collision_comp"
local hero_comp = require "combat.component.hero_comp"

-- 用 classic 继承 fight_entity 基类
local hero_entity = fight_entity:extend()
hero_entity.entity_type = "hero"

-- 覆写 new：先基类构造（id/type/components 初始化），业务装配放 on_init（需 _world 就绪）
function hero_entity:new(entity_id)
    self.super.new(self, entity_id, hero_entity.entity_type)
end

-- 实体装配（由 fight_entity_module 在 _world 就绪后、帧末 flush 时调用 on_init）：
-- 组件此时可正常 add_component（实体模块 create_entity 挂起，on_init 阶段 add_component 合法）
function hero_entity:on_init()
    self:add_component("zc_position_comp", 0, 0)
    self:add_component("event_comp")
    -- 碰撞盒：英雄半径 0.25（半宽半高），layer=0，passive=true（英雄作为被碰撞物，避免互拒触发）
    self:add_component("collision_comp", 0, 0, 0.25, 0.25, 0, true)
    self:add_component("hero_comp")
    -- 战斗属性由 combat_world 在 create_entity 后写 entity._btl，此处注入 hero_comp
    local hc = self:get_component("hero_comp")
    if hc and self._btl then
        hc:setup_btl(self._btl)
        self._btl = nil
    end
end

-- 装配完成后由 fight_entity_module 回调：设置初始位置（_init_pos 由 combat_world 注入）
function hero_entity:on_init_after()
    self.super.on_init_after(self)   -- 先调基类遍历组件 on_init_after（collision_comp 借此注册碰撞）
    local pos_comp = self:get_component("zc_position_comp")
    if pos_comp and self._init_pos then
        pos_comp:setup(self._init_pos[1], self._init_pos[2])
        self._init_pos = nil
    end
end

-- fight_register_type 自注册实体类型
fight_register_type.register("entity", hero_entity.entity_type, hero_entity)

return hero_entity
