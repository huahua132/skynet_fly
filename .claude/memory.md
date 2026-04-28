# skynet_fly 项目记忆（Memory）

> 项目背景、目录结构、配置规则、约束事实等静态知识
> **关键词**: skynet_fly, Lua 5.4, 游戏服务器, Actor模型, 热更新
> **仓库**: https://github.com/huahua132/skynet_fly
> **文档**: https://huahua132.github.io/2023/02/25/skynet_fly_word/word_1/A_home/
> **API文档**: https://huahua132.github.io/2023/12/17/skynet_fly_api/module/

> **lualib API 索引**: 见 [`.claude/lualib_api.md`](lualib_api.md) —— 快速定位各模块文件路径和核心API

---

## 项目概述

- **语言**: Lua 5.4
- **底层框架**: skynet（Actor模型并发框架）
- **平台**: Linux / macOS / Windows (VS2022 + Clang)
- **定位**: 高性能游戏服务器框架，支持热更新、分布式、ORM、HTTP服务

---

## 目录结构

```
skynet_fly/
├── lualib/skynet-fly/         # 核心库
│   ├── loader.lua             # 服务加载器（热更新支持）
│   ├── log.lua                # 日志
│   ├── timer.lua              # 定时器
│   ├── client/
│   │   ├── container_client.lua   # 同进程服务调用（核心）
│   │   ├── frpc_client.lua        # 跨节点RPC客户端
│   │   └── orm_frpc_client.lua    # ORM远程客户端
│   ├── container/
│   │   ├── container_interface.lua # 服务对外接口
│   │   └── container_launcher.lua  # 启动入口
│   ├── db/
│   │   ├── orm/ormtable.lua        # ORM核心
│   │   ├── ormadapter/             # MySQL/MongoDB适配器
│   │   ├── mysqlf.lua / redisf.lua / mongof.lua
│   ├── rpc/                   # Sub/Pub订阅
│   ├── utils/                 # 工具函数
│   ├── web/                   # HTTP Web框架（类Gin）
│   ├── watch/                 # 数据同步监听
│   ├── cache/ / pool/ / enum/ / etc/
├── module/                    # 内置热更服务模块（_m.lua）
├── examples/                  # 示例项目
├── service/                   # 普通 skynet 服务
├── script/                    # 构建脚本
├── lualib-src/                # C扩展源码
├── luaclib/                   # 编译后C扩展
├── 3rd/                       # 第三方依赖
└── commonlualib/              # 公共Lua库
```

---

## 核心概念与约束

### 热更模块（_m.lua）

| 规则 | 说明 |
|------|------|
| 文件命名 | 热更服务必须以 `_m.lua` 结尾，放 `module/` 目录 |
| 普通服务 | 放 `service/` 目录 |
| 返回值 | 必须 `return CMD`（不是 `container_interface(CMD)`） |
| register时机 | `container_client:register()` 必须在**文件顶层loading阶段** |
| start阶段 | `CMD.start` 中**不能**访问其他可热更服务 |
| start返回值 | `true` = 启动成功，`false` = 启动失败（旧服务继续） |
| exit返回值 | `true` = 可退出并10分钟后销毁，`false` = 不销毁 |
| 互访热更服务 | 必须一方调用 `container_client:set_week_visitor()` |

### 生命周期

| 函数 | 必须 | 说明 |
|------|------|------|
| `CMD.start(config)` | ✅ | 初始化，config来自load_mods的default_arg/mod_args |
| `CMD.exit()` | ✅ | 返回true=可退出 |
| `CMD.herald_exit()` | 可选 | 热更时新服务启动前通知旧服务 |
| `CMD.fix_exit()` | 可选 | 确定被新服务替代时调用 |
| `CMD.cancel_exit()` | 可选 | 新服务启动失败，旧服务继续运行时调用 |
| `CMD.check_exit()` | 可选 | 检查能否退出（不实现默认返回true） |

### load_mods 参数

| 参数 | 说明 |
|------|------|
| `launch_seq` | 启动顺序，数字越小越先 |
| `launch_num` | 启动实例数 |
| `mod_args` | 每个实例的独立配置列表（数量与launch_num对应） |
| `default_arg` | 所有实例的默认配置（mod_args优先） |
| `instance_name` | 实例分组名，供 `instance(mod, name)` 按组访问 |
| `delay_run` | 延迟运行（让其他服务先启动完毕） |
| `is_record_on` | 是否启动服务录像 |
| `auto_reload` | 自动定时热更（timer_point类型） |
| `record_backup` | 录像保留文件整理 |

### HTTP dispatch文件约束

| 要求 | 说明 |
|------|------|
| 必须导出 | `M.dispatch`、`M.init()`、`M.exit()` 三个接口 |
| init中必须调用 | `app:run()` 在 `M.init()` 最后执行 |

### require路径规范

- 核心库统一使用 `skynet-fly.` 前缀（如 `require "skynet-fly.log"`）
- 日志使用 `log.info/warn/error`，不用 `print`
- 错误处理可用全局 `x_pcall`（比pcall多打印堆栈）

### server_cfg 配置项说明

`share_config_m.default_arg.server_cfg` 中的所有字段会直接覆盖 skynet 配置文件的默认值。

| 配置项 | 默认值 | 说明 |
|--------|--------|------|
| `loglevel` | `"info"` | 日志级别：debug / info / warn / error / fatal |
| `thread` | `8` | 工作线程数（重放录像时自动设为1） |
| `svr_id` | `1` | 服务器ID（cluster节点id，全局唯一） |
| `svr_name` | 目录名 | 服务器名称（默认取运行目录名） |
| `svr_type` | `1` | 服务类型（0-255，svr_name的唯一编码） |
| `debug_port` | `8888` | 调试控制台端口（debug_console_m使用） |
| `machine_id` | `1` | 机器ID（雪花ID生成器使用，全局唯一） |
| `trace` | `0` | 链路追踪开关（1=开启） |
| `recordlimit` | `100MB` | 录像文件大小限制（字节），超过停止录像 |
| `harbor` | `0` | skynet集群harbor值（单机为0） |
| `profile` | `true` | 性能分析开关 |

**最常用配置示例**：

```lua
share_config_m = {
    launch_seq = 1, launch_num = 1,
    default_arg = {
        server_cfg = {
            loglevel    = "info",    -- 日志级别
            thread      = 8,         -- 工作线程数
            svr_id      = 1,         -- 节点ID（分布式时每节点唯一）
            svr_name    = "game",    -- 节点名称（frpc中的svr_name）
            svr_type    = 1,         -- 节点类型
            debug_port  = 9001,      -- 调试端口
            machine_id  = 1,         -- 雪花ID机器ID
            recordlimit = 1024 * 1024 * 100,  -- 录像100MB限制
        }
    }
},
```

### 定时器单位

- skynet 时间单位：`100 = 1秒`
- `timer.second = 100`，`timer.minute = 6000`，`timer.hour = 360000`，`timer.day = 8640000`，`timer.loop = 0`（循环）

---

## 热更新流程

```
修改 xxx_m.lua
→ sh make/script/check_reload.sh load_mods.lua
→ 框架检测文件变更，启动新版本服务（CMD.start）
→ 新服务启动成功 → herald_exit → fix_exit
→ 新请求路由到新服务，旧服务处理现有请求
→ 旧服务无访问者 → CMD.exit → true → 10分钟后销毁
→ 若CMD.start返回false → cancel_exit → 旧服务继续
```

---

## 内置模块说明

| 模块 | 说明 |
|------|------|
| `share_config_m` | 共享配置服务，launch_seq最小（最先启动） |
| `orm_table_m` | ORM表服务，通过instance_name区分不同表 |
| `web_agent_m` | HTTP Agent（并发处理器），launch_num=并发数 |
| `web_master_m` | HTTP Master（监听端口），launch_num=1 |
| `frpc_client_m` | 跨节点RPC客户端服务 |
| `logrotate_m` | 日志分割服务 |
| `debug_console_m` | 调试控制台 |
| `room_game_hall_m` | 游戏大厅服务 |
| `room_game_alloc_m` | 房间分配服务 |
| `room_game_table_m` | 桌子服务 |

---

## 示例项目速查

| 目录 | 说明 |
|------|------|
| `examples/AB_question/` | 服务间通信（balance/mod/broadcast及by_name变体） |
| `examples/digitalbomb/` | TCP数字炸弹游戏（完整登录/大厅/匹配/游戏流程） |
| `examples/digitalbomb_byid/` | 数字炸弹（消息ID方式） |
| `examples/digitalbomb_byrpc/` | 数字炸弹（RPC方式） |
| `examples/webapp/` | HTTP服务（路由/中间件/静态文件/JWT） |
| `examples/room_game_jump/` | 跳桌子房间游戏（Protobuf） |
| `examples/orm/` | ORM操作（MySQL） |
| `examples/frpc_client/` | 跨节点RPC客户端 |
| `examples/frpc_server/` | 跨节点RPC服务端 |
| `examples/record/` | 服务录像 |
| `examples/logrotate/` | 日志分割 |
| `examples/log_hook/` | 日志钩子 |
| `examples/pre_after_load/` | 预加载/后加载 |

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

## 网络协议矩阵

| 协议 | TCP | WebSocket |
|------|-----|-----------|
| JSON | `utils/net/jsonet_*` | `utils/net/ws_jsonet_*` |
| Protobuf | `utils/net/pbnet_*` | `utils/net/ws_pbnet_*` |
| Sproto | `utils/net/spnet_*` | `utils/net/ws_spnet_*` |

消息区分方式（以pbnet为例）：
- `_byid` - 按消息ID区分
- `_byrpc` - 按RPC方式
- `_util` - 通用工具封装

---

## 构建命令速查

```bash
# Linux/macOS 编译
sh install_centos.sh && make linux
sh install_ubuntu.sh && make linux

# 运行（在 examples/xxx 目录）
sh ../../binshell/make_server.sh ../../         # 生成运维脚本
sh make/script/run.sh load_mods.lua 0           # 前台运行
sh make/script/stop.sh load_mods.lua            # 停止
sh make/script/check_reload.sh load_mods.lua    # 热更检测
sh make/script/fasttime.sh load_mods.lua        # 时间快进
```
