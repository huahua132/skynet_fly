# 技能：使用 ORM 操作数据库

> **适用场景**: 用 skynet_fly ORM 框架操作 MySQL / MongoDB
> **关键词**: ORM, ormtable, ormadapter_mysql, orm_table_m, orm_plug, orm_table_client, 数据库, CRUD
> **参考示例**: `examples/orm/`

---

## 整体架构

```
1. 定义 orm_plug/entry_xxx.lua     定义表结构和CRUD handle
2. 在 load_mods.lua 配置 orm_table_m  挂载 orm_plug
3. 在业务模块中用 orm_table_client 调用  跨服务访问 ORM
```

**为什么要用 orm_table_m？**
ORM 有缓存机制，缓存只能被一个服务持有。当多个服务都需要访问数据库时，统一把 ORM 挂在 `orm_table_m` 热更服务中，其他服务通过 `orm_table_client` 跨服务调用，避免缓存重复/冲突。

---

## Step1 定义 orm_plug

```lua
-- orm_plug/entry_player.lua
local ormtable         = require "skynet-fly.db.orm.ormtable"
local ormadapter_mysql = require "skynet-fly.db.ormadapter.ormadapter_mysql"

local g_orm  = nil
local M      = {}
local handle = {}

-- 必须实现 init，返回 g_orm 对象
function M.init()
    local adapter = ormadapter_mysql:new("admin")  -- 对应 load_mods 中 mysql.admin

    g_orm = ormtable:new("t_player")
        :int64("player_id")
        :string64("nickname")
        :int8("sex")
        :int8("status")
        :table("extra_data")            -- table类型自动JSON序列化
        :set_index("sex_index", "sex")  -- 普通索引(索引名, 字段名...)
        :set_keys("player_id")          -- 主键字段
        :builder(adapter)               -- 绑定适配器，完成构建

    return g_orm
end

-- CRUD handle（由 orm_table_client 远程调用，handle.xxx -> client:xxx）

function handle.not_exist_create(entry_data)
    local entry = g_orm:get_one_entry(entry_data.player_id)
    if entry then return end
    entry = g_orm:create_one_entry(entry_data)
    if not entry then return end
    return entry:get_entry_data()
end

function handle.get(player_id)
    local list = g_orm:get_entry(player_id)
    if #list <= 0 then return end
    return list[1]:get_entry_data()
end

function handle.get_one(player_id)
    local entry = g_orm:get_one_entry(player_id)
    if not entry then return end
    return entry:get_entry_data()
end

function handle.change_status(player_id, new_status)
    local list = g_orm:get_entry(player_id)
    if #list <= 0 then return end
    local entry = list[1]
    entry:set("status", new_status)
    return g_orm:save_one_entry(entry)
end

M.handle = handle   -- 必须赋给 M.handle
return M
```

---

## Step2 load_mods.lua 配置

```lua
share_config_m = {
    launch_seq = 1, launch_num = 1,
    default_arg = {
        mysql = {
            admin = { host='127.0.0.1', port='3306', user='root', password='123456', database='mydb' }
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
```

---

## Step3 业务模块中使用 orm_table_client

```lua
local orm_table_client = require "skynet-fly.client.orm_table_client"

-- 常驻实例（推荐）
local c = orm_table_client:instance("player")

-- 临时实例
local c = orm_table_client:new("player")

-- 调用 handle.xxx -> c:xxx
local data = c:get(player_id)
local ok   = c:not_exist_create({player_id = 10001})
local ok   = c:change_status(player_id, 1)
```

orm_table_client 内部已自动 register 了 orm_table_m，无需手动 register。

---

## orm_table_client 内置通用方法

```lua
local c = orm_table_client:instance("player")

-- 创建
c:create_one_entry({player_id=10001, ...})
c:create_entry({{...},{...}})                    -- 批量（有冲突跳过）

-- 查询
c:get_entry(player_id)                           -- 按主键（返回entry_data列表）
c:get_one_entry(player_id)                       -- 查单条（先查缓存）
c:get_all_entry()
c:get_entry_by_in({10001, 10002, 10003})         -- IN查询
c:get_entry_by_limit(cursor, limit, sort)        -- 分页（返回cursor, list, count）
c:idx_get_entry({sex = 1})                       -- 按索引查询
c:idx_get_entry_by_limit(cursor, limit, sort, idx_name, {}, offset)

-- 批量更新
c:change_save_entry({{player_id=1, nickname="a"},...})
c:change_save_one_entry({player_id=1, nickname="a"})

-- 删除
c:delete_entry(player_id)
c:delete_entry_by_in({10001, 10002})
c:delete_entry_by_range(player_id)               -- 范围删除（>= 该主键）
c:batch_delete_entry({{10001},{10002}})
c:delete_all_entry()                             -- 删除全部（慎用）
```

### 分页查询示例

```lua
local limit = 10
local sort  = 1   -- 1=升序，-1=降序

local cursor, list, count = c:get_entry_by_limit(nil, limit, sort)   -- 第一页
cursor, list, count = c:get_entry_by_limit(cursor, limit, sort)      -- 第二页
```

---

## ormtable 在 orm_plug 内部直接操作

```lua
-- 创建
local entry    = g_orm:create_one_entry(data)
local res_list = g_orm:create_entry(data_list)

-- 查询
local entry_list = g_orm:get_entry(key)
local entry      = g_orm:get_one_entry(key)

-- 修改 entry
local val = entry:get("field_name")
entry:set("field_name", new_val)
local data = entry:get_entry_data()

-- 保存
local ok      = g_orm:save_one_entry(entry)
local ok_list = g_orm:save_entry(entry_list)
```

---

## 字段类型速查

| 类型 | 说明 | 可作索引 |
|------|------|---------|
| `int8` `int16` `int32` `int64` | 有符号整数 | 可以 |
| `uint8` `uint16` `uint32` | 无符号整数 | 可以 |
| `string32` 到 `string512` | 短字符串 | 可以 |
| `string1024` 到 `string8192` | 长字符串 | 不能 |
| `text` | 长文本 | 不能 |
| `blob` | 二进制 | 不能 |
| `table` | Lua表（自动JSON序列化） | 不能 |

---

## 注意事项

| 注意点 | 说明 |
|--------|------|
| ORM 缓存独占 | 同一张表只能被一个服务持有，其他服务必须通过 orm_table_client 访问 |
| orm_table_m 的 launch_seq | 通常设 1000，确保先于业务服务运行 |
| orm_table_client 已自动 register | 无需手动 register orm_table_m |
| table 类型字段 | 自动 JSON 序列化存库，读出来是 Lua table |
| 主键字段 | 创建时必须显式传入主键 |
| get_entry vs get_one_entry | get_entry 直接查DB；get_one_entry 先查内存缓存 |
| 热更时的 ORM | orm_table_client 已设 set_always_swtich，热更后自动切换 |
