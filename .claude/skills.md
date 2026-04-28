# skynet_fly 技能索引（Skills Index）

> 每个技能独立成一个文件，放在 `.claude/skills/` 目录

---

## 技能列表

| 技能文件 | 说明 |
|---------|------|
| [`skills/skill_write_hotreload_module.md`](skills/skill_write_hotreload_module.md) | 编写可热更模块（_m.lua）：模板、规则、load_mods配置、互访设置 |
| [`skills/skill_room_game_mode.md`](skills/skill_room_game_mode.md) | 可热更游戏房间模式：hall/alloc/table三层架构、各plug模板、interface_mgr API |
| [`skills/skill_load_mods_config.md`](skills/skill_load_mods_config.md) | 编写 load_mods.lua 配置：全量参数说明、8种场景模板（HTTP/房间游戏/ORM/多实例/延迟/热更等） |
| [`skills/skill_container_client.md`](skills/skill_container_client.md) | 使用 container_client 调用其他服务：初始化配置、全部调用方式、互访设置、6个完整示例 |
| [`skills/skill_http_dispatch.md`](skills/skill_http_dispatch.md) | 编写 HTTP Web 接口（dispatch文件）：路由/参数/中间件/静态文件/req&res API/完整综合示例 |
| [`skills/skill_orm_database.md`](skills/skill_orm_database.md) | 使用 ORM 操作数据库：orm_plug定义/load_mods配置/orm_table_client调用/全部CRUD方法/分页查询 |
| [`skills/skill_timer.md`](skills/skill_timer.md) | 使用定时器：时间常量/一次性/循环/取消/延长/剩余时间查询/5种典型场景 |
| [`skills/skill_log.md`](skills/skill_log.md) | 使用日志系统：log.info/error/warn/debug/fatal/fmt版/add_hook/日志级别配置 |
| [`skills/skill_frpc.md`](skills/skill_frpc.md) | 跨节点 RPC 调用：三种模式/load_mods配置/基本调用/by_name/byid/all/监听上下线/Sub-Pub |
| [`skills/skill_share_config.md`](skills/skill_share_config.md) | 共享配置读取：share_config.get用法/在load_mods定义配置/完整使用示例 |
| [`skills/skill_record.md`](skills/skill_record.md) | 服务录像：开启录像/录像文件结构/播放重放/record_backup整理/hotfix_require |
