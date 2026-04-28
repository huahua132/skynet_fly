# 技能：可热更游戏房间模式

> **适用场景**: 搭建完整的"登录→大厅→匹配→游戏桌"房间游戏架构
> **关键词**: 房间游戏, room_game, hall, alloc, table, 大厅, 匹配, 桌子, 游戏逻辑, plug
> **参考示例**: `examples/digitalbomb/`

---

## 🏗️ 整体架构

```
客户端
  │
  ▼
[room_game_login] ← 登录/连接（TCP/WebSocket）
  │
  ▼
[room_game_hall_m] ← 大厅服（每个玩家挂在一个hall实例上）
  │  匹配请求
  ▼
[room_game_alloc_m] ← 分配服（管理全局桌子分配、状态）
  │  分配桌子
  ▼
[room_game_table_m] ← 桌子服（运行游戏逻辑，每桌独立）
```

**各内置模块职责**：
| 模块 | 职责 | 配置方式 |
|------|------|---------|
| `room_game_hall_m` | 管理玩家连接/登录状态，处理大厅消息（匹配等） | `hall_plug = "hall.hall_plug"` |
| `room_game_alloc_m` | 全局桌子分配、状态跟踪（可用桌/满桌） | `alloc_plug = "alloc.alloc_plug"` |
| `room_game_table_m` | 桌子实例，运行具体游戏逻辑 | `table_plug = "table.table_plug"` |

---

## 📁 目录结构约定

```
my_game/
├── load_mods.lua          # 服务配置
├── main.lua               # 入口
├── hall/
│   └── hall_plug.lua      # 大厅plug（处理大厅消息）
├── alloc/
│   └── alloc_plug.lua     # 分配plug（管理桌子分配）
├── table/
│   ├── table_plug.lua     # 桌子plug（桌子生命周期）
│   └── table_logic.lua    # 桌子游戏逻辑
├── login/
│   └── login_plug.lua     # 登录plug（可选，验证登录）
├── enum/
│   ├── GAME_STATE.lua     # 游戏状态枚举
│   └── errorcode.lua      # 错误码
└── msg/
    ├── game_msg.lua       # 游戏消息封装
    └── errors_msg.lua     # 错误消息封装
```

---

## 📋 load_mods.lua 配置

```lua
-- load_mods.lua
return {
    share_config_m = {
        launch_seq = 1,
        launch_num = 1,
        default_arg = {
            -- 登录服配置（gate监听端口）
            room_game_login = {
                gateconf = {
                    address = '0.0.0.0',
                    port = 8001,
                    maxclient = 2048,
                },
                wsgateconf = {  -- WebSocket（可选）
                    address = '0.0.0.0',
                    port = 8002,
                    maxclient = 2048,
                },
                login_plug = "login.login_plug",  -- 登录plug路径
            },
            server_cfg = { loglevel = "info" },
        }
    },

    -- 大厅服（多实例，玩家连接后分配到某个hall）
    room_game_hall_m = {
        launch_seq = 2,
        launch_num = 6,
        default_arg = {
            hall_plug = "hall.hall_plug",   -- 大厅plug路径
        }
    },

    -- 分配服（单实例，全局管理桌子分配）
    room_game_alloc_m = {
        launch_seq = 3,
        launch_num = 1,
        default_arg = {
            alloc_plug = "alloc.alloc_plug",    -- 分配plug路径
            MAX_TABLES = 10000,                 -- 最多桌子数
            max_empty_time = 60,                -- 空置超时（秒）
        }
    },

    -- 桌子服（多实例，用instance_name区分不同房间类型）
    room_game_table_m = {
        launch_seq = 4,
        launch_num = 6,
        mod_args = {
            {instance_name = "room_1", table_plug = "table.table_plug", table_conf = {player_num = 2}},
            {instance_name = "room_2", table_plug = "table.table_plug", table_conf = {player_num = 2}},
            {instance_name = "room_3", table_plug = "table.table_plug", table_conf = {player_num = 2}},
            {instance_name = "room_4", table_plug = "table.table_plug", table_conf = {player_num = 4}},
            {instance_name = "room_5", table_plug = "table.table_plug", table_conf = {player_num = 4}},
            {instance_name = "room_6", table_plug = "table.table_plug", table_conf = {player_num = 4}},
        },
    },
}
```

---

## 🏪 hall_plug.lua 大厅插件

> 处理玩家在大厅的消息（匹配、退出等），通过 `interface_mgr` 操作玩家状态

```lua
-- hall/hall_plug.lua
local log            = require "skynet-fly.log"
local timer          = require "skynet-fly.timer"
local errors_msg     = require "msg.errors_msg"
local login_msg      = require "msg.login_msg"
local spnet_util     = require "skynet-fly.utils.net.spnet_util"

local g_interface_mgr = nil

local M = {}

-- ★ 发包函数（选择协议）
M.send      = spnet_util.send
M.broadcast = spnet_util.broadcast

-- 掉线超时时间（超时后清理玩家）
M.disconn_time_out = timer.minute

-- ★ 必须实现：初始化，注册消息处理
function M.init(interface_mgr)
    g_interface_mgr = interface_mgr
    errors_msg = errors_msg:new(interface_mgr)
    login_msg  = login_msg:new(interface_mgr)

    -- 注册消息处理（sproto协议名）
    interface_mgr:handle('LoginOutReq', function(player_id, packname, pack_body)
        local ok, errcode, errmsg = interface_mgr:goout(player_id)
        if ok then
            login_msg:login_out_res(player_id, {player_id = player_id})
        end
        return ok, errcode, errmsg
    end)

    interface_mgr:handle('matchReq', function(player_id, packname, pack_body)
        -- match_join_table 自动匹配或创建桌子
        local ok, errcode, errmsg = interface_mgr:match_join_table(player_id, pack_body.table_name)
        if ok then
            login_msg:match_res(player_id, {table_id = ok})
        end
        return ok, errcode, errmsg
    end)
end

-- ★ 玩家连接时调用（返回玩家信息，nil则拒绝进入）
function M.connect(player_id)
    log.info("connect:", player_id)
    return { player_id = player_id }   -- 返回nil则拒绝连接
end

-- ★ 玩家断线时调用
function M.disconnect(player_id)
    log.info("disconnect:", player_id)
end

-- ★ 玩家重连时调用
function M.reconnect(player_id)
    log.info("reconnect:", player_id)
    return { player_id = player_id }
end

-- ★ 玩家登出时调用
function M.goout(player_id)
    log.info("goout:", player_id)
end

-- ★ 消息处理前过滤（返回true才继续处理）
function M.handle_before(player_id, packname, pack_body)
    return true
end

-- ★ 消息处理后回调
function M.handle_end(player_id, packname, pack_body, ret, errcode, errmsg)
    if not ret then
        errors_msg:errors(player_id, errcode, errmsg, packname)
    end
end

-- ★ 进入桌子回调
function M.join_table(player_id, table_name, table_id)
    log.info("join_table:", player_id, table_name, table_id)
end

-- ★ 离开桌子回调
function M.leave_table(player_id, table_name, table_id)
    log.info("leave_table:", player_id, table_name, table_id)
end

-- 热更新钩子
function M.herald_exit() log.info("hall herald_exit") end
function M.exit()        log.info("hall exit"); return true end
function M.fix_exit()    log.info("hall fix_exit") end
function M.cancel_exit() log.info("hall cancel_exit") end
function M.check_exit()  return true end

return M
```

---

## 🎯 alloc_plug.lua 分配插件

> 管理全局桌子分配，跟踪每张桌子的状态和玩家列表

```lua
-- alloc/alloc_plug.lua
local log        = require "skynet-fly.log"
local GAME_STATE = require "enum.GAME_STATE"
local errorcode  = require "enum.errorcode"
local pairs      = pairs
local ipairs     = ipairs
local next       = next
local assert     = assert

local g_table_map       = {}   -- table_id → table_info
local g_cant_enter_map  = {}   -- table_id → true（满桌）

local M = {}

-- ★ CMD中的函数可被桌子服调用（通过 interface_mgr:call_alloc）
local CMD = {}

-- 桌子服更新状态时调用
function CMD.update_state(table_id, state)
    local t_info = g_table_map[table_id]
    if not t_info then return end
    if t_info.state == GAME_STATE.stop then return end
    t_info.state = state
end

M.register_cmd = CMD   -- ★ 将CMD注册给内置模块

-- ★ 初始化（⚠️ 此处不能直接访问其他服务，用fork）
function M.init(alloc_mgr)
    -- alloc_mgr 提供 create_table/dismiss_table 等操作
end

-- ★ 匹配桌子（返回table_id，无则返回nil）
function M.match(player_id)
    local max_player_num = 0
    local table_num_map  = {}

    for table_id, t_info in pairs(g_table_map) do
        local player_num = #t_info.player_list
        if not table_num_map[player_num] then table_num_map[player_num] = {} end
        if not g_cant_enter_map[table_id] then
            table.insert(table_num_map[player_num], t_info)
        end
        if t_info.config.table_conf.player_num > max_player_num then
            max_player_num = t_info.config.table_conf.player_num
        end
    end

    -- 优先进入人数最多的桌子（避免浪费）
    for i = max_player_num - 1, 0, -1 do
        local t_list = table_num_map[i]
        if t_list then
            for _, t_info in ipairs(t_list) do
                if t_info.state == GAME_STATE.waiting then
                    return t_info.table_id
                end
            end
        end
    end
    return nil
end

-- ★ 创建桌子时调用
function M.createtable(table_name, table_id, config, create_player_id)
    assert(not g_table_map[table_id], "repeat table_id")
    g_table_map[table_id] = {
        table_id    = table_id,
        table_name  = table_name,
        config      = config,
        state       = GAME_STATE.waiting,
        player_list = {},
    }
end

-- ★ 玩家进入桌子
function M.entertable(table_id, player_id)
    local t_info = g_table_map[table_id]
    assert(t_info, "table not exists")
    table.insert(t_info.player_list, player_id)
    if #t_info.player_list == t_info.config.table_conf.player_num then
        g_cant_enter_map[table_id] = true   -- 标记满桌
    end
end

-- ★ 玩家离开桌子
function M.leavetable(table_id, player_id)
    local t_info = g_table_map[table_id]
    assert(t_info, "table not exists")
    for i = #t_info.player_list, 1, -1 do
        if t_info.player_list[i] == player_id then
            table.remove(t_info.player_list, i)
            g_cant_enter_map[table_id] = nil  -- 有空位了
            return
        end
    end
end

-- ★ 解散桌子
function M.dismisstable(table_id)
    assert(g_table_map[table_id], "table not exists")
    local t_info = g_table_map[table_id]
    assert(not next(t_info.player_list), "still has players")
    g_cant_enter_map[table_id] = nil
    g_table_map[table_id] = nil
end

-- ★ 桌子满时的错误返回
function M.tablefull()
    return nil, errorcode.TABLE_FULL, "table full"
end

-- ★ 桌子不存在的错误返回
function M.table_not_exists()
    return nil, errorcode.TABLE_NOT_EXISTS, "not table"
end

-- 热更新钩子
function M.herald_exit() log.info("alloc herald_exit") end
function M.exit()        log.info("alloc exit"); return true end
function M.fix_exit()    log.info("alloc fix_exit") end
function M.cancel_exit() log.info("alloc cancel_exit") end
function M.check_exit()  return true end

return M
```

---

## 🎮 table_plug.lua 桌子插件

> 每张桌子的生命周期管理，创建时实例化游戏逻辑对象

```lua
-- table/table_plug.lua
local log          = require "skynet-fly.log"
local module_cfg   = require "skynet-fly.etc.module_info".get_cfg()
local table_logic  = hotfix_require "table.table_logic"   -- ★ 用hotfix_require支持热更
local errors_msg   = require "msg.errors_msg"
local spnet_util   = require "skynet-fly.utils.net.spnet_util"

local g_table_conf    = module_cfg.table_conf   -- 来自load_mods的table_conf配置
local g_interface_mgr = nil

local M = {}

M.send      = spnet_util.send
M.broadcast = spnet_util.broadcast

-- ★ 初始化
function M.init(interface_mgr)
    g_interface_mgr = interface_mgr
    assert(g_table_conf.player_num, "not player_num")
    -- 加载协议（按需）
    -- sp_netpack.load('./sproto')
end

-- ★ 核心：桌子创建函数（每次创建新桌子时调用）
--   table_id: 桌子ID，table_name: 桌子类型名，...: 额外参数（如创建者player_id）
function M.table_creator(table_id, table_name, ...)
    local args             = {...}
    local create_player_id = args[1]

    -- 为每张桌子创建独立的interface和logic对象
    local m_interface_mgr = g_interface_mgr:new(table_id)
    local m_errors_msg    = errors_msg:new(m_interface_mgr)
    local m_logic         = table_logic:new(m_interface_mgr, g_table_conf, table_id)

    log.info("table_creator:", table_id, table_name, create_player_id)

    -- ★ 返回桌子对象（框架调用这些方法）
    return {
        -- 玩家进入桌子
        enter = function(player_id)
            return m_logic:enter(player_id)
        end,

        -- 玩家离开桌子
        leave = function(player_id)
            return m_logic:leave(player_id)
        end,

        -- 玩家断线
        disconnect = function(player_id)
            return m_logic:disconnect(player_id)
        end,

        -- 玩家重连
        reconnect = function(player_id)
            return m_logic:reconnect(player_id)
        end,

        -- ★ 消息处理表（协议名 → 处理函数）
        handle = {
            ['MyGameReq'] = function(player_id, packname, pack_body)
                return m_logic:my_game_req(player_id, packname, pack_body)
            end,
        },

        -- 消息前置过滤（返回true才继续）
        handle_before = function(player_id, packname, pack_body)
            return true
        end,

        -- 消息处理结束回调
        handle_end = function(player_id, packname, pack_body, ret, errcode, errmsg)
            if not ret then
                m_errors_msg:errors(player_id, errcode, errmsg, packname)
            end
        end,

        -- 热更新钩子
        herald_exit = function() return m_logic:herald_exit() end,
        exit        = function() return m_logic:exit() end,
        fix_exit    = function() return m_logic:fix_exit() end,
        cancel_exit = function() return m_logic:cancel_exit() end,
        check_exit  = function() return m_logic:check_exit() end,
    }
end

return M
```

---

## 🧠 table_logic.lua 游戏逻辑

> 具体游戏逻辑（面向对象，每桌一个实例）

```lua
-- table/table_logic.lua
local log        = require "skynet-fly.log"
local GAME_STATE = require "enum.GAME_STATE"
local errorcode  = require "enum.errorcode"
local game_msg   = require "msg.game_msg"
local skynet     = require "skynet"

local setmetatable = setmetatable

local M  = {}
local mt = {__index = M}

-- 构造函数（每张桌子一个实例）
function M:new(interface_mgr, table_conf, table_id)
    local t = {
        m_interface_mgr = interface_mgr,
        m_game_msg      = game_msg:new(interface_mgr),
        m_table_id      = table_id,
        m_table_conf    = table_conf,
        m_game_state    = GAME_STATE.waiting,
        -- 游戏状态数据
        m_player_seat_map = {},
        m_seat_list       = {},
    }
    setmetatable(t, mt)
    return t
end

-- ★ 玩家进入（由table_plug的enter调用）
function M:enter(player_id)
    -- 分配座位、更新状态
    log.info("enter:", player_id)
    -- 满员时开始游戏（用fork避免阻塞）
    -- skynet.fork(function() self:game_start() end)
    return seat_id
end

-- ★ 玩家离开
function M:leave(player_id)
    log.info("leave:", player_id)
    return seat_id
end

-- ★ 玩家断线
function M:disconnect(player_id)
    log.info("disconnect:", player_id)
end

-- ★ 玩家重连
function M:reconnect(player_id)
    log.info("reconnect:", player_id)
end

-- ★ 游戏业务逻辑（对应table_plug.handle中的消息）
function M:my_game_req(player_id, packname, pack_body)
    -- 处理客户端请求
    return true
end

-- 游戏开始
function M:game_start()
    self.m_interface_mgr:call_alloc("update_state", GAME_STATE.playing)
    self.m_game_state = GAME_STATE.playing
    -- ...游戏逻辑
end

-- 游戏结束
function M:game_over(loser_player_id)
    self.m_interface_mgr:call_alloc("update_state", GAME_STATE.over)
    self.m_game_state = GAME_STATE.over
    -- 踢出所有玩家
    self.m_interface_mgr:kick_out_all()
    return true
end

-- 热更新钩子
function M:herald_exit() log.info("table herald_exit", self.m_table_id) end
function M:exit()
    log.info("table exit", self.m_table_id)
    return true
end
function M:fix_exit()
    -- 热更时通知alloc标记桌子停止
    self.m_interface_mgr:call_alloc("update_state", GAME_STATE.stop)
end
function M:cancel_exit() log.info("table cancel_exit", self.m_table_id) end
function M:check_exit()  return true end

return M
```

---

## 📌 关键 API：interface_mgr

> `table_plug` 和 `hall_plug` 的 `M.init(interface_mgr)` 中拿到的对象

| 方法 | 说明 | 适用 |
|------|------|------|
| `interface_mgr:handle(packname, fn)` | 注册消息处理 | hall |
| `interface_mgr:goout(player_id)` | 玩家登出 | hall |
| `interface_mgr:match_join_table(player_id, table_name)` | 匹配加桌 | hall |
| `interface_mgr:get_addr(player_id)` | 获取玩家连接地址 | hall/table |
| `interface_mgr:get_hall_server_id()` | 获取大厅服ID | hall |
| `interface_mgr:get_alloc_server_id(player_id)` | 获取分配服ID | hall |
| `interface_mgr:get_table_server_id(player_id)` | 获取桌子服ID | hall |
| `interface_mgr:get_table_id(player_id)` | 获取桌子ID | hall |
| `interface_mgr:new(table_id)` | 为新桌子创建interface | table_plug |
| `interface_mgr:call_alloc(cmd, ...)` | 调用alloc_plug的CMD | table |
| `interface_mgr:kick_out_all()` | 踢出桌子所有玩家 | table |

---

## ⚠️ 注意事项

| 注意点 | 说明 |
|--------|------|
| `hotfix_require` | table_logic 用 `hotfix_require`（而非require）加载，支持独立热更游戏逻辑 |
| alloc.init中访问其他服务 | 用 `skynet.fork` 包裹，避免初始化时阻塞 |
| table_creator返回table | 必须包含 enter/leave/disconnect/reconnect/handle/herald_exit/exit 等字段 |
| register_cmd | alloc_plug 中定义的 `CMD` 需赋给 `M.register_cmd`，供桌子服通过 `call_alloc` 调用 |
| instance_name | 不同房间类型用不同 instance_name，alloc匹配时按 table_name 区分 |
