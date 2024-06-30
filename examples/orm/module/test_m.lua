local log = require "skynet-fly.log"
local skynet = require "skynet"
local orm_table_client = require "skynet-fly.client.orm_table_client"

local CMD = {}

local function test()
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
    local isok,ret = pcall(client.create_one_entry, client, {player_id = 10001})
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
end

function CMD.start()
    skynet.fork(test)
    return true
end

function CMD.exit()
    return true
end

return CMD