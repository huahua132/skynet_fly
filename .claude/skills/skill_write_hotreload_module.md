# 技能：编写可热更模块（_m.lua）

> **适用场景**: 新建一个可热更的业务服务模块
> **关键词**: _m.lua, CMD, start, exit, 热更模块, 可热更服务, module

---

## ⚡ 最简模板

```lua
-- module/my_service_m.lua
local log = require "skynet-fly.log"

local CMD = {}

function CMD.start(config)
    log.info("my_service start")
    return true   -- ★ 必须返回true
end

function CMD.exit()
    return true   -- ★ 必须返回true
end

return CMD        -- ★ return CMD（不是container_interface）
```

---

## ⚠️ 必须遵守的规则（写之前先看）

| 规则 | 错误写法 | 正确写法 |
|------|---------|---------|
| 文件命名 | `my_service.lua` | `my_service_m.lua`，放 `module/` 目录 |
| 返回方式 | `container_interface(CMD)` | `return CMD` |
| register时机 | 在 `CMD.start` 里调用 | **文件顶层（loading阶段）**调用 |
| start阶段访问服务 | `CMD.start` 里调 `container_client:instance()` | start里**不能**访问其他热更服务 |
| start返回值 | 忘记写 return | `return true`（false=启动失败） |
| exit返回值 | 忘记写 return | `return true`（false=不销毁） |
| 互访设置 | 两个热更服务互访不设置 | 必须一方调用 `set_week_visitor` |

---

## 📋 完整模板（含服务调用、定时器）

```lua
-- module/my_service_m.lua
local log            = require "skynet-fly.log"
local container_client = require "skynet-fly.client.container_client"
local timer          = require "skynet-fly.timer"

-- ============================================================
-- ★ loading阶段（文件顶层）：注册要访问的其他模块
--   不能放在CMD.start里！
-- ============================================================
container_client:register("other_m")

-- 两个热更服务互访时，必须一方设置弱访问者（避免旧服务无法退出）
container_client:set_week_visitor("other_m")

-- 旧服务版本也能访问新版other_m（可选，按需）
container_client:set_always_swtich("other_m")

-- other_m就绪时回调（可选）
container_client:add_queryed_cb("other_m", function()
    log.info("other_m 已就绪")
end)

-- other_m热更后回调（可选，通常用于清缓存）
container_client:add_updated_cb("other_m", function()
    log.info("other_m 已热更，清理缓存")
end)

-- ============================================================
-- 模块内部状态
-- ============================================================
local g_config = nil   -- 保存启动配置

local CMD = {}

-- ============================================================
-- ★ 必须实现：启动函数
--   config = load_mods 中对应的 default_arg 或 mod_args
--   ⚠️ 此处不能调用其他热更服务
-- ============================================================
function CMD.start(config)
    g_config = config
    log.info("my_service start, config:", config)

    -- 启动循环定时器（5秒执行一次）
    timer:new(timer.second * 5, timer.loop, function()
        -- 在定时器回调中可以访问其他服务（start已经结束）
        local ret = container_client:instance("other_m"):balance_call("ping")
        log.info("other_m pong:", ret)
    end)

    return true  -- ★ 必须返回true，返回false=启动失败
end

-- ============================================================
-- ★ 必须实现：退出函数
-- ============================================================
function CMD.exit()
    log.info("my_service exit")
    return true  -- true=可退出并10分钟后销毁，false=不销毁
end

-- ============================================================
-- 可选：热更新生命周期钩子
-- ============================================================

-- 热更时，新服务启动前通知旧服务（旧服务此时还在处理请求）
function CMD.herald_exit()
    log.info("收到预告退出通知，准备切换")
end

-- 确认被新服务替代（新服务已成功启动）
function CMD.fix_exit()
    log.info("已确认被新服务替代")
end

-- 新服务启动失败，旧服务继续运行（取消退出）
function CMD.cancel_exit()
    log.info("新服务启动失败，旧服务继续运行")
end

-- 检查能否退出（可加自定义条件，不实现默认返回true）
function CMD.check_exit()
    -- 例如：检查是否还有未处理的订单
    -- if has_pending_orders() then return false end
    return true
end

-- ============================================================
-- 自定义业务命令（被其他服务 call/send 调用）
-- ============================================================
function CMD.ping()
    return "pong from my_service"
end

function CMD.get_config()
    return g_config
end

-- ★ return CMD（不是 container_interface(CMD)）
return CMD
```

---

## 📁 配套 load_mods.lua 配置

```lua
-- 单实例
my_service_m = {
    launch_seq = 10,    -- 启动顺序（数字越小越先）
    launch_num = 1,     -- 实例数
    default_arg = {     -- 传给 CMD.start(config) 的参数
        interval = 5,
        max_retry = 3,
    },
},

-- 多实例（用instance_name分组）
my_service_m = {
    launch_seq = 10,
    launch_num = 3,
    mod_args = {        -- 每个实例的独立配置，数量=launch_num
        { instance_name = "s1", role = "master" },
        { instance_name = "s2", role = "slave" },
        { instance_name = "s3", role = "slave" },
    },
    delay_run = true,           -- 延迟运行（让其他依赖服务先启动）
    is_record_on = false,       -- 是否启动服务录像
    auto_reload = {             -- 自动定时热更
        type = "hour",          -- month/day/hour/min/sec/wday/yday
        hour = 3,               -- 每天3点热更
    },
},
```

---

## 🔄 热更新流程说明

```
1. 修改 my_service_m.lua 代码
2. 执行: sh make/script/check_reload.sh load_mods.lua
3. 框架检测到文件变更：
   a. 启动新版本服务（新CMD.start被调用）
   b. 新服务启动成功 → 通知旧服务 herald_exit
   c. 路由新请求到新服务，旧服务处理存量请求
   d. 旧服务无访问者 → 调用旧服务 fix_exit
   e. 旧服务 CMD.exit() 返回true → 10分钟后销毁
4. 若新服务 CMD.start 返回false：
   → 旧服务 cancel_exit 被调用，旧服务继续运行
```

---

## 📌 常见场景补充

### 两个热更服务互访（A ↔ B）

```lua
-- A_m.lua
container_client:register("B_m")
container_client:set_week_visitor("B_m")  -- A是弱访问者

-- B_m.lua
container_client:register("A_m")
-- B不需要设置，只需A设置即可（一方设置即可）
```

### 访问同一模块的不同instance_name组

```lua
-- load_mods.lua 中定义了：
-- mod_args = { {instance_name="s1"}, {instance_name="s2"} }

-- 访问s1组
local s1 = container_client:instance("my_service_m", "s1")
s1:balance_call_by_name("cmd")

-- 访问所有实例（广播）
local all = container_client:instance("my_service_m")
all:broadcast_call("cmd")
```

### start里读取share_config配置

```lua
local share_config = require "skynet-fly.etc.share_config"

function CMD.start(config)
    -- 读取share_config_m.default_arg.server_cfg
    local server_cfg = share_config.get("server_cfg")
    log.info("loglevel:", server_cfg.loglevel)
    return true
end
```
