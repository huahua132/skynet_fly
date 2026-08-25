-- 事件组件：用 fight_register_type 模块自注册组件类型
local classic = require "skynet-fly.classic"
local fight_event = hotfix_require "skynet-fly.fight_frame.common.fight_event"
local fight_register_type = require "skynet-fly.fight_frame.fight_register_type"

-- 用 classic 定义事件组件
local event_comp = classic:extend()
event_comp.component_type = "event_comp"

function event_comp:on_init()
    self._event = fight_event()
end

function event_comp:on_remove()
    if self._event then
        self._event:clear()
        self._event = nil
    end
end


function event_comp:add_listener(event_name, listener)
    if self._event then
        self._event:add_listener(event_name, listener)
    end
end

function event_comp:remove_listener(event_name, listener)
    if self._event then
        self._event:remove_listener(event_name, listener)
    end
end

function event_comp:trigger_event(event_name, ...)
    if self._event then
        self._event:trigger_event(event_name, ...)
    end
end

-- 通过 fight_register_type 模块自注册组件类型
fight_register_type.register("component", event_comp.component_type, event_comp)

return event_comp
