# 技能：使用日志系统

> **适用场景**: 在 skynet_fly 服务中记录日志、调试、错误上报
> **关键词**: log, log.info, log.error, log.warn, log.debug, log.fatal, add_hook, loglevel, 日志钩子

---

## 快速上手

```lua
local log = require "skynet-fly.log"

log.info("普通信息", var1, var2)     -- 多参数自动序列化
log.debug("调试信息", ...)
log.warn("警告信息", ...)
log.error("错误信息", ...)
log.fatal("致命错误", ...)
```

---

## API 速查

### 基础日志（多参数自动转为字符串）

```lua
local log = require "skynet-fly.log"

log.info("消息", table_var, num_var, str_var)  -- 自动 dump 每个参数
log.debug("调试", ...)
log.warn("警告", ...)
log.error("错误", ...)
log.fatal("致命", ...)
```

### 格式化日志（类似 string.format）

```lua
log.info_fmt("玩家 %d 登录，账号: %s", player_id, account)
log.debug_fmt("状态: %s, 耗时: %.2fms", state, cost)
log.warn_fmt(...)
log.error_fmt(...)
log.fatal_fmt(...)
```

### 日志钩子（add_hook）

```lua
-- 添加钩子：某个级别的日志触发时执行自定义函数
log.add_hook(log.ERROR, function(log_str)
    -- 错误日志上报（如告警系统）
    send_alert(log_str)
end)

log.add_hook(log.FATAL, function(log_str)
    -- 致命错误：发邮件/短信通知
    notify_admin(log_str)
end)
```

---

## 日志级别说明

| 级别常量 | 说明 | 适用场景 |
|---------|------|---------|
| `log.DEBUG = -1` | 调试信息（最详细） | 开发调试 |
| `log.INFO = 0` | 普通信息 | 重要业务流程 |
| `log.WARN = 2` | 警告 | 非预期但可恢复的情况 |
| `log.ERROR = 3` | 错误 | 需要关注的错误 |
| `log.FATAL = 4` | 致命错误 | 严重故障，需立即处理 |

---

## 日志级别配置

在 `load_mods.lua` 中通过 `share_config_m` 配置：

```lua
share_config_m = {
    launch_seq = 1, launch_num = 1,
    default_arg = {
        server_cfg = {
            loglevel = "info",   -- debug / info / warn / error / fatal
        }
    }
}
```

低于配置级别的日志不会输出。例如设置 `"warn"` 时，`log.info` 和 `log.debug` 不会输出。

---

## 典型使用场景

### 场景1：服务模块中的标准日志

```lua
local log = require "skynet-fly.log"

function CMD.start(config)
    log.info("服务启动", config)
    return true
end

function CMD.exit()
    log.info("服务退出")
    return true
end

function CMD.my_cmd(player_id, data)
    log.debug("收到请求", player_id, data)

    local ok, err = process(player_id, data)
    if not ok then
        log.error("处理失败", player_id, err)
        return false, err
    end

    log.info("处理成功", player_id)
    return true
end
```

### 场景2：错误日志钩子（告警上报）

```lua
local log = require "skynet-fly.log"
local container_client = require "skynet-fly.client.container_client"

-- loading阶段注册钩子（钩子在loading阶段就可以注册）
log.add_hook(log.ERROR, function(log_str)
    -- 异步上报，不阻塞日志输出
    skynet.fork(function()
        -- 发送到告警服务
    end)
end)
```

### 场景3：格式化日志（统一格式）

```lua
-- 统一加前缀
local function player_log(player_id, ...)
    log.info_fmt("[player:%d] %s", player_id, string.format(...))
end

player_log(10001, "进入房间 table_id=%d", table_id)
-- 输出: [player:10001] 进入房间 table_id=5
```

---

## 注意事项

| 注意点 | 说明 |
|--------|------|
| 不用 print | 用 `log.info` 替代 `print`，日志会带时间、服务名、行号信息 |
| 自动序列化 | 普通版本（非 fmt）会自动 dump 所有参数，table 也能直接打印 |
| 日志格式 | 输出格式：`[级别][跟踪标记][服务名][文件:行号]消息` |
| add_hook 时机 | 可以在 loading 阶段（文件顶层）注册钩子 |
| 多个钩子 | 同一级别可添加多个钩子，按注册顺序依次调用 |
| fatal vs error | `fatal` 语义上表示不可恢复的错误，但框架不会因此崩溃 |
