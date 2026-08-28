# log_shutdown 示例

演示 log_service 的 fatal/traceback 日志自动强制关服功能。

## 功能

log_service 检测到 **fatal** 或 **traceback**（错误堆栈）日志时，若开关开启，会打印 `[强制关服]` 日志并触发 container_mgr 的 `shutdown` 强制关服。

- 开关默认关闭，通过 `log.set_shutdown_when_fatal(true)` 开启（log_service 提供 `CMD.set_shutdown_when_fatal`）
- 触发前打印 `[强制关服]` 日志，用 `skynet.send('.container_mgr','lua','shutdown')` 异步触发
- `g_shutdown_triggered` 防止重复触发

## 测试场景

在 [load_mods.lua](load_mods.lua) 中修改 `SHUTDOWN_MODE` 切换场景：

| SHUTDOWN_MODE | 行为 | 预期 |
|---------------|------|------|
| `on` | 开启开关，打 fatal | 打印 `[强制关服]`，触发 container_mgr shutdown，进程退出 |
| `on_off` | 开启后 2 秒关闭，3 秒打 fatal | 不触发关服，进程继续运行 |
| `off` | 不开启（默认），打 fatal | 不触发关服，进程继续运行 |

## 运行

在 `examples/log_shutdown` 目录下（WSL）：

```sh
# 场景1: 开启自动关服 (改 load_mods.lua 的 SHUTDOWN_MODE = 'on')
sh make/script/run.sh load_mods.lua 0

# 查看日志
tail -f logs/server.log
# 3秒后应看到:
#   ... [强制关服] 检测到 ... 触发 container_mgr 强制关服 ...
#   ... shutdown over ...  (container_mgr shutdown 完成)

# 停止
sh make/script/stop.sh load_mods.lua
```

## 文件说明

- [main.lua](main.lua) — 入口，启动 container_launcher
- [module/test_m.lua](module/test_m.lua) — 测试模块，按 SHUTDOWN_MODE 控制开关并打 fatal 日志
- [load_mods.lua](load_mods.lua) — 模块配置，`SHUTDOWN_MODE` 切换场景，`mod_args` 传给模块
