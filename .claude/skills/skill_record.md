# 技能：服务录像（Record）

> **适用场景**: 开启服务录像，用于复现 Bug、调试复杂时序问题，支持录像播放（重放）
> **关键词**: record, is_record_on, recordfile, record_backup, 录像, 重放, 复现Bug
> **参考示例**: `examples/record/`

---

## 录像原理

skynet_fly 录像功能会把服务运行时的所有**非确定性操作**（随机数、时间、网络收包等）记录到文件。重放时，这些操作按原始顺序回放，可以完全复现当时的运行状态，非常适合复现难以稳定重现的 Bug。

**录像文件存放位置**：`records/` 目录（在项目运行目录下自动生成）

---

## 开启录像

在 `load_mods.lua` 中，对需要录像的模块设置 `is_record_on = 1`：

```lua
B_m = {
    launch_seq = 3,
    launch_num = 1,
    is_record_on = 1,   -- ★ 开启录像（1=开启，0/不设置=关闭）

    -- 可选：配置录像文件自动整理（需要同时启动 logrotate_m）
    record_backup = {
        max_age     = 3,    -- 最大保留天数
        max_backups = 8,    -- 最大保留文件数
        point_type  = 1,    -- 整理周期类型（1=每分钟）
        sec         = 20,   -- 在第20秒整理
    },
},

-- 如果配置了 record_backup，必须同时启动 logrotate_m
logrotate_m = {
    launch_seq = 4,
    launch_num = 1,
}
```

另外在 `share_config_m` 中可配置录像大小限制：

```lua
share_config_m = {
    launch_seq = 1, launch_num = 1,
    default_arg = {
        server_cfg = {
            recordlimit = 1024 * 1024,  -- 录像文件大小限制（字节），超过则停止录像
        }
    }
}
```

---

## 播放录像（重放）

录像文件生成后，可以通过 `run.sh` 的第三个参数指定录像文件路径来重放：

```bash
# Linux/macOS
sh make/script/run.sh load_mods.lua 0 records/B_m-xxx/xxx.record

# Windows
make\script\run.bat load_mods.lua 0 records\B_m-xxx\xxx.record
```

| 参数位置 | 说明 |
|---------|------|
| 第1个参数 | load_mods.lua 配置文件名 |
| 第2个参数 | 是否守护进程（1=后台，0=前台） |
| 第3个参数 | **录像文件路径**（可选，填了就是重放模式） |

重放时，框架会自动将工作线程数调整为1，确保单线程顺序执行，精确重现原始时序。

---

## 录像文件结构

```
records/
└── B_m-1-20240427-120000/     # 模块名-版本-启动时间
    ├── patch_1/               # 热更补丁文件（记录热更时的代码快照）
    │   └── ...
    └── xxx.record             # 录像文件（二进制）
```

---

## hotfix_require（录像支持热更文件）

在录像模式下，如果模块的某些文件在运行中被热更，录像需要记录热更前后的代码状态。框架提供了 `hotfix_require` 来支持这种场景：

```lua
-- 使用 hotfix_require 而不是普通 require，支持录像中追踪热更
local hotfix_func  = hotfix_require "testhotfix.hotfix_func"
local hotfix_table = hotfix_require "testhotfix.hotfix_table"
```

- `hotfix_require` 加载的模块在热更时，录像会记录新代码的快照
- 普通 `require` 加载的模块热更后不会被录像追踪

---

## 注意事项

| 注意点 | 说明 |
|--------|------|
| `is_record_on = 1` | 整数1，不是true |
| 录像大小限制 | 超过 `recordlimit` 后不再继续录像（但服务继续运行） |
| 重放时线程数自动设为1 | 框架自动处理，不需要手动配置 |
| `record_backup` 需要 `logrotate_m` | 配置了 record_backup 必须同时启动 logrotate_m 服务 |
| 随机数会被记录 | 重放时 `math.random` 返回与录像时相同的值 |
| 时间会被记录 | 重放时 `skynet.time()`、`os.time()` 等返回录像时的值 |
| 每个实例独立录像 | 多实例时每个实例分别生成独立录像文件 |
| hotfix_require | 需要追踪热更的文件用 hotfix_require 而非 require |

---

## 完整 load_mods 示例

```lua
return {
    share_config_m = {
        launch_seq = 1, launch_num = 1,
        default_arg = {
            server_cfg = {
                loglevel    = "info",
                recordlimit = 1024 * 1024 * 100,  -- 100MB录像大小限制
            }
        }
    },

    my_service_m = {
        launch_seq = 2,
        launch_num = 1,
        is_record_on = 1,    -- 开启录像
        record_backup = {
            max_age     = 7,    -- 保留最近7天
            max_backups = 20,   -- 最多保留20个文件
            point_type  = 1,    -- 每分钟整理
            sec         = 30,   -- 第30秒整理
        },
    },

    logrotate_m = {
        launch_seq = 100,
        launch_num = 1,
    },
}
```
