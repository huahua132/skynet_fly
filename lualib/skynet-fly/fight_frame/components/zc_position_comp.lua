-- zc_position_comp 位置组件：实体在场景中的坐标（Q16.16 定点）
-- 契约（collision_comp / hash_search_module 引用）：
--   component_type = "zc_position_comp"
--   字段 .x/.y 为 Q16.16 定点 raw 整数
--   方法 get_position() 返回 x, y（定点 raw）
-- 组件类型通过 fight_register_type 模块自注册
local classic = require "skynet-fly.classic"
local fixed = require "skynet-fly.fixed"
local fight_register_type = require "skynet-fly.fight_frame.fight_register_type"

local zc_position_comp = classic:extend()
zc_position_comp.component_type = "zc_position_comp"

zc_position_comp.new = function(self, x, y)
    self.x = fixed.from_float(x or 0)
    self.y = fixed.from_float(y or 0)
end

-- 设置位置（普通浮点输入，内部转定点）
function zc_position_comp:set_position(x, y)
    self.x = fixed.from_float(x)
    self.y = fixed.from_float(y)
end

-- 设置位置（已定点 raw 输入）
function zc_position_comp:set_position_raw(x, y)
    self.x = x
    self.y = y
end

-- 获取位置（返回定点 raw）
function zc_position_comp:get_position()
    return self.x, self.y
end

-- 通过 fight_register_type 模块自注册组件类型
fight_register_type.register("component", zc_position_comp.component_type, zc_position_comp)

return zc_position_comp
