-- fight_fsm 有限状态机框架：注册状态 → 启动 → 每帧检查转换 + 更新当前状态 → 切换
-- 生命周期：on_init(注册+初始化)/on_update(FSM 更新)/on_remove(清理)；ChangeState 调旧状态 OnExit + 新状态 OnEnter

local classic = require "skynet-fly.classic"
local log = require "skynet-fly.log"
local fight_fsm_state_type = hotfix_require "skynet-fly.fight_frame.fsm.fight_fsm_state_type"
local FSM_STATE_TYPE = fight_fsm_state_type.FSM_STATE_TYPE
local FSM_STATE_TYPE_NAME = fight_fsm_state_type.FSM_STATE_TYPE_NAME

local fight_fsm = classic:extend()

fight_fsm.new = function(self)
    self._fsm_states = {}          -- FsmStateType → 状态实例
    self.current_state = nil       -- 当前状态实例
    self.current_state_type = FSM_STATE_TYPE.None
    self.previous_state_type = FSM_STATE_TYPE.None
    self.is_can_change_state = false -- 是否可切换状态
    self.on_fsm_change_callback = nil
end

function fight_fsm:on_init()
    self._fsm_states = {}
    self.current_state = nil
    self.current_state_type = FSM_STATE_TYPE.None
    self.previous_state_type = FSM_STATE_TYPE.None
    self:on_register_all_fsm_state()
    self:on_fsm_init()
    self.is_can_change_state = true
    self:on_start_fsm()
end

-- 每帧更新：检查状态转换 + 更新当前状态
function fight_fsm:on_update()
    self:on_update_fsm()
    if self.current_state == nil then return end

    local next_state_type = self.current_state:check_transition()
    if next_state_type ~= FSM_STATE_TYPE.None and next_state_type ~= self.current_state_type then
        self:change_state(next_state_type)
    end
    self.current_state:on_update()
end

function fight_fsm:on_remove()
    self:on_fsm_destroy()
    self._fsm_states = {}
    self.current_state = nil
    self.previous_state_type = FSM_STATE_TYPE.None
    self.current_state_type = FSM_STATE_TYPE.None
    self.on_fsm_change_callback = nil
end

-- ============ 状态切换 ============

-- 切换状态（同状态/不可切换/状态未注册则跳过）
function fight_fsm:change_state(state)
    if not self.is_can_change_state then
        return
    end
    if state == FSM_STATE_TYPE.None or state == self.current_state_type then
        return
    end
    local new_state = self._fsm_states[state]
    if not new_state then
        log.error(string.format("fight_fsm.change_state: 状态 [%s] 未注册", tostring(FSM_STATE_TYPE_NAME[state] or state)))
        return
    end

    local prev_type = self.current_state_type
    self.previous_state_type = prev_type

    if self.current_state then
        self.current_state:on_exit()
    end

    self.current_state = new_state
    self.current_state_type = state
    if self.current_state then
        self.current_state:on_enter()
    end

    if self.on_fsm_change_callback then
        self.on_fsm_change_callback(state, prev_type)
    end
    self:on_state_changed(prev_type, state)
end

-- 切换到上一个状态（C# ChangeToPreviousState）
function fight_fsm:change_to_previous_state()
    self:change_state(self.previous_state_type)
end

-- ============ 状态注册 ============

-- 注册状态（C# RegisterFsmState<T>）
-- state_type: 状态枚举；state_class: 状态类（classic 继承 fight_fsm_state）
-- 状态实例创建时传入实体和 FSM 自身
function fight_fsm:register_fsm_state(state_type, state_class)
    if self._fsm_states[state_type] then
        log.warn(string.format("fight_fsm.register_fsm_state: 状态 [%s] 已注册", tostring(FSM_STATE_TYPE_NAME[state_type] or state_type)))
        return
    end
    local state = state_class(self._entity, self)
    self._fsm_states[state_type] = state
end

-- 获取状态实例
function fight_fsm:get_fsm_state(state_type)
    return self._fsm_states[state_type]
end

-- ============ 子类覆写 ============

-- 注册所有状态（子类实现，C# OnRegisterAllFsmState）
function fight_fsm:on_register_all_fsm_state()
end

-- 初始化 FSM（子类实现，C# OnFsmInit）
function fight_fsm:on_fsm_init()
end

-- 启动 FSM（子类实现，C# OnStartFsm，通常切到初始状态）
function fight_fsm:on_start_fsm()
end

-- FSM 更新前钩子（子类实现，C# OnUpdateFsm）
function fight_fsm:on_update_fsm()
end

-- 停止 FSM（子类实现，C# OnStopFsm）
function fight_fsm:on_stop_fsm()
end

-- 销毁 FSM（子类实现，C# OnFsmDestroy）
function fight_fsm:on_fsm_destroy()
end

-- 状态切换钩子（子类实现，C# OnStateChanged）
function fight_fsm:on_state_changed(previous_state_type, current_state_type)
end

return fight_fsm
