# skynet_fly 项目 AI 编程指南

## 项目概述

**skynet_fly** 是基于 [skynet](https://github.com/cloudwu/skynet) 扩展的高性能游戏服务器框架，使用 **Lua** 语言开发，专注于快速开发 Web 服务、游戏服务器及分布式系统。

- **语言**: Lua 5.4
- **底层框架**: skynet（Actor模型并发框架）
- **运行平台**: Linux / macOS / Windows (VS2022 + Clang)
- **主仓库**: https://github.com/huahua132/skynet_fly
- **项目文档**: https://huahua132.github.io/2023/02/25/skynet_fly_word/word_1/A_home/
- **API文档**: https://huahua132.github.io/2023/12/17/skynet_fly_api/module/

---

## 项目目录结构

```
skynet_fly/
├── lualib/skynet-fly/         # 核心库（框架核心功能）
│   ├── loader.lua             # 服务加载器（热更新支持）
│   ├── log.lua                # 日志模块
│   ├── timer.lua              # 定时器模块
│   ├── sharedata.lua          # 共享配置数据
│   ├── snowflake.lua          # 雪花ID生成器
│   ├── hotfix/                # 热更新实现
│   ├── client/                # 内部RPC客户端
│   │   ├── container_client.lua   # 容器服务访问客户端（核心）
│   │   ├── frpc_client.lua        # 远程RPC客户端（跨节点）
│   │   └── orm_frpc_client.lua    # ORM远程客户端
│   ├── container/             # 服务容器
│   │   ├── container_interface.lua # 服务对外接口
│   │   └── container_launcher.lua  # 启动函数（main.lua中调用）
│   ├── db/                    # 数据库相关
│   │   ├── orm/               # ORM实现（ormtable.lua核心）
│   │   ├── ormadapter/        # ORM适配器（MySQL/MongoDB）
│   │   ├── mysqlf.lua         # MySQL连接封装
│   │   ├── redisf.lua         # Redis连接封装
│   │   └── mongof.lua         # MongoDB连接封装
│   ├── rpc/                   # RPC通信
│   │   ├── watch_client.lua   # 远程Sub/Pub订阅客户端
│   │   ├── watch_server.lua   # 远程Sub/Pub发布服务端
│   │   └── watch_syn_client.lua # 同步订阅客户端
│   ├── netpack/               # 网络包处理
│   │   ├── json_netpack.lua   # JSON协议包
│   │   ├── pb_netpack.lua     # Protobuf协议包
│   │   └── sp_netpack.lua     # Sproto协议包
│   ├── utils/                 # 工具函数
│   │   ├── env_util.lua       # 环境变量工具
│   │   ├── time_util.lua      # 时间工具
│   │   ├── table_util.lua     # 表操作工具
│   │   ├── string_util.lua    # 字符串工具
│   │   ├── file_util.lua      # 文件工具
│   │   ├── skynet_util.lua    # skynet工具
│   │   ├── math_util.lua      # 数学工具
│   │   ├── guid_util.lua      # GUID工具
│   │   └── net/               # 网络工具（TCP/WebSocket）
│   ├── web/                   # HTTP Web框架（类Gin风格）
│   │   ├── engine_web.lua     # 引擎入口
│   │   ├── routergroup_web.lua # 路由组
│   │   ├── context_web.lua    # 请求上下文
│   │   ├── request_web.lua    # 请求对象
│   │   ├── response_web.lua   # 响应对象
│   │   └── middleware/        # 中间件
│   ├── watch/                 # 数据同步监听
│   ├── cache/                 # 缓存（TTI）
│   ├── pool/                  # 对象池
│   ├── enum/                  # 枚举常量
│   ├── etc/                   # 模块信息配置
│   └── time_extend/           # 时间扩展（wait/timer_point）
├── module/                    # 内置服务模块（可热更）
│   ├── frpc_client_m.lua      # 远程RPC客户端服务
│   ├── orm_table_m.lua        # ORM表服务
│   ├── share_config_m.lua     # 共享配置服务
│   ├── web_agent_m.lua        # HTTP Agent服务
│   ├── web_master_m.lua       # HTTP Master服务
│   ├── room_game_hall_m.lua   # 大厅服务
│   ├── room_game_alloc_m.lua  # 房间分配服务
│   ├── room_game_table_m.lua  # 桌子服务
│   ├── logrotate_m.lua        # 日志分割服务
│   └── debug_console_m.lua    # 调试控制台
├── examples/                  # 示例项目
│   ├── AB_question/           # 服务间通信示例
│   ├── digitalbomb/           # 数字炸弹游戏（TCP）
│   ├── digitalbomb_byid/      # 数字炸弹（按ID消息）
│   ├── digitalbomb_byrpc/     # 数字炸弹（RPC消息）
│   ├── webapp/                # HTTP Web服务示例
│   ├── room_game_jump/        # 跳房间游戏示例
│   ├── orm/                   # ORM使用示例
│   ├── frpc_client/           # 跨节点RPC客户端示例
│   ├── frpc_server/           # 跨节点RPC服务端示例
│   └── record/                # 服务录像示例
├── service/                   # skynet服务
├── script/                    # 构建脚本（Lua）
├── binshell/                  # Shell构建脚本
├── binbat/                    # Windows构建脚本
├── lualib-src/                # C扩展源码
├── luaclib/                   # 编译后的C扩展
├── 3rd/                       # 第三方依赖源码
├── commonlualib/              # 公共Lua库
├── skynet/                    # skynet子模块
├── Makefile                   # Linux/macOS编译
└── CMakeLists.txt             # Windows编译
```

---

## 核心概念

### 1. 可热更服务模块（Hot-Reloadable Module）

每个业务服务写成一个 `xxx_m.lua` 文件，统一放在 `module/` 文件夹（skynet普通服务放在 `service/`）。

**模块结构约定**（必须遵守）：
```lua
-- 示例：B_m.lua
local log = require "skynet-fly.log"
local container_client = require "skynet-fly.client.container_client"
local skynet = require "skynet"

-- 在文件顶层（loading阶段）注册要访问的其他模块（必须在 start 之前）
container_client:register("A_m")

local CMD = {}

-- ★ 必须实现 start，返回true表示启动成功，false表示启动失败
-- config 是 load_mods 中 default_arg 或 mod_args 对应的配置
-- 注意：start阶段不能访问其他可热更服务
function CMD.start(config)
    -- 初始化逻辑
    return true
end

-- 热更时，启动新服务之前给旧服务发预告（可选）
function CMD.herald_exit()
    log.error("预告退出")
end

-- ★ 必须实现 exit
-- 返回true后10分钟内会销毁旧服务 返回true表示可以退出，false表示不销毁服务
function CMD.exit()
    log.error("退出")
    return true
end

-- 确定被新服务替代（可选）
function CMD.fix_exit()
    log.error("确认要退出")
end

-- 新服务启动失败时，旧服务应继续运行（可选）
function CMD.cancel_exit()
    log.error("取消退出")
end

-- 用于检查能不能退出（可选，不实现默认返回True） 返回true表示可以退出，false表示不销毁服务
function CMD.check_exit()
    log.error("检查退出")
    return true
end

-- 自定义业务命令
function CMD.hello()
    return "HELLO, I am " .. skynet.address(skynet.self())
end

-- ★ 必须 return CMD（不是像普通skynet服务那样注册dispatch）
return CMD
```

**生命周期说明**：
| 函数 | 必须实现 | 说明 |
|------|---------|------|
| `CMD.start(config)` | ✅ | 初始化，返回true启动成功，启动阶段不能访问其他热更服务 |
| `CMD.exit()` | ✅ | 返回true表示可退出，false不销毁 |
| `CMD.herald_exit()` | 可选 | 热更时，新服务启动前给旧服务发预告 |
| `CMD.fix_exit()` | 可选 | 确定被新服务替代 |
| `CMD.cancel_exit()` | 可选 | 新服务启动失败，旧服务继续运行 |
| `CMD.check_exit()` | 可选 | 检查能否退出 |

### 2. main.lua 入口文件

```lua
local skynet = require "skynet"
local container_launcher = require "skynet-fly.container.container_launcher"

skynet.start(function()
    local delay_run = container_launcher.run()
    delay_run()  -- 启动 delay_run = true 的模块
    skynet.exit()
end)
```

### 3. load_mods.lua 配置文件

每个项目都有一个 `load_mods.lua`，定义启动哪些服务模块：

```lua
return {
    -- 模块名 = 配置
    share_config_m = {
        launch_seq = 1,          -- 启动顺序（数字越小越先启动）
        launch_num = 1,          -- 启动实例数量
        default_arg = {          -- 传递给所有实例的默认参数（和mod_args同时存在时，mod_args优先）
            server_cfg = {
                loglevel = "info",
                thread = 8,
                debug_port = 9001,
            }
        }
    },

    my_service_m = {
        launch_seq = 2,
        launch_num = 3,           -- 启动3个实例
        mod_args = {              -- 每个实例的独立参数（与instance_name配合分类）
            {instance_name = "s1", role = "master"},
            {instance_name = "s2", role = "slave"},
            {instance_name = "s3", role = "slave"},
        },
        delay_run = true,         -- 延迟运行（先让其他服务启动完毕）
        is_record_on = false,     -- 是否启动录像
        auto_reload = {           -- 自动定时热更（整点热更）
            type = "hour",        -- month/day/hour/min/sec/wday/yday
            hour = 3,             -- 具体时间值
        },
    },
}
```

**load_mods 参数说明**：
| 参数 | 说明 |
|------|------|
| `launch_seq` | 启动顺序，数字越小越先启动 |
| `launch_num` | 启动实例数量 |
| `mod_args` | 每个实例的独立配置列表，与launch_num数量对应 |
| `default_arg` | 所有实例的默认配置，mod_args对应配置优先级更高 |
| `instance_name` | 实例名称，用于服务二级分类，通过instance_name访问指定组 |
| `delay_run` | 延迟运行，有些服务需要其他服务先启动（如客户端模拟） |
| `is_record_on` | 是否启动服务录像 |
| `auto_reload` | 自动定时热更配置（timer_point类型） |
| `record_backup` | 录像保留文件整理，启动录像才生效 |

### 4. container_client 内部RPC调用

同一进程内服务间调用使用 `container_client`：

```lua
local container_client = require "skynet-fly.client.container_client"

-- ★ 在文件顶层（loading阶段）注册要访问的模块，必须在 start 之前调用
container_client:register("B_m")

-- 设置B为弱访问者（两个热更服务相互访问时，需一方设置另一方为弱访问者，避免旧服务无法退出）
container_client:set_week_visitor("B_m")

-- 总能切换到新服务（不受自身是否为旧服务的限制）
container_client:set_always_swtich("B_m")

-- 查询到B服务地址时的回调
container_client:add_queryed_cb("B_m", function()
    log.info("queryed B_m")
end)

-- B服务地址更新时的回调（热更后触发）
container_client:add_updated_cb("B_m", function()
    log.info("updated B_m")
end)
```

**调用方式**（在 `CMD.start` 之后可以使用，loading阶段不能用）：
```lua
-- ★ instance() 创建/获取常驻调用对象（推荐方式，自动缓存）
local b = container_client:instance("B_m")

-- 轮询负载均衡 call（有返回值）
local ret = b:balance_call("hello", arg1, arg2)

-- 轮询负载均衡 send（无需等待返回）
b:balance_send("notify", data)

-- mod hash映射（固定到某个实例，默认mod=skynet.self()）
local ret = b:set_mod_num(1):mod_call("hello")
b:set_mod_num(1):mod_send("notify", data)

-- 广播所有实例 call（返回 {服务id = {返回值列表}} 的map）
local ret_map = b:broadcast_call("refresh")

-- 广播所有实例 send
b:broadcast("notify", data)

-- by_name方式：按instance_name分组调用（mod_args中定义了instance_name时使用）
local b1 = container_client:instance("B_m", "test_one")  -- 获取instance_name="test_one"的组
local ret = b1:balance_call_by_name("hello")              -- 轮询组内服务
local ret = b1:set_mod_num(1):mod_call_by_name("hello")   -- hash映射组内服务
local ret_map = b1:broadcast_call_by_name("hello")        -- 广播组内服务
-- 对应send版本: balance_send_by_name / mod_send_by_name / broadcast_by_name
```

**container_client 完整API汇总**：
| 方法 | 说明 |
|------|------|
| `register(mod_name, ...)` | 注册访问模块（loading阶段调用） |
| `set_week_visitor(mod_name, ...)` | 设置弱访问者（避免互相访问导致旧服务无法退出） |
| `set_always_swtich(mod_name, ...)` | 总能切换到新服务 |
| `add_queryed_cb(mod_name, func)` | 查询到服务地址时的回调 |
| `add_updated_cb(mod_name, func)` | 服务地址更新时的回调 |
| `instance(mod_name, instance_name?)` | 获取常驻调用对象（推荐） |
| `new(mod_name, instance_name?, can_switch_func?)` | 创建临时调用对象 |
| `is_ready(mod_name)` | 服务是否已就绪 |
| **调用对象方法** | |
| `balance_call(cmd, ...)` | 轮询call |
| `balance_send(cmd, ...)` | 轮询send |
| `mod_call(cmd, ...)` | hash映射call |
| `mod_send(cmd, ...)` | hash映射send |
| `broadcast_call(cmd, ...)` | 广播call |
| `broadcast(cmd, ...)` | 广播send |
| `balance_call_by_name(cmd, ...)` | 按instance_name组轮询call |
| `balance_send_by_name(cmd, ...)` | 按instance_name组轮询send |
| `mod_call_by_name(cmd, ...)` | 按instance_name组hash映射call |
| `mod_send_by_name(cmd, ...)` | 按instance_name组hash映射send |
| `broadcast_call_by_name(cmd, ...)` | 按instance_name组广播call |
| `broadcast_by_name(cmd, ...)` | 按instance_name组广播send |
| `set_mod_num(num)` | 设置mod映射数字（链式调用）|
| `set_instance_name(name)` | 设置instance_name（链式调用）|

### 5. 日志系统

```lua
local log = require "skynet-fly.log"

log.info("普通信息", var1, var2)
log.debug("调试信息", ...)
log.warn("警告信息", ...)
log.error("错误信息", ...)
log.fatal("致命错误", ...)

-- 格式化版本（类似string.format）
log.info_fmt("格式化 %s %d", str, num)
log.debug_fmt(...)
log.warn_fmt(...)
log.error_fmt(...)
log.fatal_fmt(...)

-- 添加日志钩子
log.add_hook(log.ERROR, function(log_str)
    -- 自定义处理错误日志
end)
```

日志级别通过 `load_mods` 的 `share_config_m.default_arg.server_cfg.loglevel` 配置，可选 `debug/info/warn/error/fatal`。

### 6. 定时器

```lua
local timer = require "skynet-fly.timer"

-- 创建定时器（100 = 1秒）
local t = timer:new(
    timer.second * 5,  -- 5秒后触发
    1,                 -- 触发次数（0/timer.loop 表示循环）
    function(arg1, arg2)
        log.info("timer fired", arg1, arg2)
    end,
    "hello", 42        -- 传递给回调的参数
)

-- 循环定时器
local t2 = timer:new(timer.minute, timer.loop, function()
    log.info("every minute")
end)

-- 取消定时器
t:cancel()

-- 先执行回调，再注册下一次（默认是先注册再执行）
t:after_next()

-- 延长过期时间（返回新定时器对象）
local nt = t:extend(timer.second * 2)

-- 获取剩余触发时间（-1表示已触发或已取消）
local remain = t:remain_expire()

-- 时间常量
-- timer.second  = 100     (1秒)
-- timer.minute  = 6000    (1分钟)
-- timer.hour    = 360000  (1小时)
-- timer.day     = 8640000 (1天)
-- timer.loop    = 0       (循环标志)
```

### 7. ORM 数据库映射

ORM使用**链式调用**定义表结构，通常写在独立的 `orm_plug/entry_xxx.lua` 文件中：

```lua
-- 文件: orm_plug/entry_player.lua
local ormtable = require "skynet-fly.db.orm.ormtable"
local ormadapter_mysql = require "skynet-fly.db.ormadapter.ormadapter_mysql"

local g_orm_obj = nil
local M = {}
local handle = {}

function M.init()
    -- 创建MySQL适配器（参数为mysql配置名，对应share_config_m中的mysql.xxx）
    local adapter = ormadapter_mysql:new("admin")

    -- 链式API定义表结构
    g_orm_obj = ormtable:new("t_player")  -- 参数为数据库表名
        :int64("player_id")               -- 字段类型方法(字段名)
        :string64("name")
        :int8("sex")
        :int8("status")
        :table("extra_data")              -- table类型自动JSON序列化
        :set_index("sex_index", "sex")    -- 设置普通索引(索引名, 字段名...)
        :set_keys("player_id")            -- 设置主键(字段名...)
        :builder(adapter)                 -- 绑定适配器，完成构建

    return g_orm_obj
end

-- 创建记录
function handle.create(entry_data)
    local entry = g_orm_obj:create_one_entry(entry_data)
    if not entry then return end
    return entry:get_entry_data()
end

-- 按主键查询（返回entry列表）
function handle.get(player_id)
    local entry_list = g_orm_obj:get_entry(player_id)
    if #entry_list <= 0 then return end
    return entry_list[1]:get_entry_data()
end

-- 查单条（先检查缓存，无则从DB查）
function handle.get_one(player_id)
    local entry = g_orm_obj:get_one_entry(player_id)
    if not entry then return end
    return entry:get_entry_data()
end

-- 修改并保存
function handle.update(player_id, field, value)
    local entry_list = g_orm_obj:get_entry(player_id)
    if #entry_list <= 0 then return end
    local entry = entry_list[1]
    local old_val = entry:get(field)          -- 获取字段值
    entry:set(field, value)                   -- 修改字段
    return g_orm_obj:save_one_entry(entry)    -- 保存（返回true/false）
end

M.handle = handle
return M
```

**字段类型方法**（链式调用，方法名即字段类型）：
`int8` / `int16` / `int32` / `int64` / `uint8` / `uint16` / `uint32` / `string32` / `string64` / `string128` / `string256` / `string512` / `string1024` / `string2048` / `string4096` / `string8192` / `text` / `blob` / `table`

在 `load_mods.lua` 中配置：
```lua
-- 先配置数据库连接（在share_config_m的default_arg中）
share_config_m = {
    launch_seq = 1,
    launch_num = 1,
    default_arg = {
        mysql = {
            admin = {  -- 对应 ormadapter_mysql:new("admin") 的参数名
                host = '127.0.0.1',
                port = '3306',
                user = 'root',
                password = '123456',
                database = 'admin',
            }
        }
    }
},
-- 配置orm_table_m
orm_table_m = {
    launch_seq = 1000,
    launch_num = 1,
    mod_args = {
        {
            instance_name = "player",           -- 实例名（访问时用）
            orm_plug = "orm_plug.entry_player", -- orm_plug文件路径
        },
    }
},
```

ORM支持MySQL和MongoDB，通过适配器切换：
- `db/ormadapter/ormadapter_mysql.lua` - MySQL适配器，用 `ormadapter_mysql:new("配置名")`
- `db/ormadapter/ormadapter_mongo.lua` - MongoDB适配器，用 `ormadapter_mongo:new("配置名")`

### 8. HTTP Web框架（类Gin风格）

```lua
-- 在 dispatch 文件中（如 apps/webapp_dispatch.lua）
local engine_web = require "skynet-fly.web.engine_web"
local HTTP_STATUS = require "skynet-fly.web.HTTP_STATUS"

local M = {}
-- 纯净版（不带中间件）
local app = engine_web:new()
-- 或默认版（带logger中间件）
-- local app = engine_web:default()

-- ★ dispatch 是必须导出的函数
M.dispatch = engine_web.dispatch(app)

-- ★ init 在服务启动时调用
function M.init()
    -- GET 路由
    app:get("/", function(c)
        c.res:set_rsp("hello world", HTTP_STATUS.OK)
    end)

    -- POST 路由，返回JSON
    app:post("/api/login", function(c)
        local body = c.req:get_json_body()
        c.res:set_json_rsp({code = 0, msg = "ok"})
    end)

    -- 路由参数
    app:get("/user/:id", function(c)
        local id = c.req:get_param("id")
        c.res:set_json_rsp({id = id})
    end)

    -- 路由组
    local v1 = app:group("/v1")
    v1:get("/ping", function(c)
        c.res:set_json_rsp({message = "pong"})
    end)

    -- 使用中间件（全局）
    app:use(require("skynet-fly.web.middleware.cors_mid")())
    app:use(require("skynet-fly.web.middleware.logger_mid")())

    -- 静态文件
    app:static_file("/favicon.ico", "./static/favicon.ico")
    app:static_dir("/static", "./static/")

    -- 404处理
    app:set_no_route(function(c)
        c.res:set_error_rsp(HTTP_STATUS.Not_Found)
    end)

    app:run()  -- ★ 必须调用run()完成路由构建
end

-- ★ exit 在服务退出时调用
function M.exit()
end

return M
```

在 `load_mods.lua` 中配置：
```lua
web_agent_m = {
    launch_seq = 2,
    launch_num = 8,           -- agent数量等于并发处理能力
    default_arg = {
        protocol = 'http',
        dispatch = 'apps.webapp_dispatch',  -- dispatch模块的require路径
        keep_alive_time = 300,              -- 最长保活时间（秒）
        second_req_limit = 2000,            -- 每秒请求数限制
    }
},
web_master_m = {
    launch_seq = 3,
    launch_num = 1,
    default_arg = {
        protocol = 'http',
        port = 8688,
        max_client = 30000,
        second_conn_limit = 30000,  -- 相同ip每秒建立连接数限制
        keep_live_limit = 30000,    -- 相同ip保持活跃连接数限制
    }
}
```

### 9. 共享配置（share_config）

```lua
-- 从 share_config_m 中查询配置
local share_config = require "skynet-fly.etc.share_config"
local cfg = share_config.get("my_config_key")
```

`share_config_m.default_arg` 中的所有键都可以通过 `share_config.get(key)` 获取。

### 10. 跨节点RPC（frpc）

```lua
local frpc_client = require "skynet-fly.client.frpc_client"

-- 调用远程节点的服务
local ret = frpc_client:call(svr_name, svr_id, module_name, cmd, ...)

-- 订阅远程节点消息（Sub/Pub）
local watch_client = require "skynet-fly.rpc.watch_client"
watch_client:watch(svr_name, channel_name, function(data)
    -- 处理订阅消息
end)
```

### 11. 环境变量工具

```lua
local env_util = require "skynet-fly.utils.env_util"

local svr_id   = env_util.get_svr_id()    -- 服务器ID（cluster节点id）
local svr_name = env_util.get_svr_name()  -- 服务器名称
local svr_type = env_util.get_svr_type()  -- 服务器类型

-- 预加载/后加载lua文件（在服务start之前/之后执行）
env_util.add_pre_load("/path/to/file.lua")
env_util.add_after_load("/path/to/file.lua")
```

---

## 网络协议支持

框架支持三种协议格式，均有 TCP 和 WebSocket 两种传输方式：

| 协议 | TCP工具 | WebSocket工具 |
|------|--------|--------------|
| JSON | `utils/net/jsonet_*` | `utils/net/ws_jsonet_*` |
| Protobuf | `utils/net/pbnet_*` | `utils/net/ws_pbnet_*` |
| Sproto | `utils/net/spnet_*` | `utils/net/ws_spnet_*` |

消息发送方式三种（以pbnet为例）：
- `pbnet_byid.lua` - 按消息ID区分（digitalbomb_byid示例）
- `pbnet_byrpc.lua` - 按RPC方式（digitalbomb_byrpc示例）
- `pbnet_util.lua` - 通用工具封装

---

## 工具函数参考

### time_util
```lua
local time_util = require "skynet-fly.utils.time_util"
time_util.time()              -- 当前时间戳（秒）
time_util.skynet_int_time()   -- skynet时间（100=1秒）
time_util.mstime()            -- 毫秒时间戳
time_util.date(fmt, t)        -- 格式化日期
```

### table_util
```lua
local table_util = require "skynet-fly.utils.table_util"
table_util.dump(t)            -- 表转字符串（用于打印）
table_util.clone(t)           -- 深拷贝
table_util.merge(dst, src)    -- 合并表
table_util.sort_ipairs(t, cmp) -- 排序遍历（返回迭代器）
```

### string_util
```lua
local string_util = require "skynet-fly.utils.string_util"
string_util.split(str, sep)   -- 分割字符串
```

### file_util
```lua
local file_util = require "skynet-fly.utils.file_util"
file_util.mkdir(path)                        -- 创建目录
file_util.is_window()                        -- 是否Windows
file_util.path_join(a, b)                    -- 路径拼接
file_util.get_cur_dir_name()                 -- 获取当前目录名
file_util.convert_path(path)                 -- 路径格式转换
```

### math_util
```lua
local math_util = require "skynet-fly.utils.math_util"
math_util.uint32max               -- uint32最大值
math_util.is_vaild_int8(n)        -- 检查是否有效int8
math_util.is_vaild_uint32(n)      -- 检查是否有效uint32
```

---

## 热更新机制

### 工作流程
1. 修改 `xxx_m.lua` 业务文件
2. 执行 `sh make/script/check_reload.sh load_mods.lua`
3. 框架检测文件变更时间，启动新版本服务（`CMD.start` 被调用）
4. 新服务启动成功后通知旧服务（`CMD.herald_exit` → `CMD.fix_exit`）
5. 新请求路由到新服务，旧服务等待现有请求处理完毕
6. 旧服务无访问者后调用 `CMD.exit`，返回true后10分钟销毁

### 热更新约束
- `CMD.start` 返回 `false` 表示启动失败，旧服务继续（`CMD.cancel_exit` 被调用）
- 热更新只更新函数逻辑，不能修改服务状态数据结构
- 全局变量变更会有警告（安全限制）
- 两个相互访问的热更服务，需一方设置另一方为弱访问者 `set_week_visitor`

---

## 项目构建

### Linux/macOS
```bash
# 克隆并初始化子模块
git clone https://github.com/huahua132/skynet_fly
cd skynet_fly

# 安装依赖
sh install_centos.sh   # CentOS
sh install_ubuntu.sh   # Ubuntu

# 编译
make linux             # Linux
make macosx            # macOS
```

### Windows
使用 Visual Studio 2022 + CMake + Clang 模块编译（`CMakeLists.txt`）。

### 运行示例
```bash
cd examples/webapp
sh ../../binshell/make_server.sh ../../    # 生成运维脚本到 make/script/
sh make/script/run.sh load_mods.lua 0     # 0=前台运行，无参数=后台运行
sh make/script/stop.sh load_mods.lua      # 停止服务
sh make/script/check_reload.sh load_mods.lua  # 检测并热更
sh make/script/fasttime.sh load_mods.lua  # 时间快进
```

---

## 示例项目说明

| 目录 | 说明 |
|------|------|
| `examples/AB_question/` | 基础服务间通信，演示 balance_call/mod_call/broadcast_call 及 by_name变体 |
| `examples/digitalbomb/` | 数字炸弹游戏，TCP长连接，完整登录/大厅/匹配/游戏流程 |
| `examples/digitalbomb_byid/` | 数字炸弹（消息ID方式区分消息） |
| `examples/digitalbomb_byrpc/` | 数字炸弹（RPC方式区分消息） |
| `examples/webapp/` | HTTP服务，多种路由、中间件、静态文件、JWT鉴权示例 |
| `examples/room_game_jump/` | 跳桌子房间游戏，Protobuf协议 |
| `examples/orm/` | ORM数据库操作示例（MySQL） |
| `examples/frpc_client/` | 跨节点RPC客户端示例 |
| `examples/frpc_server/` | 跨节点RPC服务端示例 |
| `examples/record/` | 服务录像功能示例 |
| `examples/logrotate/` | 日志分割示例 |
| `examples/log_hook/` | 日志钩子示例 |
| `examples/pre_after_load/` | 预加载/后加载示例 |
| `examples/code_cache_test/` | 代码缓存测试示例 |

---

## 第三方依赖

| 库 | 用途 | require路径 |
|----|------|------------|
| lua-cjson | JSON编解码 | `cjson` |
| lua-protobuf | Protobuf | `pb` |
| lua-openssl | 加密/SSL | `openssl` |
| luafilesystem | 文件系统 | `lfs` |
| lzlib | 压缩 | `zlib` |
| lua-zset | 有序集合（跳表） | `skiplist` |
| lua-snapshot | 内存快照 | `snapshot` |
| luajwtjitsi | JWT鉴权 | `skynet-fly.3rd.luajwtjitsi` |
| basexx | Base编码 | `skynet-fly.3rd.basexx` |
| radix-router | HTTP路由 | `skynet-fly.3rd.radix-router` |
| LuaPanda | 断点调试 | `skynet-fly.LuaPanda` |
| lua-chat_filter | 聊天过滤 | `chat_filter` |
| frpcpack | 远程RPC打包 | `frpcpack.core` |

---

## 编程规范

1. **模块文件命名**：服务模块必须以 `_m.lua` 结尾（如 `my_service_m.lua`），普通skynet服务放 `service/`，可热更服务放 `module/` 或示例内的 `module/` 子目录
2. **require路径**：核心库统一用 `skynet-fly.` 前缀（如 `require "skynet-fly.log"`）
3. **模块返回值**：可热更模块必须 `return CMD`，不是调用 `container_interface(CMD)`
4. **register调用时机**：`container_client:register()` 必须在文件顶层（loading阶段），不能在 `CMD.start` 里
5. **start阶段限制**：`CMD.start` 中不能访问其他可热更服务（因为服务还未就绪）
6. **局部变量优化**：频繁使用的全局函数应先赋给局部变量（如 `local pairs = pairs`）
7. **日志规范**：使用 `log.info/warn/error` 替代 `print`
8. **定时器单位**：skynet时间单位是 `1/100秒`，即 `100 = 1秒`
9. **错误处理**：可以使用 `x_pcall`（全局函数，比pcall多打印堆栈）代替 `pcall`
10. **dispatch文件结构**：HTTP dispatch模块必须导出 `M.dispatch`、`M.init()`、`M.exit()` 三个接口，并在init中调用 `app:run()`
11. **弱访问者设置**：两个热更模块相互引用时，必须有一方调用 `container_client:set_week_visitor()` 避免死循环

---

## 典型代码模式

### 完整模块示例（A调用B）
```lua
-- A_m.lua
local container_client = require "skynet-fly.client.container_client"
local timer = require "skynet-fly.timer"
local log = require "skynet-fly.log"

-- ★ loading 阶段：注册、配置访问关系
container_client:register("B_m")
container_client:set_week_visitor("B_m")     -- 避免互相访问死锁
container_client:set_always_swtich("B_m")    -- 旧A也能访问新B

container_client:add_updated_cb("B_m", function()
    -- B热更后的处理（如清空缓存）
end)

local CMD = {}

function CMD.start(config)
    -- ★ 此处不能访问 B_m
    log.info("A start, config:", config)
    -- 启动一个3秒循环定时器
    timer:new(timer.second * 3, timer.loop, function()
        local ret = container_client:instance("B_m"):balance_call("hello")
        log.info("B reply:", ret)
    end)
    return true  -- ★ 必须返回true
end

function CMD.exit()
    return true  -- ★ 必须返回true
end

-- 自定义命令（被其他服务调用）
function CMD.ping()
    return "pong from A"
end

return CMD  -- ★ return CMD 而不是 container_interface(CMD)
```

### ORM plug 访问模式
```lua
-- 在 orm_table_m 对应的 orm_plug 文件中定义
-- 通过 orm_frpc_client 或直接 container_client 访问 orm_table_m

local container_client = require "skynet-fly.client.container_client"
container_client:register("orm_table_m")

-- 调用 orm_table_m 中的 handle
local function query_player(player_id)
    local data = container_client:instance("orm_table_m", "player")
        :instance_call("handle", "get", player_id)  -- instance_name="player"
    return data
end
```

### share_config 获取配置
```lua
-- load_mods.lua 中定义：
-- share_config_m.default_arg.my_cfg = { key = "value" }

local share_config = require "skynet-fly.etc.share_config"

function CMD.start(config)
    local my_cfg = share_config.get("my_cfg")  -- 获取 share_config_m 的配置
    log.info("my_cfg:", my_cfg)
    return true
end
```

