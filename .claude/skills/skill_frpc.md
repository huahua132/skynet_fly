# 技能：跨节点 RPC 调用（frpc）

> **适用场景**: 在不同进程/节点之间调用热更模块的函数
> **关键词**: frpc, frpc_client, frpc_client_m, 跨节点, 分布式, RPC, FRPC_MODE, watch_client, Sub/Pub
> **参考示例**: `examples/frpc_client/` / `examples/frpc_server/`

---

## 整体架构

```
[客户端节点]                           [服务端节点]
frpc_client_m (客户端)  ---TCP--->  frpc_server_m (服务端)
     |                                     |
frpc_client.lua (封装)              热更模块（test_m等）
```

---

## 三种调用模式（FRPC_MODE）

| 模式 | 常量 | 说明 |
|------|------|------|
| `one` | `frpc_client.FRPC_MODE.one` | 轮询（从多个同名节点中轮询一个） |
| `byid` | `frpc_client.FRPC_MODE.byid` | 按节点ID指定（需 `set_svr_id`） |
| `all` | `frpc_client.FRPC_MODE.all` | 广播所有同名节点 |

---

## load_mods.lua 配置

### 客户端节点

```lua
frpc_client_m = {
    launch_seq = 1, launch_num = 1,
    default_arg = {
        node_map = {
            ['frpc_s'] = {   -- 远程节点名称（svr_name）
                [1] = { svr_id=1, host="127.0.0.1:9688", secret_key='key1', is_encrypt=true },
                [2] = { svr_id=2, host="127.0.0.1:9689", secret_key='key2', is_encrypt=true },
            }
        }
    }
},
```

### 服务端节点

```lua
frpc_server_m = {
    launch_seq = 1, launch_num = 1,
    default_arg = {
        port       = 9688,
        svr_name   = "frpc_s",   -- 节点名称（客户端 node_map 的 key）
        svr_id     = 1,
        secret_key = 'key1',
        is_encrypt = true,
    }
},
```

---

## 基本调用

```lua
local frpc_client = require "skynet-fly.client.frpc_client"

-- 创建调用对象
local cli = frpc_client:new(
    frpc_client.FRPC_MODE.one,  -- 模式
    "frpc_s",                   -- 远程节点名（svr_name）
    "test_m"                    -- 远程热更模块名
)

-- 轮询 call（有返回值）
local ret = cli:balance_call("ping", arg1)
-- ret = { cluster_name="frpc_s", result={返回值} } 或 nil, errcode, errmsg

-- 轮询 send（不等返回）
cli:balance_send("hello", "data")

-- hash映射 call/send（默认用自身服务id取模）
local ret = cli:mod_call("ping", arg1)
cli:mod_send("hello", "data")

-- 广播所有实例
local ret = cli:broadcast_call("ping")
cli:broadcast("hello", "data")
```

---

## 按 instance_name 分组调用

```lua
local cli = frpc_client:new(frpc_client.FRPC_MODE.one, "frpc_s", "test_m")
cli:set_instance_name("test_one")

cli:balance_call_by_name("ping")
cli:balance_send_by_name("hello", data)
cli:mod_call_by_name("ping")
cli:mod_send_by_name("hello", data)
cli:broadcast_call_by_name("ping")
cli:broadcast_by_name("hello", data)
```

---

## 按节点ID调用（byid模式）

```lua
local cli = frpc_client:new(frpc_client.FRPC_MODE.byid, "frpc_s", "test_m")
cli:set_svr_id(1)   -- 必须指定节点ID
local ret = cli:balance_call("ping")
```

---

## 广播所有节点（all模式）

```lua
local cli = frpc_client:new(frpc_client.FRPC_MODE.all, "frpc_s", "test_m")
local ret_list, err_list = cli:balance_call("ping")
-- ret_list: [{cluster_name=..., result={...}}, ...]
-- err_list: 失败节点列表
```

---

## 常驻对象（推荐）

```lua
-- instance 获取常驻调用对象（自动缓存）
local cli = frpc_client:instance(frpc_client.FRPC_MODE.one, "frpc_s", "test_m")
local cli = frpc_client:instance(frpc_client.FRPC_MODE.one, "frpc_s", "test_m", "test_one")
```

---

## 监听节点上下线

```lua
-- 监听特定节点上线
frpc_client:watch_up("frpc_s", function(svr_name, svr_id)
    log.info("节点上线:", svr_name, svr_id)
end)

-- 监听所有节点上线
frpc_client:watch_all_up("my_handler", function(svr_name, svr_id)
    log.info("任意节点上线:", svr_name, svr_id)
end)

-- 检查节点是否活跃
frpc_client:is_active("frpc_s")        -- 是否有活跃节点
frpc_client:is_active("frpc_s", 1)     -- id=1的节点是否活跃

-- 获取所有活跃节点ID
local ids = frpc_client:get_active_svr_ids("frpc_s")
```

---

## Sub/Pub 订阅（watch_client）

```lua
local watch_client = require "skynet-fly.rpc.watch_client"

watch_client:watch("frpc_s", "channel_name", function(data)
    log.info("收到订阅消息:", data)
end)

watch_client:unwatch("frpc_s", "channel_name")
```

---

## 注意事项

| 注意点 | 说明 |
|--------|------|
| 需先配置 frpc_client_m | 客户端节点必须在 load_mods 中配置 frpc_client_m 及 node_map |
| frpc_client 已自动 register | 内部已 register frpc_client_m，无需手动 register |
| byid 模式必须 set_svr_id | 不设置会断言报错 |
| all 模式返回列表 | 多节点时返回 ret_list 和 err_list，逐一处理 |
| secret_key 要匹配 | 客户端和服务端的 secret_key 必须一致 |
| 节点名称 svr_name | node_map 的 key 就是 svr_name，需与服务端 frpc_server_m 的 svr_name 一致 |
