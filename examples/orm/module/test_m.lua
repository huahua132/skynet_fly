local log = require "skynet-fly.log"
local skynet = require "skynet"
local orm_table_client = require "skynet-fly.client.orm_table_client"

local CMD = {}

local function test()
    orm_table_client:instance("player"):delete_all_entry()
    orm_table_client:instance("player"):not_exist_create({player_id = 10001})

    local client = orm_table_client:new("player")
    local entry_data = client:get(10001)
    log.info("get:",entry_data)

    --批量创建数据
    local entry_data_list = {
        {player_id = 10001},
        {player_id = 10002},
        {player_id = 10003},
        {player_id = 10003},
    }

    --主键冲突，创建失败
    local res_list = client:create_entry(entry_data_list)
    log.info("res_list:", res_list)

    local entry_data_list = {
        {player_id = 10002},
        {player_id = 10003},
    }
    --没有冲突创建成功
    local res_list = client:create_entry(entry_data_list)
    log.info("res_list:", res_list)

    --创建单个冲突
    local _,ret = pcall(client.create_one_entry, client, {player_id = 10001})
    log.info("create_one_entry 1>>> ",ret)

    --创建单个成功
    local ret = client:create_one_entry({player_id = 10005})
    log.info("create_one_entry 1>>> ",ret)
    
    --查询多条数据存在
    local ret_list = client:get_entry(10001)
    log.info("get_entry>>>>>1 ", ret_list)
    --查询多条数据不存在
    local ret_list = client:get_entry(100000000)
    log.info("get_entry>>>>>2 ", ret_list)

    --查询一条数据存在
    local ret = client:get_one_entry(10002)
    log.info("get_one_entry1 >>>> ", ret)

    --查询一条数据不存在
    log.info("get_one_entry2 >>>> ", ret)

    --批量更改保存数据
    local entry_data_list = {
        {player_id = 10001, nickname = 200000, sex = 1},
        {player_id = 10002, nickname = 500000, sex = 1},
    }

    local res = client:change_save_entry(entry_data_list)
    log.info("change_save_entry >>> ", res)

    --变更一条数据
    local ret = client:change_save_one_entry({player_id = 10003, nickname = 200000})
    log.info("change_one_entry1 >>> ", ret)
    --变更一条数据不存在
    local ret = client:change_save_one_entry({player_id = 1000003, nickname = 200000})
    log.info("change_one_entry2 >>> ", ret)

    --查询所有数据
    local res_list = client:get_all_entry()
    log.info("get_all_entry >>>> :", res_list)

    --删除一条数据
    local ret = client:delete_entry(10005)
    log.info("delete_entry >>>> :", ret)

    --查询所有数据
    local res_list = client:get_all_entry()
    log.info("get_all_entry >>>> :", res_list)

    -- IN 查询
    local res_list = client:get_entry_by_in({10001, 10002, 10005})
    log.info("get_entry_by_in >>> :", res_list)

    -- 分页查询
    local limit = 2
    local sort = 1   --1升序 -1降序
    local cursor, res_list, count = client:get_entry_by_limit(nil, limit, sort)
    log.info("get_entry_by_limit1 >>> :", cursor, res_list, count)

    cursor, res_list, count = client:get_entry_by_limit(cursor, limit, sort)
    log.info("get_entry_by_limit2 >>> :", cursor, res_list, count)

    --范围删除
    local all_data = client:get_all_entry()
    log.info("all_data >>> ", all_data)

    local ret = client:delete_entry_by_range(10002)
    local all_data = client:get_all_entry()
    log.info("all_data >>> ", ret, all_data)

    --in删除
    local ret = client:delete_entry_by_in({10001})
    local all_data = client:get_all_entry()
    log.info("all_data >>> ", ret, all_data)

    --测试批量删除
    local entry_data_list = {
        {player_id = 10005},
        {player_id = 10006},
        {player_id = 10007},
        {player_id = 10008},
    }
    client:create_entry(entry_data_list)
    client:batch_delete_entry({{10005},{10006},{10007}})
    local all_data = client:get_all_entry()
    log.info("测试批量删除 all_data >>> ", ret, all_data)
end

--切换测试
local function switch_test()
    local client = orm_table_client:new("player")
    while true do
        skynet.sleep(300)
        local entry_data = client:switch_test()
        log.info("switch_test:",entry_data)
    end
end

function CMD.start()
    skynet.fork(test)
    skynet.fork(switch_test)
    return true
end

function CMD.exit()
    return true
end

return CMD