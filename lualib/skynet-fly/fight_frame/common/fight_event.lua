local MODULE_NAME = "fight_event"


-- 用 classic 定义 fight_event 事件引擎
local classic = require "skynet-fly.classic"
local log = require "skynet-fly.log"
local fight_event = classic:extend()

local function _log_error(event_name, err)
    log.error(string.format("%s.trigger_event: event_name=[%s] error: %s", MODULE_NAME, event_name, tostring(err)))
end

fight_event.new = function(self)
    self._listeners = {}
    self._trigger_depths = {}
    self._pending_ops = {}
end

function fight_event:add_listener(event_name, listener)
    if type(listener) ~= "function" then
        return
    end
    if self._trigger_depths[event_name] and self._trigger_depths[event_name] > 0 then
        local pending = self._pending_ops[event_name]
        if not pending then
            pending = {}
            self._pending_ops[event_name] = pending
        end
        pending[#pending + 1] = {listener = listener, is_add = true}
        return
    end
    local list = self._listeners[event_name]
    if not list then
        list = {}
        self._listeners[event_name] = list
    end
    for _, l in ipairs(list) do
        if l == listener then
            return
        end
    end
    list[#list + 1] = listener
end

function fight_event:remove_listener(event_name, listener)
    if type(listener) ~= "function" then
        return
    end
    if self._trigger_depths[event_name] and self._trigger_depths[event_name] > 0 then
        local pending = self._pending_ops[event_name]
        if not pending then
            pending = {}
            self._pending_ops[event_name] = pending
        end
        pending[#pending + 1] = {listener = listener, is_add = false}
        return
    end
    local list = self._listeners[event_name]
    if not list then
        return
    end
    for i = #list, 1, -1 do
        if list[i] == listener then
            table.remove(list, i)
        end
    end
    if #list == 0 then
        self._listeners[event_name] = nil
    end
end

function fight_event:trigger_event(event_name, ...)
    local list = self._listeners[event_name]
    if not list or #list == 0 then
        return
    end
    self._trigger_depths[event_name] = (self._trigger_depths[event_name] or 0) + 1
    local count = #list
    for i = 1, count do
        local listener = list[i]
        if listener then
            local ok, err = pcall(listener, ...)
            if not ok then
                _log_error(event_name, err)
            end
        end
    end
    -- 深度递减加 or 0 防御：dispatch 期间实体移除可能清空 _trigger_depths（event_comp:clear），
    -- 深度丢失时按 0 处理（完成本层 dispatch），避免算术报错
    self._trigger_depths[event_name] = (self._trigger_depths[event_name] or 0) - 1
    if self._trigger_depths[event_name] <= 0 then
        self._trigger_depths[event_name] = nil
        local pending = self._pending_ops[event_name]
        if pending then
            for _, op in ipairs(pending) do
                if op.is_add then
                    self:add_listener(event_name, op.listener)
                else
                    self:remove_listener(event_name, op.listener)
                end
            end
            self._pending_ops[event_name] = nil
        end
    end
end

function fight_event:clear()
    self._listeners = {}
    self._trigger_depths = {}
    self._pending_ops = {}
end

return fight_event
