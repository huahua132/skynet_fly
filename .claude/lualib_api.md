# lualib/skynet-fly API 索引

> 用于快速定位各模块的文件路径和核心API，辅助代码阅读和实现
> **路径前缀**: `lualib/skynet-fly/`，require路径前缀: `skynet-fly.`

---

## 核心模块

| require路径 | 文件路径 | 核心API |
|------------|---------|---------|
| `skynet-fly.log` | `log.lua` | `info/debug/warn/error/fatal` `info_fmt/...` `add_hook(level, fn)` |
| `skynet-fly.timer` | `timer.lua` | `timer:new(expire, times, fn, ...)` `:cancel()` `:extend()` `:remain_expire()` `:after_next()` |
| `skynet-fly.sharedata` | `sharedata.lua` | `sharedata:new(path, enum):builder()` `:get_data_table()` |
| `skynet-fly.snowflake` | `snowflake.lua` | 雪花ID生成器 |

---

## client/ 客户端

| require路径 | 文件路径 | 核心API |
|------------|---------|---------|
| `skynet-fly.client.container_client` | `client/container_client.lua` | `register(mod)` `set_week_visitor(mod)` `set_always_swtich(mod)` `add_queryed_cb` `add_updated_cb` `instance(mod,name?)` `new(mod,name?)` `is_ready(mod)` |
| `skynet-fly.client.frpc_client` | `client/frpc_client.lua` | `frpc_client:new(mode, svr_name, module_name, instance_name?)` `instance(mode, svr_name, module_name, name?)` `balance_call/send` `mod_call/send` `broadcast_call/broadcast` `*_by_name变体` `is_active` `watch_up` `watch_all_up` |
| `skynet-fly.client.orm_table_client` | `client/orm_table_client.lua` | `orm_table_client:instance(orm_name)` `new(orm_name)` → 动态代理 handle.xxx |
| `skynet-fly.client.orm_frpc_client` | `client/orm_frpc_client.lua` | 跨节点ORM访问 |

---

## container/ 容器

| require路径 | 文件路径 | 核心API |
|------------|---------|---------|
| `skynet-fly.container.container_launcher` | `container/container_launcher.lua` | `container_launcher.run()` → 返回 `delay_run()` |
| `skynet-fly.container.container_interface` | `container/container_interface.lua` | 普通skynet服务使用，热更服务用return CMD |

---

## db/ 数据库

| require路径 | 文件路径 | 核心API |
|------------|---------|---------|
| `skynet-fly.db.orm.ormtable` | `db/orm/ormtable.lua` | 链式定义：`:int64/string64/table/set_keys/set_index/builder` `create_one_entry/get_entry/get_one_entry/save_one_entry` `entry:get/set/get_entry_data` |
| `skynet-fly.db.ormadapter.ormadapter_mysql` | `db/ormadapter/ormadapter_mysql.lua` | `ormadapter_mysql:new("config_name")` |
| `skynet-fly.db.ormadapter.ormadapter_mongo` | `db/ormadapter/ormadapter_mongo.lua` | `ormadapter_mongo:new("config_name")` |
| `skynet-fly.db.mysqlf` | `db/mysqlf.lua` | MySQL连接封装 |
| `skynet-fly.db.redisf` | `db/redisf.lua` | `redisf.new_client("config_name")` |
| `skynet-fly.db.mongof` | `db/mongof.lua` | MongoDB连接封装 |

---

## etc/ 配置/环境

| require路径 | 文件路径 | 核心API |
|------------|---------|---------|
| `skynet-fly.etc.share_config` | `etc/share_config.lua` | `share_config.get(key)` |
| `skynet-fly.etc.module_info` | `etc/module_info.lua` | `module_info.get_cfg()` `module_info.get_base_info()` |

---

## utils/ 工具函数

| require路径 | 文件路径 | 核心API |
|------------|---------|---------|
| `skynet-fly.utils.env_util` | `utils/env_util.lua` | `get_svr_id()` `get_svr_name()` `get_svr_type()` `add_pre_load(path)` `add_after_load(path)` |
| `skynet-fly.utils.time_util` | `utils/time_util.lua` | `time()` `skynet_int_time()` `mstime()` `date(time?)` `string_to_date(str)` `month_day(date,day)` |
| `skynet-fly.utils.table_util` | `utils/table_util.lua` | `dump(t)` `deep_copy(t)` `copy(t)` `merge(target,src)` `sort_ipairs(t,cmp?)` `sort_ipairs_byk(t,cmp?)` `kvsortipairs(t)` `count(t)` `inlist(list,v)` `find_index(list,v,idx?)` `check_def_table(new,old)` `def_tostring(def)` `is_loop_table(t)` `depth_to_list(t,depth)` `permute_pairs(arr)` |
| `skynet-fly.utils.string_util` | `utils/string_util.lua` | `split(str, sep1, sep2, ...)` `quote_sql_str(str)` |
| `skynet-fly.utils.file_util` | `utils/file_util.lua` | `mkdir(path)` `is_window()` `path_join(a,b)` `get_cur_dir_name()` `convert_path(path)` |
| `skynet-fly.utils.math_util` | `utils/math_util.lua` | `is_vaild_int8/uint8/int16/uint16/int32/uint32/int64(n)` `get_min_max(a,b)` `haversine(lon1,lat1,lon2,lat2)` `number_div_str(n,div)` **常量**: `int8min/max` `uint8max` `int16/uint16/int32/uint32/int64 min/max` |
| `skynet-fly.utils.guid_util` | `utils/guid_util.lua` | `fly_guid()` `get_svr_type_by_fly_guid(guid)` `get_svr_id_by_fly_guid(guid)` |
| `skynet-fly.utils.skynet_util` | `utils/skynet_util.lua` | `lua_dispatch(cmd_func)` `lua_src_dispatch(cmd_func)` `number_address(name)` |
| `skynet-fly.utils.crypt_util` | `utils/crypt_util.lua` | `HMAC.SHA256/SHA384/SHA512(data,key)` `DIGEST.SHA256/SHA384/SHA512(data,hex?)` |

---

## utils/net/ 网络工具

| require路径 | 文件路径 | 说明 |
|------------|---------|------|
| `skynet-fly.utils.net.pbnet_util` | `utils/net/pbnet_util.lua` | Protobuf TCP（通用） |
| `skynet-fly.utils.net.pbnet_byid` | `utils/net/pbnet_byid.lua` | Protobuf TCP（按消息ID） |
| `skynet-fly.utils.net.pbnet_byrpc` | `utils/net/pbnet_byrpc.lua` | Protobuf TCP（RPC方式） |
| `skynet-fly.utils.net.ws_pbnet_util` | `utils/net/ws_pbnet_util.lua` | Protobuf WebSocket |
| `skynet-fly.utils.net.spnet_util` | `utils/net/spnet_util.lua` | Sproto TCP（通用） |
| `skynet-fly.utils.net.spnet_byid` | `utils/net/spnet_byid.lua` | Sproto TCP（按消息ID） |
| `skynet-fly.utils.net.spnet_byrpc` | `utils/net/spnet_byrpc.lua` | Sproto TCP（RPC方式） |
| `skynet-fly.utils.net.ws_spnet_util` | `utils/net/ws_spnet_util.lua` | Sproto WebSocket |
| `skynet-fly.utils.net.jsonet_util` | `utils/net/jsonet_util.lua` | JSON TCP（通用） |
| `skynet-fly.utils.net.jsonet_byid` | `utils/net/jsonet_byid.lua` | JSON TCP（按消息ID） |
| `skynet-fly.utils.net.ws_jsonet_util` | `utils/net/ws_jsonet_util.lua` | JSON WebSocket |
| `skynet-fly.utils.net.rpc_client` | `utils/net/rpc_client.lua` | RPC客户端工具 |
| `skynet-fly.utils.net.rpc_server` | `utils/net/rpc_server.lua` | RPC服务端工具 |

---

## web/ HTTP框架

| require路径 | 文件路径 | 核心API |
|------------|---------|---------|
| `skynet-fly.web.engine_web` | `web/engine_web.lua` | `engine_web:new()` `engine_web:default()` `engine_web.dispatch(app)` `app:get/post(path,fn)` `app:group(prefix)` `app:use(middleware)` `app:static_file(url,path)` `app:static_dir(url,dir)` `app:set_no_route(fn...)` `app:run()` |
| `skynet-fly.web.HTTP_STATUS` | `web/HTTP_STATUS.lua` | `HTTP_STATUS.OK/Not_Found/Bad_Request/...` |
| `skynet-fly.web.middleware.logger_mid` | `web/middleware/logger_mid.lua` | `logger_mid()` |
| `skynet-fly.web.middleware.cors_mid` | `web/middleware/cors_mid.lua` | `cors_mid()` |

**context(c) 字段**：
- `c.req.path` `c.req.method` `c.req.query` `c.req.body` `c.req.body_raw` `c.req.header`
- `c.params` (路由参数)
- `c.res:set_rsp(text,status,ct?)` `c.res:set_json_rsp(table)` `c.res:set_error_rsp(status)` `c.res:set_header(k,v)`
- `c:next()` (继续下一中间件) `c:abort()` (中止)

---

## rpc/ 订阅/发布

| require路径 | 文件路径 | 核心API |
|------------|---------|---------|
| `skynet-fly.rpc.watch_client` | `rpc/watch_client.lua` | `watch_client:watch(svr_name, channel, fn)` `unwatch(svr_name, channel)` |
| `skynet-fly.rpc.watch_syn_client` | `rpc/watch_syn_client.lua` | 同步订阅客户端 |

---

## netpack/ 网络包

| require路径 | 文件路径 | 说明 |
|------------|---------|------|
| `skynet-fly.netpack.pb_netpack` | `netpack/pb_netpack.lua` | Protobuf包，`pb_netpack.load('./proto')` |
| `skynet-fly.netpack.sp_netpack` | `netpack/sp_netpack.lua` | Sproto包，`sp_netpack.load('./sproto')` |

---

## watch/ 数据同步

| require路径 | 文件路径 | 说明 |
|------------|---------|------|
| `skynet-fly.watch.watch_syn` | `watch/watch_syn.lua` | 同步数据订阅 |

---

## hotfix/ 热更新

| require路径 | 文件路径 | 说明 |
|------------|---------|------|
| `hotfix_require "xxx"` | `hotfix/hotfix.lua` | 加载可热更文件（全局函数，不是require） |

---

## time_extend/ 时间扩展

| require路径 | 文件路径 | 核心API |
|------------|---------|---------|
| `skynet-fly.time_extend.wait` | `time_extend/wait.lua` | `wait:new()` `:wait(key)` `:wakeup(key)` |
| `skynet-fly.time_extend.timer_point` | `time_extend/timer_point.lua` | 定时点（auto_reload使用的配置类型） |

---

## pool/ / cache/ / enum/ 其他

| require路径 | 文件路径 | 说明 |
|------------|---------|------|
| `skynet-fly.pool.table_pool` | `pool/table_pool.lua` | 表对象池，减少GC |
| `skynet-fly.cache.tti` | `cache/tti.lua` | TTI缓存（定时失效） |
| `skynet-fly.mult_queue` | `mult_queue.lua` | 多队列（并发控制） |
| `skynet-fly.mod_queue` | `mod_queue.lua` | 模块队列 |
