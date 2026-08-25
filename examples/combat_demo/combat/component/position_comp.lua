-- position_comp 位置组件（示例专用，注册为 fight_frame 约定的 zc_position_comp 组件类型）
-- 统一使用 skynet-fly.fixed Q16.16 定点坐标：get_position() 返回定点数（战斗层确定性来源），
-- 碰撞组件/搜索模块从本组件读取均得到定点数，保证全链确定。
local classic = require "skynet-fly.classic"
local fixed = require "skynet-fly.fixed"
local fight_register_type = require "skynet-fly.fight_frame.fight_register_type"

local position_comp = classic:extend()
position_comp.component_type = "zc_position_comp"

-- new(x, y)：接收普通数值坐标，内部转 Q16.16 定点；也可直接传已定点数（new 里不再二次换算）
position_comp.new = function(self, x, y)
    self.x = x or 0
    self.y = y or 0
    if self.x < 100000 and self.x > -100000 then self.x = fixed.from_float(self.x) end
    if self.y < 100000 and self.y > -100000 then self.y = fixed.from_float(self.y) end
end

function position_comp:setup(x, y)
    self.x = fixed.from_float(x)
    self.y = fixed.from_float(y)
end

-- 返回 Q16.16 定点坐标（战斗层在实体装配完成后经此读取确定性坐标）
function position_comp:get_position()
    return self.x, self.y
end

function position_comp:get_x()
    return self.x
end

function position_comp:get_y()
    return self.y
end

-- 移动：dx/dy 为 Q16.16 相对位移
function position_comp:translate(dx, dy)
    self.x = fixed.add(self.x, dx)
    self.y = fixed.add(self.y, dy)
end

-- 直接取整坐标（调试/展示用）
function position_comp:get_float_position()
    return fixed.to_float(self.x), fixed.to_float(self.y)
end

-- 通过 fight_register_type 模块自注册组件类型
fight_register_type.register("component", position_comp.component_type, position_comp)

return position_comp
