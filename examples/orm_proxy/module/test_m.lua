local skynet = require "skynet"
local log = require "skynet-fly.log"
local orm_table_proxy = require "skynet-fly.client.orm_table_proxy"
local orm_table_client = require "skynet-fly.client.orm_table_client"

local CMD = {}

local assert = assert
local function eq(a, b)
    return a == b
end

--每个main_key一个proxy
--proxy不再有常驻实例，每次new独立拉取快照
local function get_player_proxy(main_key)
    return orm_table_proxy:new("player", main_key)
end

local function get_backpack_proxy(main_key)
    return orm_table_proxy:new("backpack", main_key)
end

--==================== 单主键表 t_player ====================

local function test_player_create()
    --每个main_key一个proxy，各自create自己的数据
    local proxy1 = get_player_proxy(10001)
    proxy1:create_one_entry({player_id = 10001, nickname = "p10001", sex = 1, status = 1})
    local proxy2 = get_player_proxy(10002)
    proxy2:create_one_entry({player_id = 10002, nickname = "p10002", sex = 1, status = 0})
    log.info("[p] test_player_create done")

    --本地快照立即可读(零call)
    local one = proxy1:get_one_entry(10001)
    assert(one and one.nickname == "p10001", "get_one_entry 10001 fail")
    log.info("[p] test_player_create get_one_entry 10001 >>>> ", one)

    --flush落库，供后续新proxy构造时拉到
    proxy1:flush_now()
    proxy2:flush_now()
    skynet.sleep(300)
end

local function test_player_get()
    local proxy = get_player_proxy(10001)
    --create后本地快照已含数据，get_entry读本地
    local list = proxy:get_entry(10001)
    assert(#list == 1 and list[1].player_id == 10001, "get_entry fail")
    log.info("[p] test_player_get get_entry 10001 >>>> ", list)

    local one = proxy:get_one_entry(10001)
    assert(one and one.nickname == "p10001", "get_one_entry fail")
    log.info("[p] test_player_get get_one_entry >>>> ", one)

    local all = proxy:get_all_entry()
    assert(#all == 1, "get_all_entry count fail")
    log.info("[p] test_player_get get_all_entry >>>> ", all)

    --单主键proxy无第二级key，不存在key查询用多主键表覆盖
end

local function test_player_save()
    local proxy = get_player_proxy(10001)
    --save_one_entry 修改
    proxy:save_one_entry({player_id = 10001, nickname = "p10001_mod", sex = 1, status = 0})
    local one = proxy:get_one_entry(10001)
    assert(one and one.nickname == "p10001_mod" and one.status == 0, "save_one_entry local fail")
    log.info("[p] test_player_save after save_one >>>> ", one)

    --save_entry 批量(本main_key内多条)
    proxy:save_entry({
        {player_id = 10001, nickname = "p10001_batch", sex = 1, status = 1},
        {player_id = 10001, nickname = "p10001_batch2", sex = 1, status = 1},
    })
    local one2 = proxy:get_one_entry(10001)
    assert(one2 and one2.nickname == "p10001_batch2" and one2.status == 1, "save_entry local fail")
    log.info("[p] test_player_save after save_entry >>>> ", one2)

    --10002用自己的proxy保存
    local proxy2 = get_player_proxy(10002)
    proxy2:save_one_entry({player_id = 10002, nickname = "p10002_mod", sex = 1, status = 1})
    local one3 = proxy2:get_one_entry(10002)
    assert(one3 and one3.nickname == "p10002_mod", "proxy2 save fail")
    log.info("[p] test_player_save proxy2 >>>> ", one3)

    --flush落库
    proxy:flush_now()
    proxy2:flush_now()
    skynet.sleep(300)
end

local function test_player_delete()
    local proxy = get_player_proxy(10002)
    proxy:delete_entry(10002)
    log.info("[p] test_player_delete delete_entry 10002 done")
    local one = proxy:get_one_entry(10002)
    assert(one == nil, "delete_entry local fail")
    log.info("[p] test_player_delete after delete 10002 >>>> ", one)

    --flush落库
    proxy:flush_now()
    skynet.sleep(300)
end

local function test_player_delete_all()
    local proxy = get_player_proxy(10001)
    proxy:delete_all_entry()
    log.info("[p] test_player_delete_all done")
    local all = proxy:get_all_entry()
    assert(#all == 0, "delete_all local fail")
    log.info("[p] test_player_delete_all after >>>> ", all)

    --等delete_all异步落库完成，避免与后续create同批次冲突
    proxy:flush_now()
    skynet.sleep(300)

    --重新create恢复，供后续consistency对照
    proxy:create_one_entry({player_id = 10001, nickname = "p10001_final", sex = 1, status = 1})
    proxy:flush_now()
    skynet.sleep(300)
end

--==================== 多主键嵌套表 t_backpack ====================

-- create 3条：10001下 item(1,1)/item(1,2)/item(2,1)
local function test_bag_create()
    local proxy = get_backpack_proxy(10001)
    proxy:create_one_entry({player_id = 10001, item_id = 1, slot_id = 1, count = 10, prop = "a"})
    proxy:create_one_entry({player_id = 10001, item_id = 1, slot_id = 2, count = 20, prop = "b"})
    proxy:create_one_entry({player_id = 10001, item_id = 2, slot_id = 1, count = 30, prop = "c"})
    --另一个main_key
    get_backpack_proxy(10002):create_one_entry({player_id = 10002, item_id = 1, slot_id = 1, count = 99, prop = "p2"})
    log.info("[b] test_bag_create done")

    --本地立即可读
    local one = proxy:get_one_entry(10001, 1, 1)
    assert(one and one.count == 10, "bag get_one (10001,1,1) fail")
    log.info("[b] test_bag_create get_one (10001,1,1) >>>> ", one)

    --flush落库，供后续新proxy构造时拉到
    proxy:flush_now()
    get_backpack_proxy(10002):flush_now()
    skynet.sleep(300)
end

local function test_bag_get()
    local proxy = get_backpack_proxy(10001)

    --最左前缀 get_entry(10001) 返回全部3条
    local all = proxy:get_entry(10001)
    assert(#all == 3, "bag get_entry(10001) count fail, got " .. #all)
    log.info("[b] test_bag_get get_entry(10001) >>>> ", all)

    --最左前缀 get_entry(10001,1) 返回 item=1 的2条
    local item1 = proxy:get_entry(10001, 1)
    assert(#item1 == 2, "bag get_entry(10001,1) count fail, got " .. #item1)
    log.info("[b] test_bag_get get_entry(10001,1) >>>> ", item1)

    --完整主键 get_one_entry(10001,2,1)
    local one = proxy:get_one_entry(10001, 2, 1)
    assert(one and one.count == 30, "bag get_one (10001,2,1) fail")
    log.info("[b] test_bag_get get_one (10001,2,1) >>>> ", one)

    --不存在
    local nil_one = proxy:get_one_entry(10001, 9, 9)
    assert(nil_one == nil, "bag get_one (10001,9,9) should nil")
    log.info("[b] test_bag_get nil-key ok")

    --另一个main_key隔离
    local p2_all = get_backpack_proxy(10002):get_all_entry()
    assert(#p2_all == 1 and p2_all[1].count == 99, "bag 10002 isolation fail")
    log.info("[b] test_bag_get 10002 isolation >>>> ", p2_all)
end

local function test_bag_save()
    local proxy = get_backpack_proxy(10001)
    --save_one_entry 修改已有条目
    proxy:save_one_entry({player_id = 10001, item_id = 1, slot_id = 1, count = 100, prop = "a_mod"})
    local one = proxy:get_one_entry(10001, 1, 1)
    assert(one and one.count == 100 and one.prop == "a_mod", "bag save_one fail")
    log.info("[b] test_bag_save after save_one >>>> ", one)

    --save_one_entry 不存在则本地创建
    proxy:save_one_entry({player_id = 10001, item_id = 9, slot_id = 9, count = 1, prop = "new"})
    local one9 = proxy:get_one_entry(10001, 9, 9)
    assert(one9 and one9.count == 1, "bag save_one create-new fail")
    log.info("[b] test_bag_save save_one create-new >>>> ", one9)

    --save_entry 批量
    proxy:save_entry({
        {player_id = 10001, item_id = 2, slot_id = 1, count = 300, prop = "c_mod"},
        {player_id = 10001, item_id = 1, slot_id = 2, count = 200, prop = "b_mod"},
    })
    local c = proxy:get_one_entry(10001, 2, 1)
    local b = proxy:get_one_entry(10001, 1, 2)
    assert(c and c.count == 300 and b and b.count == 200, "bag save_entry fail")
    log.info("[b] test_bag_save after save_entry >>>> ", c, b)

    --flush落库
    proxy:flush_now()
    skynet.sleep(300)
end

local function test_bag_delete()
    local proxy = get_backpack_proxy(10001)
    --删除完整主键一条
    proxy:delete_entry(10001, 1, 2)
    local b = proxy:get_one_entry(10001, 1, 2)
    assert(b == nil, "bag delete_one fail")
    log.info("[b] test_bag_delete delete_one done")

    --删除最左前缀一批(item=9)
    proxy:delete_entry(10001, 9)
    local list9 = proxy:get_entry(10001, 9)
    assert(#list9 == 0, "bag delete_prefix fail")
    log.info("[b] test_bag_delete delete_prefix done")

    --剩余应为 item(1,1) item(2,1)
    local left = proxy:get_entry(10001)
    assert(#left == 2, "bag delete left count fail, got " .. #left)
    log.info("[b] test_bag_delete left >>>> ", left)

    --flush落库
    proxy:flush_now()
    skynet.sleep(300)
end

--==================== 跨服务一致性（flush后与orm_table_client对照） ====================

local function test_player_consistency()
    local proxy1 = get_player_proxy(10001)
    local proxy2 = get_player_proxy(10002)
    proxy1:flush_now()
    proxy2:flush_now()
    skynet.sleep(300)

    local proxy1_all = proxy1:get_all_entry()
    local proxy2_all = proxy2:get_all_entry()
    local client1 = orm_table_client:instance("player"):get_one_entry(10001)
    local client2 = orm_table_client:instance("player"):get_one_entry(10002)
    log.info("[c] player proxy1_all >>>> ", proxy1_all)
    log.info("[c] player proxy2_all >>>> ", proxy2_all)
    log.info("[c] player client1 >>>> ", client1)
    log.info("[c] player client2 >>>> ", client2)

    --10001：create final 后一致；10002：已被 delete，两边都应为空
    assert(#proxy1_all == 1, "player 10001 count mismatch")
    assert(#proxy2_all == 0, "player 10002 proxy should be empty after delete")
    assert(client1 and not client2, "player client state mismatch")
    assert(proxy1_all[1].player_id == client1.player_id
        and proxy1_all[1].nickname == client1.nickname
        and proxy1_all[1].status == client1.status, "player 10001 mismatch")
end

local function test_bag_consistency()
    local proxy = get_backpack_proxy(10001)
    proxy:flush_now()
    skynet.sleep(300)

    local proxy_all = proxy:get_all_entry()
    local client_all = orm_table_client:instance("backpack"):get_entry(10001)
    log.info("[c] bag proxy_all >>>> ", proxy_all)
    log.info("[c] bag client_all >>>> ", client_all)
    assert(#proxy_all == #client_all, "bag count mismatch")
    if #proxy_all == #client_all then
        for i = 1, #proxy_all do
            local p = proxy_all[i]
            assert(p.player_id == client_all[i].player_id, "bag player_id mismatch")
            assert(p.item_id == client_all[i].item_id, "bag item_id mismatch")
            assert(p.slot_id == client_all[i].slot_id, "bag slot_id mismatch")
            assert(p.count == client_all[i].count, "bag count mismatch")
            assert(p.prop == client_all[i].prop, "bag prop mismatch")
        end
    end
end

--==================== 主函数 ====================

local function test_all()
    log.info("========== t_player 单主键测试 ==========")
    test_player_create()
    test_player_get()
    test_player_save()
    test_player_delete()
    test_player_delete_all()
    test_player_consistency()

    log.info("========== t_backpack 多主键嵌套测试 ==========")
    test_bag_create()
    test_bag_get()
    test_bag_save()
    test_bag_delete()
    test_bag_consistency()

    log.info("========== orm_table_proxy 全部测试通过 ==========")
end

function CMD.start()
    skynet.fork(test_all)
    return true
end

function CMD.exit()
    return true
end

return CMD
