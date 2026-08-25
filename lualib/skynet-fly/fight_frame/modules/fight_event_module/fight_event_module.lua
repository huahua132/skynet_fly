local MODULE_NAME = "fight_event_module"

local classic = require "skynet-fly.classic"
local fight_event = hotfix_require "skynet-fly.fight_frame.common.fight_event"

-- 用 classic 定义事件模块
local M = classic:extend()

function M:on_init()
    self._event = fight_event()
end

function M:on_remove()
    self._event:clear()
end

-- 无 update 逻辑（事件回调驱动），不实现 on_update

function M:add_listener(event_name, listener)
    self._event:add_listener(event_name, listener)
end

function M:remove_listener(event_name, listener)
    self._event:remove_listener(event_name, listener)
end

function M:trigger_event(event_name, ...)
    self._event:trigger_event(event_name, ...)
end

return M
