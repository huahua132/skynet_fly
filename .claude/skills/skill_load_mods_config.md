# 技能：编写 load_mods.lua 配置

> **适用场景**: 为一个 skynet_fly 项目配置启动模块、实例数量、参数传递
> **关键词**: load_mods.lua, launch_seq, launch_num, mod_args, default_arg, instance_name, delay_run, auto_reload

---

## ⚡ 最简 load_mods.lua

```lua
-- load_mods.lua（每个项目根目录下）
return {
    share_config_m = {        -- ★ 通常第一个启动
        launch_seq = 1,
        launch_num = 1,
        default_arg = {
            server_cfg = {
                loglevel = "info",   -- debug/info/warn/error/fatal
                thread = 8,
            }
        }
    },

    my_service_m = {
        launch_seq = 2,
        launch_num = 1,
    },
}
```

---

## 📋 全量参数说明

| 参数 | 类型 | 说明 |
|------|------|------|
| `launch_seq` | number | 启动顺序，**数字越小越先启动** |
| `launch_num` | number | 启动实例数量 |
| `default_arg` | table | 所有实例共享的默认配置，传给 `CMD.start(config)` |
| `mod_args` | table[] | 每个实例的独立配置列表，长度必须等于 `launch_num`，优先级高于 `default_arg` |
| `instance_name` | string | 实例分组名（定义在 mod_args 内），通过 `container_client:instance(mod, name)` 按组访问 |
| `delay_run` | bool | `true` = 延迟运行（等其他服务启动完再启动，适合客户端模拟等） |
| `is_record_on` | bool | `true` = 开启服务录像 |
| `auto_reload` | table | 自动定时热更配置（见下方说明） |
| `record_backup` | table | 录像文件保留策略（配合 `is_record_on` 使用） |

### auto_reload 配置

```lua
auto_reload = {
    type = "hour",   -- 热更类型: month / day / hour / min / sec / wday / yday
    hour = 3,        -- 对应类型的具体值（如每天3点）
}
```

---

## 📋 场景模板大全

### 场景1：单实例服务 + 默认参数

```lua
my_service_m = {
    launch_seq = 10,
    launch_num = 1,
    default_arg = {
        max_conn = 1000,
        timeout  = 30,
    }
},
```

---

### 场景2：多实例服务 + 每实例独立参数（用 mod_args）

```lua
-- 注意：mod_args 的数量必须等于 launch_num
my_service_m = {
    launch_seq = 10,
    launch_num = 3,
    mod_args = {
        {instance_name = "s1", role = "master", port = 8001},
        {instance_name = "s2", role = "slave",  port = 8002},
        {instance_name = "s3", role = "slave",  port = 8003},
    },
},
```

在模块中读取：
```lua
function CMD.start(config)
    -- config = {instance_name="s1", role="master", port=8001}
    log.info("role:", config.role, "port:", config.port)
    return true
end
```

---

### 场景3：default_arg + mod_args 混用（mod_args 优先）

```lua
my_service_m = {
    launch_seq = 10,
    launch_num = 3,
    default_arg = {
        timeout = 30,       -- 所有实例都有
        max_retry = 3,      -- 所有实例都有
    },
    mod_args = {
        {instance_name = "s1", role = "master"},   -- s1有role，也继承timeout和max_retry
        {instance_name = "s2", role = "slave"},
        {instance_name = "s3", role = "slave"},
    },
},
```

---

### 场景4：延迟启动（delay_run）

```lua
-- 适用于：测试客户端、需要其他服务完全就绪才能运行的模块
test_client_m = {
    launch_seq = 100,
    launch_num = 2,
    delay_run = true,    -- ★ 在 main.lua 的 delay_run() 调用后才启动
    mod_args = {
        {account = "user1", password = "123456"},
        {account = "user2", password = "123456"},
    },
},
```

对应 main.lua：
```lua
skynet.start(function()
    local delay_run = container_launcher.run()
    delay_run()   -- ★ 这里才启动 delay_run=true 的模块
    skynet.exit()
end)
```

---

### 场景5：自动定时热更（auto_reload）

```lua
my_service_m = {
    launch_seq = 10,
    launch_num = 1,
    auto_reload = {
        type = "hour",   -- 每天整点检查
        hour = 3,        -- 每天 3 点自动热更
    },
},
```

其他 type 示例：
```lua
auto_reload = { type = "min",   min = 30 }   -- 每小时30分
auto_reload = { type = "day",   day = 1  }   -- 每月1号
auto_reload = { type = "wday",  wday = 2 }   -- 每周一（1=周日,2=周一...）
```

---

### 场景6：完整 HTTP 服务配置

```lua
return {
    share_config_m = {
        launch_seq = 1,
        launch_num = 1,
        default_arg = {
            server_cfg = { loglevel = "info", thread = 8 }
        }
    },

    web_agent_m = {
        launch_seq = 2,
        launch_num = 8,        -- 并发处理数（越大并发能力越强）
        default_arg = {
            protocol          = 'http',
            dispatch          = 'apps.webapp_dispatch',   -- dispatch模块路径（require路径格式）
            keep_alive_time   = 300,                      -- 最长保活时间（秒）
            second_req_limit  = 2000,                     -- 每秒请求数限制
        }
    },

    web_master_m = {
        launch_seq = 3,
        launch_num = 1,
        default_arg = {
            protocol          = 'http',
            port              = 8688,
            max_client        = 30000,
            second_conn_limit = 30000,    -- 相同IP每秒建立连接数限制
            keep_live_limit   = 30000,    -- 相同IP保持活跃连接数限制
        }
    },
}
```

---

### 场景7：完整房间游戏配置

```lua
return {
    share_config_m = {
        launch_seq = 1,
        launch_num = 1,
        default_arg = {
            room_game_login = {
                gateconf   = { address = '0.0.0.0', port = 8001, maxclient = 2048 },
                wsgateconf  = { address = '0.0.0.0', port = 8002, maxclient = 2048 },
                login_plug = "login.login_plug",
            },
            server_cfg = { loglevel = "info" },
        }
    },

    room_game_hall_m = {
        launch_seq = 2,
        launch_num = 6,
        default_arg = { hall_plug = "hall.hall_plug" }
    },

    room_game_alloc_m = {
        launch_seq = 3,
        launch_num = 1,
        default_arg = {
            alloc_plug     = "alloc.alloc_plug",
            MAX_TABLES     = 10000,
            max_empty_time = 60,
        }
    },

    room_game_table_m = {
        launch_seq = 4,
        launch_num = 6,
        mod_args = {
            {instance_name = "room_1", table_plug = "table.table_plug", table_conf = {player_num = 2}},
            {instance_name = "room_2", table_plug = "table.table_plug", table_conf = {player_num = 2}},
            {instance_name = "room_3", table_plug = "table.table_plug", table_conf = {player_num = 4}},
            {instance_name = "room_4", table_plug = "table.table_plug", table_conf = {player_num = 4}},
            {instance_name = "room_5", table_plug = "table.table_plug", table_conf = {player_num = 6}},
            {instance_name = "room_6", table_plug = "table.table_plug", table_conf = {player_num = 6}},
        },
    },
}
```

---

### 场景8：ORM 数据库配置

```lua
return {
    share_config_m = {
        launch_seq = 1,
        launch_num = 1,
        default_arg = {
            mysql = {
                -- key名对应 ormadapter_mysql:new("admin") 中的参数
                admin = {
                    host     = '127.0.0.1',
                    port     = '3306',
                    user     = 'root',
                    password = '123456',
                    database = 'admin',
                }
            },
            server_cfg = { loglevel = "info" }
        }
    },

    orm_table_m = {
        launch_seq = 1000,
        launch_num = 2,
        mod_args = {
            {instance_name = "player", orm_plug = "orm_plug.entry_player"},
            {instance_name = "order",  orm_plug = "orm_plug.entry_order"},
        }
    },
}
```

---

## ⚠️ 常见错误

| 错误 | 正确做法 |
|------|---------|
| `mod_args` 数量与 `launch_num` 不一致 | 数量必须完全相等 |
| 在 mod_args 中不写 `instance_name` | 如需按组访问，每条 mod_args 必须有 `instance_name` |
| `launch_seq` 相同 | 推荐不同模块用不同 seq，避免启动顺序不确定 |
| share_config_m 不是最小 seq | `share_config_m` 必须最先启动（seq=1） |
| web_agent_m 和 web_master_m 顺序错误 | agent 的 seq 必须小于 master |
| `dispatch` 路径格式错误 | 使用 require 路径格式：`apps.webapp_dispatch`（不是文件路径） |
