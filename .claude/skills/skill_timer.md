# 技能：使用定时器

> **适用场景**: 在 skynet_fly 服务中设置延迟执行、循环执行、定时任务
> **关键词**: timer, timer:new, timer.loop, timer.second, cancel, extend, remain_expire, after_next

---

## 时间常量速查

```lua
local timer = require "skynet-fly.timer"

timer.second = 100      -- 1秒（skynet时间单位，100=1秒）
timer.minute = 6000     -- 1分钟
timer.hour   = 360000   -- 1小时
timer.day    = 8640000  -- 1天
timer.loop   = 0        -- 循环标志（触发次数传0=循环）
```

---

## 基本用法

### 一次性延迟执行

```lua
local timer = require "skynet-fly.timer"

-- 5秒后执行一次
local t = timer:new(
    timer.second * 5,   -- 延迟时间
    1,                  -- 触发次数（1=只触发1次）
    function(arg1, arg2)
        log.info("触发了", arg1, arg2)
    end,
    "hello", 42         -- 传给回调的参数（可选）
)
```

### 循环定时器

```lua
-- 每1分钟触发一次（无限循环）
local t = timer:new(timer.minute, timer.loop, function()
    log.info("每分钟执行")
end)

-- 每3秒执行一次，共执行5次
local t = timer:new(timer.second * 3, 5, function()
    log.info("执行")
end)
```

### 取消定时器

```lua
local t = timer:new(timer.second * 10, timer.loop, function()
    log.info("循环中")
end)

-- 某个条件下取消
t:cancel()
```

---

## 完整 API

| 方法 | 说明 |
|------|------|
| `timer:new(expire, times, callback, ...)` | 创建定时器 |
| `t:cancel()` | 取消定时器 |
| `t:after_next()` | 切换为"先执行回调再注册下一次"模式 |
| `t:extend(ex_expire)` | 延长过期时间（返回新定时器对象） |
| `t:remain_expire()` | 获取剩余触发时间（-1=已触发完/已取消） |

### timer:new 参数说明

| 参数 | 类型 | 说明 |
|------|------|------|
| `expire` | number | 触发间隔（100=1秒） |
| `times` | number | 触发次数（`timer.loop` 或 `0` = 无限循环） |
| `callback` | function | 触发时调用的函数 |
| `...` | any | 传给 callback 的参数（可选） |

---

## 进阶用法

### after_next：先执行回调再注册下一次

```lua
-- 默认行为：先注册下一次定时，再执行回调（下次触发时间从当前算）
-- after_next：先执行回调，再注册下一次（下次触发时间从回调结束后算）
-- 适用于：回调本身很耗时，不希望在回调执行期间就已经计算了下次触发时间

local t = timer:new(timer.second * 5, timer.loop, function()
    -- 这里做耗时操作
    skynet.sleep(200)  -- 假设耗时2秒
    log.info("处理完成")
end)
t:after_next()  -- 先执行完回调，再开始下一个5秒计时
```

### extend：延长过期时间

```lua
local t = timer:new(timer.second * 10, 1, function()
    log.info("过期了")
end)

-- 在过期前，延长3秒
local nt = t:extend(timer.second * 3)
-- nt 是新的定时器对象，原来的 t 已被取消
```

### remain_expire：查询剩余时间

```lua
local t = timer:new(timer.second * 10, 1, function() end)

-- 查询剩余时间（单位：skynet时间，100=1秒）
local remain = t:remain_expire()
if remain == -1 then
    log.info("已触发或已取消")
else
    log.info("还有", remain / 100, "秒触发")
end
```

---

## 典型使用场景

### 场景1：服务启动后延迟初始化

```lua
function CMD.start(config)
    -- 延迟1秒后执行初始化（等其他服务就绪）
    timer:new(timer.second, 1, function()
        local ret = container_client:instance("other_m"):balance_call("init_data")
        log.info("初始化完成:", ret)
    end)
    return true
end
```

### 场景2：心跳检测（循环定时器）

```lua
local g_timer = nil

function CMD.start(config)
    g_timer = timer:new(timer.second * 30, timer.loop, function()
        -- 每30秒检查一次连接状态
        check_connections()
    end)
    return true
end

function CMD.exit()
    if g_timer then
        g_timer:cancel()
        g_timer = nil
    end
    return true
end
```

### 场景3：超时处理（一次性定时器 + cancel）

```lua
local function wait_with_timeout(player_id, timeout_sec, on_timeout)
    local t = timer:new(timer.second * timeout_sec, 1, function()
        log.warn("玩家操作超时:", player_id)
        on_timeout(player_id)
    end)
    return t   -- 返回定时器，让调用方在操作完成时 cancel
end

-- 使用：等待玩家操作，30秒超时
local timeout_t = wait_with_timeout(player_id, 30, function(pid)
    -- 超时处理：踢出玩家
    kick_player(pid)
end)

-- 玩家操作完成时取消超时
function on_player_action(player_id)
    timeout_t:cancel()
    -- 处理操作...
end
```

### 场景4：分批处理（循环计数）

```lua
local g_batch_count = 0

-- 每秒处理一批，共处理10批
timer:new(timer.second, 10, function()
    g_batch_count = g_batch_count + 1
    log.info("第", g_batch_count, "批处理")
    process_batch(g_batch_count)
end)
```

### 场景5：动态延迟（根据条件决定下次间隔）

```lua
local function schedule_next()
    local delay = get_next_delay()   -- 动态计算延迟
    timer:new(delay, 1, function()
        do_work()
        schedule_next()   -- 执行完后动态决定下次间隔
    end)
end

function CMD.start(config)
    schedule_next()
    return true
end
```

---

## 注意事项

| 注意点 | 说明 |
|--------|------|
| 时间单位 | skynet 时间单位 `100 = 1秒`，不要用秒数直接传 |
| 取消时机 | 在 `CMD.exit` 中取消长期持有的定时器（避免服务退出后还在触发） |
| 回调异常 | timer 内部用 `x_pcall` 保护，回调异常不会崩溃，但会打印错误日志 |
| 长间隔定时器 | 间隔 > 60秒时，timer 内部会分段 sleep（不会产生大量协程） |
| after_next | 回调耗时长时用 `after_next`，避免计时误差累积 |
| extend 返回新对象 | `extend` 取消原定时器并返回新对象，原对象引用失效 |
