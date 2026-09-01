local MODULE_NAME = "fight_world"

local skynet = require "skynet"
local timer = require "skynet-fly.timer"
local fixed = require "skynet-fly.fixed"
local log = require "skynet-fly.log"

-- 用 classic 定义 world
local classic = require "skynet-fly.classic"
local world = classic:extend()

world.new = function(self, world_id)
    local now = skynet.now()
    self.id = world_id
    self._modules = {}
    self._update_modules = {}
    self.frame_count = 0
    self.total_time = 0      -- Q16.16 定点秒
    self.delta_time = 0      -- Q16.16 定点秒
    self.last_tick = now     -- 毫秒时间戳（skynet.now 原始整数）
end

function world:add_module(name, module)
    if self[name] then
        log.warn(string.format("%s.add_module: module [%s] already exists in world [%s]", MODULE_NAME, name, self.id))
        return false
    end
    local instance = module()
    instance._world = self
    self[name] = instance
    self._modules[name] = instance
    if instance.on_update then
        self._update_modules[#self._update_modules + 1] = instance
    end
    instance:on_init()
    return true
end

function world:remove_module(name)
    local module = self[name]
    if not module then
        log.warn(string.format("%s.remove_module: module [%s] not found in world [%s]", MODULE_NAME, name, self.id))
        return false
    end
    module:on_remove()
    module._world = nil
    self[name] = nil
    self._modules[name] = nil
    for i, m in ipairs(self._update_modules) do
        if m == module then
            table.remove(self._update_modules, i)
            break
        end
    end
    return true
end

function world:update()
    local now = skynet.now()
    -- 毫秒→秒并转 Q16.16 定点秒（确定性秒制时间线）
    self.delta_time = fixed.from_float((now - self.last_tick) / 1000)
    self.last_tick = now
    self.frame_count = self.frame_count + 1
    self.total_time = fixed.add(self.total_time, self.delta_time)
    for _, module in ipairs(self._update_modules) do
        module:on_update()
    end
end

function world:run(frame_rate)
    -- frame_rate 为每秒帧数；skynet tick 100 等于 1 秒，故 1 帧间隔的 tick 数 = 100 / frame_rate
    local tick = math.floor(100 / frame_rate)
    if tick < 1 then tick = 1 end
    self.frame_rate = frame_rate
    local self_ref = self
    self._timer = timer:new_loop(tick, function() self_ref:update() end)
    log.debug(string.format("%s.run: world [%s] started, frame_rate=[%d], tick=[%d]ticks", MODULE_NAME, self.id, frame_rate, tick))
end

function world:stop()
    if self._timer then
        self._timer:cancel()
        self._timer = nil
    end
end

function world:remove_all_modules()
    -- 遍历全部模块（_modules 含无 on_update 的模块，如 supply_module），
    -- 不能只遍历 _update_modules：否则无 on_update 的模块收不到 on_remove，
    -- 其内部定时器（如补给 timer）不被取消，world 销毁后仍在回调 → 解引用已 nil 的 _world 报错
    for name, module in pairs(self._modules) do
        if module.on_remove then
            module:on_remove()
        end
        module._world = nil
        self[name] = nil
    end
    self._modules = {}
    self._update_modules = {}
end

return world