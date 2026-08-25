-- fight_fsm_state 有限状态机状态基类（C# BaseFsmState 移植，纯逻辑核心）
-- 状态通过 classic 继承本基类，实现 StateType/OnEnter/OnUpdate/OnExit/CheckTransition
-- 生命周期由 fight_fsm 驱动（FSM 的 ChangeState 调 OnExit/OnEnter，OnUpdate 调 CheckTransition + OnUpdate）
-- 服务器适配：实体访问通过 Entity 容器（entity 参数为实体 impl，可 get_component）

local classic = require "skynet-fly.classic"
local fight_fsm_state_type = hotfix_require "skynet-fly.fight_frame.fsm.fight_fsm_state_type"
local FSM_STATE_TYPE = fight_fsm_state_type.FSM_STATE_TYPE

-- 用 classic 定义状态基类（无注册副作用，仅作基类）
local fight_fsm_state = classic:extend()

fight_fsm_state.new = function(self, entity, fsm_comp)
    self.entity = entity        -- Entity 容器（组件通过 get_component 访问）
    self.fsm_comp = fsm_comp      -- 所属 FSM 组件（可强转具体 FSM）
end

-- 状态类型（子类实现）
function fight_fsm_state:get_state_type()
    return FSM_STATE_TYPE.None
end

-- 进入状态（子类实现）
function fight_fsm_state:on_enter()
end

-- 更新状态（子类实现）
function fight_fsm_state:on_update()
end

-- 退出状态（子类实现）
function fight_fsm_state:on_exit()
end

-- 检查状态转换（子类实现）：返回目标状态枚举，None 表示不转换
function fight_fsm_state:check_transition()
    return FSM_STATE_TYPE.None
end

-- 获取实体组件（C# EntityGetComponent<T>；entity 为 Entity 容器）
function fight_fsm_state:get_entity_comp(component_type)
    if not self.entity then return nil end
    return self.entity:get_component(component_type)
end

-- 释放状态引用（C# Clear）
function fight_fsm_state:clear()
    self.entity = nil
    self.fsm_comp = nil
end

return fight_fsm_state
