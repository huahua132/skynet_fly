# 技能：共享配置读取（share_config）

> **适用场景**: 在服务模块中读取 load_mods.lua 中 share_config_m 定义的全局配置
> **关键词**: share_config, share_config_m, share_config.get, 全局配置, 配置读取

---

## 快速上手

```lua
local share_config = require "skynet-fly.etc.share_config"

function CMD.start(config)
    -- 获取 share_config_m.default_arg.server_cfg
    local server_cfg = share_config.get("server_cfg")
    log.info("loglevel:", server_cfg.loglevel)
    return true
end
```

---

## 定义配置（在 load_mods.lua 中）

```lua
share_config_m = {
    launch_seq = 1,
    launch_num = 1,
    default_arg = {
        -- 所有 default_arg 下的 key 都可以通过 share_config.get(key) 获取

        server_cfg = {
            loglevel   = "info",    -- 日志级别
            thread     = 8,
            debug_port = 9001,
            svr_id     = 1,
            svr_name   = "game",
            svr_type   = 1,
        },

        mysql = {
            admin = { host='127.0.0.1', port='3306', user='root', password='123456', database='admin' }
        },

        redis = {
            default = { host='127.0.0.1', port=6379, auth='' }
        },

        room_game_login = {
            gateconf   = { address='0.0.0.0', port=8001, maxclient=2048 },
            login_plug = "login.login_plug",
        },

        my_custom_cfg = {
            max_player = 1000,
            reward_rate = 0.95,
        },
    }
},
```

---

## 读取配置

```lua
local share_config = require "skynet-fly.etc.share_config"

-- 获取某个配置项（参数 = default_arg 的 key）
local server_cfg   = share_config.get("server_cfg")
local mysql_cfg    = share_config.get("mysql")
local my_cfg       = share_config.get("my_custom_cfg")
local login_cfg    = share_config.get("room_game_login")

-- 使用配置
local max_player = my_cfg.max_player
local db_host    = mysql_cfg.admin.host
local port       = login_cfg.gateconf.port
```

---

## 完整使用示例

### 场景1：服务启动时读取配置

```lua
local share_config = require "skynet-fly.etc.share_config"
local log = require "skynet-fly.log"

local g_cfg = nil

function CMD.start(config)
    -- 可以在 start 中读取 share_config
    g_cfg = share_config.get("my_custom_cfg")
    log.info("max_player:", g_cfg.max_player)
    return true
end
```

### 场景2：读取服务器基础信息

```lua
local share_config = require "skynet-fly.etc.share_config"
local env_util     = require "skynet-fly.utils.env_util"

function CMD.start(config)
    local server_cfg = share_config.get("server_cfg")
    log.info("服务器ID:", env_util.get_svr_id())
    log.info("日志级别:", server_cfg.loglevel)
    return true
end
```

### 场景3：HTTP服务中读取配置

```lua
-- apps/webapp_dispatch.lua
local share_config = require "skynet-fly.etc.share_config"

function M.init()
    local my_cfg = share_config.get("my_custom_cfg")

    app:get("/info", function(c)
        c.res:set_json_rsp({
            max_player = my_cfg.max_player
        })
    end)

    app:run()
end
```

---

## 注意事项

| 注意点 | 说明 |
|--------|------|
| share_config 已自动 register | 内部已 register share_config_m，无需手动 register |
| 有本地缓存 | share_config.get 有缓存，share_config_m 热更后自动清空缓存 |
| share_config_m 最先启动 | launch_seq 要最小（通常为1），其他服务才能正确读取 |
| 只能读 default_arg | share_config.get 只能获取 share_config_m.default_arg 下的 key |
| CMD.start 中可以读取 | 与 container_client 不同，share_config 在 start 中可以使用 |
