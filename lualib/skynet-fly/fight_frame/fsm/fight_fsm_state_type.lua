-- fight_fsm_state_type 有限状态机状态类型枚举（C# Fsm.cs FsmStateType 移植，纯逻辑核心）
-- 通用状态类型：新增状态直接加枚举即可
-- 服务器适配：剥离 Unity 依赖，仅状态类型常量

local FSM_STATE_TYPE = {
    None   = 0,  -- 无（不转换）
    Idle   = 1,  -- 待机
    Move   = 2,  -- 移动
    Attack = 3,  -- 攻击
    Portal = 4,  -- 传送（服务器暂未使用，保留枚举）
    Death  = 5,  -- 死亡
}

local FSM_STATE_TYPE_NAME = {
    [0] = "None",
    [1] = "Idle",
    [2] = "Move",
    [3] = "Attack",
    [4] = "Portal",
    [5] = "Death",
}

return { FSM_STATE_TYPE = FSM_STATE_TYPE, FSM_STATE_TYPE_NAME = FSM_STATE_TYPE_NAME }
