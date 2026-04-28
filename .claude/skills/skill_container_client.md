# 技能：使用 container_client 调用其他服务

> **适用场景**: 在同一进程内，从一个热更服务调用另一个热更服务
> **关键词**: container_client, register, instance, balance_call, mod_call, broadcast_call, by_name, set_mod_num, 服务间调用, 内部RPC

---

## ⚡ 最快上手（3步）

```lua
-- Step1: 文件顶层（loading阶段）注册
local container_client = require "skynet-fly.client.container_client"
container_client:register("B_m")

-- Step2: CMD.start 返回 true 后就可以调用
function CMD.start(config)
    return true  -- start内部不能调用
end

-- Step3: 在业务代码/定时器/消息处理中调用
local b = container_client:instance("B_m")
local ret = b:balance_call("my_cmd", arg1, arg2)
```

---

## ⚠️ 必须遵守的规则

| 规则 | 说明 |
|------|------|
| `register` 时机 | **必须在文件顶层**（loading阶段），不能在 `CMD.start` 里 |
| `CMD.start` 内 | **不能**调用其他热更服务（服务未就绪） |
| 互访设置 | 两个热更服务互相访问时，**必须一方**调用 `set_week_visitor`，否则旧服务无法退出 |
| `instance()` 推荐 | 使用 `instance()` 获取常驻对象（自动缓存），不要每次 `new()` |

---

## 📋 初始化配置（loading阶段）

```lua
local container_client = require "skynet-fly.client.container_client"

-- ★ 必须：注册要访问的模块
container_client:register("B_m")

-- 可选：两个热更服务互访时，必须一方设置弱访问者（避免旧服务无法退出）
container_client:set_week_visitor("B_m")

-- 可选：旧版本自身也能自动切换到新版B（适用于A旧服想访问B新服）
container_client:set_always_swtich("B_m")

-- 可选：B_m 首次就绪时回调
container_client:add_queryed_cb("B_m", function()
    log.info("B_m 已就绪，可以开始调用")
end)

-- 可选：B_m 热更后回调（通常用于清理本地对B的缓存）
container_client:add_updated_cb("B_m", function()
    log.info("B_m 已热更，清理本地缓存")
    g_b_cache = nil
end)
```

---

## 📋 获取调用对象

```lua
-- ★ 推荐：instance() 返回常驻调用对象，自动缓存，多次调用返回同一对象
local b = container_client:instance("B_m")

-- 按 instance_name 分组获取（B_m 的 mod_args 中定义了 instance_name）
local b_s1 = container_client:instance("B_m", "s1")

-- 检查服务是否已就绪（start之前可能未就绪）
if container_client:is_ready("B_m") then
    local b = container_client:instance("B_m")
end

-- 临时对象（不推荐，每次创建新对象）
local b_tmp = container_client:new("B_m")
```

---

## 📋 调用方式

### 一、普通调用（无 instance_name 分组）

```lua
local b = container_client:instance("B_m")

-- 轮询负载均衡（自动选下一个实例）
local ret = b:balance_call("cmd", arg1, arg2)    -- 有返回值，协程等待
b:balance_send("cmd", arg1, arg2)                -- 无需等待返回

-- hash映射（相同mod_num总是路由到同一实例）
local ret = b:set_mod_num(player_id):mod_call("cmd", arg1)   -- 按player_id固定路由
b:set_mod_num(player_id):mod_send("cmd", arg1)

-- 广播（发给所有实例）
local ret_map = b:broadcast_call("cmd", ...)   -- 返回 {服务id = {返回值列表}} 的map
b:broadcast("cmd", ...)                        -- 广播 send
```

### 二、按 instance_name 分组调用

```lua
-- B_m 的 mod_args 中有：{instance_name = "s1", ...}, {instance_name = "s2", ...}
local b_s1 = container_client:instance("B_m", "s1")   -- 只访问 instance_name="s1" 的实例组

b_s1:balance_call_by_name("cmd")                -- 组内轮询 call
b_s1:balance_send_by_name("cmd")                -- 组内轮询 send
b_s1:set_mod_num(1):mod_call_by_name("cmd")     -- 组内 hash call
b_s1:mod_send_by_name("cmd")                    -- 组内 hash send
b_s1:broadcast_call_by_name("cmd")              -- 组内广播 call
b_s1:broadcast_by_name("cmd")                   -- 组内广播 send
```

---

## 📋 API 速查表

### 初始化API（loading阶段）

| 方法 | 说明 |
|------|------|
| `register(mod_name, ...)` | 注册要访问的模块 |
| `set_week_visitor(mod_name, ...)` | 设置弱访问者（互访必须一方设置） |
| `set_always_swtich(mod_name, ...)` | 旧服务也能切换到新服务 |
| `add_queryed_cb(mod_name, fn)` | 服务首次就绪时回调 |
| `add_updated_cb(mod_name, fn)` | 服务热更后回调 |

### 对象获取API（start之后）

| 方法 | 说明 |
|------|------|
| `instance(mod, name?)` | 获取常驻调用对象（推荐） |
| `new(mod, name?, fn?)` | 创建临时调用对象 |
| `is_ready(mod_name)` | 服务是否已就绪 |

### 调用对象方法

| 方法 | 说明 |
|------|------|
| `balance_call(cmd, ...)` | 轮询 call（有返回值） |
| `balance_send(cmd, ...)` | 轮询 send（不等返回） |
| `mod_call(cmd, ...)` | hash映射 call |
| `mod_send(cmd, ...)` | hash映射 send |
| `broadcast_call(cmd, ...)` | 广播 call（返回map） |
| `broadcast(cmd, ...)` | 广播 send |
| `balance_call_by_name(cmd, ...)` | 按instance_name组轮询 call |
| `balance_send_by_name(cmd, ...)` | 按instance_name组轮询 send |
| `mod_call_by_name(cmd, ...)` | 按instance_name组hash call |
| `mod_send_by_name(cmd, ...)` | 按instance_name组hash send |
| `broadcast_call_by_name(cmd, ...)` | 按instance_name组广播 call |
| `broadcast_by_name(cmd, ...)` | 按instance_name组广播 send |
| `set_mod_num(num)` | 设置hash映射数字（链式调用） |
| `set_instance_name(name)` | 设置instance_name（链式调用） |

---

## 📌 完整使用示例

### 示例1：A 调用 B（单向）

```lua
-- A_m.lua
local container_client = require "skynet-fly.client.container_client"
local log = require "skynet-fly.log"
local timer = require "skynet-fly.timer"

-- loading阶段注册
container_client:register("B_m")

local CMD = {}

function CMD.start(config)
    -- ⚠️ 此处不能调用 B_m
    -- 在定时器中调用
    timer:new(timer.second * 3, timer.loop, function()
        local ret = container_client:instance("B_m"):balance_call("ping")
        log.info("B reply:", ret)
    end)
    return true
end

function CMD.exit() return true end

-- 被B_m反向调用的命令
function CMD.hello()
    return "hello from A"
end

return CMD
```

### 示例2：A 和 B 互访（必须设置弱访问者）

```lua
-- A_m.lua
container_client:register("B_m")
container_client:set_week_visitor("B_m")  -- ★ A作为弱访问者

-- B_m.lua
container_client:register("A_m")
-- B 不需要设置（只需一方设置即可）
```

### 示例3：按 player_id 固定路由到同一实例

```lua
-- 保证同一 player_id 总是路由到同一个 B_m 实例
local b = container_client:instance("B_m")
local ret = b:set_mod_num(player_id):mod_call("get_player_data", player_id)
```

### 示例4：广播并收集所有实例的返回

```lua
local b = container_client:instance("B_m")
-- broadcast_call 返回: { [服务id1] = {ret1, ret2, ...}, [服务id2] = {...} }
local ret_map = b:broadcast_call("get_status")
for svr_id, rets in pairs(ret_map) do
    log.info("svr:", svr_id, "status:", rets[1])
end
```

### 示例5：热更后重建连接（利用updated_cb）

```lua
local g_b_instance = nil

container_client:register("B_m")
container_client:add_updated_cb("B_m", function()
    -- B_m 热更后，清空缓存的实例，下次访问自动获取新服务
    g_b_instance = nil
    log.info("B_m 热更，重置缓存")
end)

-- 在业务中访问 B_m
local function get_b()
    if not g_b_instance then
        g_b_instance = container_client:instance("B_m")
    end
    return g_b_instance
end
```

### 示例6：临时查询（使用 new 创建临时对象）

```lua
-- 在启动时用 new 临时查询 share_config_m（不常驻）
local confclient = container_client:new("share_config_m")
local room_cfg = confclient:mod_call("query", "room_game_login")
```

---

## 📌 call 与 send 的选择

| 场景 | 用法 |
|------|------|
| 需要返回值 | `balance_call` / `mod_call` / `broadcast_call` |
| 不需要返回值，不阻塞 | `balance_send` / `mod_send` / `broadcast` |
| 需要固定路由（如按玩家ID） | `set_mod_num(player_id):mod_call(...)` |
| 通知所有实例（如刷新配置） | `broadcast_call` / `broadcast` |
| 按房间类型访问特定组 | `instance("B_m", "room_type"):balance_call_by_name(...)` |
