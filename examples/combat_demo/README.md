# combat_demo 战斗示例

基于 `skynet-fly.fight_frame` 的一个小型 2v2 英雄对战示例，用于演示战斗框架的完整接入与运行。

## 玩法

- 2 名玩家进入房间，各自点击"请求准备"（`request_ready`）。
- **两名玩家都准备好后**自动创建 `fight_world` 并开局。
- 每名玩家在 **10×10** 地图上随机生成 **2 名英雄**。
- 英雄属性随机：
  - 血量：100 ~ 300
  - 攻击力：10 ~ 30
  - 移速：0.3 ~ 0.6（单位/秒）
  - 攻击距离：0.5
  - 攻击 CD：5 秒
- 英雄 AI：随机锁定一名敌方英雄，追到攻击距离内则按 CD 攻击；歼灭某队所有英雄即分出胜负。

> 数值（位置、血量、攻击、移速、时间）统一采用 `skynet-fly.fixed`（Q16.16 定点数），
> 并用确定性伪随机数（LCG，种子可配），保证可复现、可回放校验。

## 文件结构

```
combat_demo/
├── main.lua                 # 服务入口（container_launcher.run）
├── load_mods.lua            # 声明 combat_m 可热更服务
├── module/
│   └── combat_m.lua         # 可热更服务模块：房间 + 玩家准备流程 + 演示驱动
└── combat/
    ├── combat_world.lua     # 战斗编排：准备→开局→生成英雄→胜负判定 + 确定性 RNG
    ├── component/
    │   ├── position_comp.lua # zc_position_comp 定点位置组件
    │   └── hero_comp.lua     # 英雄属性 + 逐帧 AI（锁定/追击/攻击）
    ├── entity/
    │   └── hero_entity.lua   # 英雄实体（组装各组件，自注册实体类型）
    └── module/
        └── combat_logic_module.lua # 战斗逻辑模块：清理阵亡 + 胜负判定
    standalone_run.lua         # 独立运行器（无需 skynet 容器，纯 Lua 模拟驱动打印日志）
```

## 接入 fight_frame 的方式

- **实体/组件自注册**：`hero_entity`/`position_comp`/`hero_comp` 经
  `skynet-fly.fight_frame.fight_register_type` 的 `register("entity"/"component", ...)` 自注册；
  组件模块在文件顶层 `require` 自身以触发注册。
- **世界创建**：`combat_world` 调用 `fight_world_manager.add_world(instance)`（默认挂载
  entity/event/collision/hash_search 四个模块），随后 `world:add_module("combat_logic_module", ...)`
  追加本例自定义的战斗逻辑模块。
- **位置契约**：`collision_comp` 从实体 `zc_position_comp:get_position()` 读取坐标；
  本示例的 `position_comp` 返回 Q16.16 定点坐标，保证全链确定性。
- **帧驱动**：`fight_world` 用 `skynet-fly.timer` 的 `new_loop` 定时调用 `world:update()`，
  依次驱动各模块更新。

## 运行

### 方式一：独立运行器（无需容器，推荐先跑这个看效果）

用项目自带的 Lua 5.5 执行，用模拟时钟驱动真实的 `fight_world` + `combat.*` 代码，
把完整战斗日志（玩家就绪 → 生成英雄 → AI 追击攻击 → 分出胜负）打印到控制台：

```bash
cd examples/combat_demo
../../build/skynet_fly/skynet/3rd/lua/lua.exe standalone_run.lua
```

### 方式二：在 skynet 容器中作为可热更服务运行

在项目根目录打好 Lua/Skynet 环境后，进入示例目录生成运行脚本并启动（
`make/script/run.*` 由框架的 `console.lua` 自动生成）：

```bash
# Linux
cd examples/combat_demo
# 第一次：生成运行脚本后启动（以下命令会在 make/script/ 生成 run.sh）
../../skynet/3rd/lua/lua ../../script/lua/write_config.lua ../../ load_mods.lua 1
../../skynet/3rd/lua/lua ../../script/lua/console.lua ../../ combat_demo load_mods.lua
make/script/run.sh load_mods.lua 0
```

```bat
:: Windows
cd /d examples\combat_demo
..\..\build\skynet_fly\skynet\3rd\lua\lua.exe ..\..\script\lua\write_config.lua ..\.. load_mods.lua 1
..\..\build\skynet_fly\skynet\3rd\lua\lua.exe ..\..\script\lua\console.lua ..\.. combat_demo load_mods.lua
:: 然后运行生成的 make\script\run.bat load_mods.lua 0
```

启动后服务日志会依次打印：玩家进入 → 生成英雄（属性/坐标）→ 战斗进度 → 阵亡 → 胜负。

## 对外命令（combat_m）

| 命令 | 说明 |
|------|------|
| `request_ready(player_id)` | 玩家请求准备；足额后自动开局 |
| `get_state()` | 查询战斗状态（含存活英雄列表） |
| `stop_room()` | 手动停止房间 |

> 演示模式（`combat_m.lua` 内 `g_auto_start=true`）会在启动 1 秒、2 秒后自动让两名玩家
> 依次准备，使战斗自动跑起来。若接入真实客户端，可把 `g_auto_start` 置为 `false`，
> 由外部依次调用 `request_ready`。
