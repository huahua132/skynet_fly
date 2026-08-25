-- entity_event_enum 实体通用事件ID定义（负数递增）
local ENTITY_EVENT = {
    on_collision_enter = -1,  -- 碰撞进入
    on_collision_exit = -2,   -- 碰撞退出
    on_collision_stay = -3,   -- 碰撞持续
}
return ENTITY_EVENT
