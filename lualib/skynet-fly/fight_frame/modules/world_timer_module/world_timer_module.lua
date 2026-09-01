-- world_timer_module 世界定时器模块：帧驱动 + 世界时间
-- 与 skynet-fly.timer（skynet.timeout 时间轮，墙钟驱动）不同：
--   1. 由 fight_world 每帧 on_update 驱动（不依赖 skynet.timeout）
--   2. 时间基准用世界时间 self._world.total_time（Q16.16 定点秒），
--      帧同步/回放/录像下与帧时间线严格对齐（确定性）
-- 适用场景：
--   * 战斗内的冷却/持续时长/延时结算（要求跨端回放一致）
--   * 不想让游戏逻辑依赖墙钟定时器的场合
-- 注意：
--   * 回调**同步执行**（x_pcall），不 fork —— 帧内顺序确定，回放一致
--   * 定时器在本模块的 _timers 列表持有；world 销毁（on_remove）时全部清空，
--     不会像 supply_module 旧实现那样漏取消（世界已销毁仍被墙钟定时器回调）
--   * expire 单位为 Q16.16 定点秒：1 秒 = fixed.ONE（65536），可用 M.second * N
--     （M.second = fixed.ONE，与 timer.lua 的 M.second=100 语义对齐，只是基数不同）
--   * 与 timer.lua 的差异：帧驱动无对象池，release() 仅释放句柄引用、不阻止回调（见 timer_methods:release）

local MODULE_NAME = "world_timer_module"

local classic = require "skynet-fly.classic"
local fixed   = require "skynet-fly.fixed"
local log     = require "skynet-fly.log"

local TIMES_LOOP = 0      -- 循环触发标记（与 timer.lua 一致）
local x_pcall    = x_pcall

local M = classic:extend()

function M:on_init()
    self._timers = {}     -- 活跃定时器列表（数组，帧驱动遍历）
end

function M:on_remove()
    -- 世界销毁：清空全部定时器（防泄漏，旧定时器回调不再访问已销毁 world）
    self._timers = {}
end

-- 当前世界时间（Q16.16 定点秒）
function M:now()
    return self._world.total_time or 0
end

-- ===========================================================================
-- 定时器句柄方法（t 的 metatable __index 指向此表）
-- 句柄方法里 self 是定时器对象 t，通过 t._module 反查所属模块
-- ===========================================================================
local timer_methods = {}

-- 取消定时器
function timer_methods:cancel()
    if self.is_cancel then return self end
    self.is_cancel = true
    return self
end

-- 回调执行完再注册下一次（默认先注册下次再执行回调）
-- 帧驱动下用于“回调内决定是否续期”的场景：回调内 cancel 后不会重挂
function timer_methods:after_next()
    self.is_after_next = true
    return self
end

-- 延时：把下次触发时间往后推 ex_expire（Q16.16 定点秒）
function timer_methods:extend(ex_expire)
    if self.is_cancel or self.is_over then return self end
    local now    = self._module:now()
    local remain = self.expire_time - now
    if remain < 0 then remain = 0 end
    self.expire      = self.expire + ex_expire
    self.expire_time = now + remain + ex_expire
    return self
end

-- 剩余触发时间（Q16.16 定点秒，0 表示已终结/取消）
function timer_methods:remain_expire()
    if self.is_cancel or self.is_over then return 0 end
    local remain = self.expire_time - self._module:now()
    if remain < 0 then remain = 0 end
    return remain
end

-- 是否已取消
function timer_methods:is_cancelled()
    return self.is_cancel
end

-- 是否已结束（触发次数耗尽）
function timer_methods:is_finished()
    return self.is_over
end

-- 是否循环定时器（times=0）
function timer_methods:is_loop()
    return self.times == TIMES_LOOP
end

-- 剩余触发次数（循环定时器返回 -1，已结束/取消返回 0）
function timer_methods:remain_times()
    if self.is_cancel or self.is_over then return 0 end
    if self.times == TIMES_LOOP then return -1 end
    return self.times - self.cur_times
end

-- 是否有效（未取消且未结束）
function timer_methods:is_valid()
    return not self.is_cancel and not self.is_over
end

-- 释放用户对定时器的引用
-- 与 timer.lua 对齐：release 不取消定时器、不阻止回调（回调照常触发），
-- 只是“我不再持有句柄引用”。帧驱动无对象池，无需归还动作，实现为空操作。
function timer_methods:release()
    return self
end

-- ===========================================================================
-- 定时器创建
-- ===========================================================================

-- 创建定时器对象（返回带方法的句柄，句柄方法见 timer_methods）
-- @param expire number Q16.16 定点秒（1 秒 = fixed.ONE），间隔时长（0 = 下帧触发）
-- @param times  number 触发次数，0 表示循环触发
-- @param callback function 回调
-- @param ... 回调参数
-- @return table 定时器句柄
-- 注意：本方法是双形态 —— fight_world:add_module 用 module() 实例化模块时会
-- 经 classic.__call 无参调用 new 作为构造器（on_init 做真正初始化，此处直接返回）；
-- 定时器创建必须传 expire（可为 0，但非 nil）。由此保证 timer.lua 的 new 语义可用。
function M:new(expire, times, callback, ...)
    if expire == nil then
        -- classic 构造器路径（module() 实例化）
        return
    end
    assert(expire >= 0, MODULE_NAME .. " expire must >= 0")
    assert(times and times >= 0, MODULE_NAME .. " times must >= 0")
    assert(type(callback) == "function", MODULE_NAME .. " callback must be function")

    local now = self:now()
    local t = {
        _module     = self,          -- 反查模块（cancel/remain 用）
        expire      = expire,        -- 间隔（Q16.16 定点秒）
        times       = times,         -- 剩余触发次数（0=循环）
        callback    = callback,
        args        = {n = select('#', ...), ...},
        expire_time = now + expire,  -- 下次到期世界时间
        cur_times   = 0,             -- 已触发次数
        is_cancel   = false,
        is_over     = false,
        is_after_next = false,       -- 回调执行完再注册下次（默认先注册再执行）
    }
    self._timers[#self._timers + 1] = t
    return setmetatable(t, {__index = timer_methods})
end

-- 快捷：单次触发（times=1）
-- 注意用 self:new 而非 M:new —— M 是类，self 才是当前模块实例（持有 _world）
function M:once(expire, callback, ...)
    return self:new(expire, 1, callback, ...)
end

-- 快捷：循环触发（times=0）
function M:new_loop(expire, callback, ...)
    return self:new(expire, TIMES_LOOP, callback, ...)
end

-- ===========================================================================
-- 每帧驱动（fight_world 调用）：检查到期定时器并同步执行回调
-- 同一帧内不复查刚触发的定时器（i+1 推进），因此 expire=0 不会本帧死循环：
--   * once(0)     → 下帧触发一次
--   * new_loop(0) → 每帧触发
-- ===========================================================================
function M:on_update()
    local timers = self._timers
    local n = #timers
    if n == 0 then return end

    local now = self:now()
    local i = 1
    while i <= n do
        local t = timers[i]
        if t.is_cancel or t.is_over then
            -- 终结/取消：交换移除（勿递增 i，回填的元素还需检查）
            timers[i] = timers[n]
            timers[n] = nil
            n = n - 1
        elseif now >= t.expire_time then
            local loop = t.times == TIMES_LOOP
            t.cur_times = t.cur_times + 1
            if not (loop or t.cur_times < t.times) then
                t.is_over = true   -- 末次触发
            end

            if t.is_after_next then
                -- after_next 模式：先执行回调（回调内可 cancel/决定是否续期），
                -- 回调未取消且未终结才注册下次（间隔从当前时刻起算，对齐 timer.lua）
                self:_fire(t)
                if not t.is_cancel and not t.is_over then
                    t.expire_time   = now + t.expire
                    t.is_after_next = false
                end
            else
                -- 默认模式：先注册下次（固定间隔累加，不追赶），再执行回调
                if not t.is_over then
                    t.expire_time = t.expire_time + t.expire
                end
                self:_fire(t)
            end

            if t.is_cancel or t.is_over then
                timers[i] = timers[n]
                timers[n] = nil
                n = n - 1
            else
                i = i + 1
            end
        else
            i = i + 1
        end
    end
end

-- 执行回调（同步 x_pcall，帧内确定性；参数解包）
function M:_fire(t)
    local is_ok, err = x_pcall(t.callback, table.unpack(t.args, 1, t.args.n))
    if not is_ok then
        log.error(string.format("%s callback err: %s", MODULE_NAME, err))
    end
end

-- 循环标记（与 timer.lua 一致）
M.loop   = TIMES_LOOP
-- 时间常量（Q16.16 定点秒：1 秒 = fixed.ONE）
M.second = fixed.ONE
M.minute = fixed.ONE * 60
M.hour   = fixed.ONE * 3600
M.day    = fixed.ONE * 86400

return M
