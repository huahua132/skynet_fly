local skynet = require "skynet"
local ormtable = require "ormtable"
local ormadapter_mysql = require "ormadapter_mysql"
local math_util = require "math_util"
local string_util = require "string_util"
local table_util = require "table_util"
local mysqlf = require "mysqlf"
local log = require "log"

local assert = assert

local CMD = {}

--测试创建表
local function test_create_table(is_del)
    mysqlf:instance("admin"):query("drop table if exists t_player")
    local adapter = ormadapter_mysql:new("admin")
    local orm_obj = ormtable:new("t_player")
    :int64("player_id")
    :int64("role_id")
    :int8("sex")
    :string32("nickname")
    :string64("email")
    :uint8("sex1")
    :int16("sex2")
    :uint16("sex3")
    :int32("sex4")
    :uint32("sex5")
    :int64("sex6")
    :string128("sex7")
    :string256("sex8")
    :string512("sex9")
    :string1024("sex10")
    :string2048("sex11")
    :string4096("sex12")
    :string8192("sex13")
    :text("sex14")
    :blob("sex15")
    :set_keys("player_id","role_id","sex")
    :builder(adapter)

    local sqlret = mysqlf:instance("admin"):query("DESCRIBE t_player")

    assert(not sqlret.err,sqlret.err)
    assert(sqlret[1].Field == 'player_id' and sqlret[1].Type == 'bigint' and sqlret[1].Key == 'PRI')
    assert(sqlret[2].Field == 'role_id' and sqlret[2].Type == 'bigint' and sqlret[2].Key == 'PRI')
    assert(sqlret[3].Field == 'sex' and sqlret[3].Type == 'tinyint' and sqlret[3].Key == 'PRI')
    assert(sqlret[4].Field == 'nickname' and sqlret[4].Type == 'varchar(32)')
    assert(sqlret[5].Field == 'email' and sqlret[5].Type == 'varchar(64)')
    assert(sqlret[6].Field == 'sex1' and sqlret[6].Type == 'tinyint unsigned')
    assert(sqlret[7].Field == 'sex2' and sqlret[7].Type == 'smallint')
    assert(sqlret[8].Field == 'sex3' and sqlret[8].Type == 'smallint unsigned')
    assert(sqlret[9].Field == 'sex4' and sqlret[9].Type == 'int')
    assert(sqlret[10].Field == 'sex5' and sqlret[10].Type == 'int unsigned')
    assert(sqlret[11].Field == 'sex6' and sqlret[11].Type == 'bigint')
    assert(sqlret[12].Field == 'sex7' and sqlret[12].Type == 'varchar(128)')
    assert(sqlret[13].Field == 'sex8' and sqlret[13].Type == 'varchar(256)')
    assert(sqlret[14].Field == 'sex9' and sqlret[14].Type == 'varchar(512)')
    assert(sqlret[15].Field == 'sex10' and sqlret[15].Type == 'varchar(1024)')
    assert(sqlret[16].Field == 'sex11' and sqlret[16].Type == 'varchar(2048)')
    assert(sqlret[17].Field == 'sex12' and sqlret[17].Type == 'varchar(4096)')
    assert(sqlret[18].Field == 'sex13' and sqlret[18].Type == 'varchar(8192)')
    assert(sqlret[19].Field == 'sex14' and sqlret[19].Type == 'text')
    assert(sqlret[20].Field == 'sex15' and sqlret[20].Type == 'blob')

    if is_del then
        mysqlf:instance("admin"):query("drop table if exists t_player")
    end
end

--测试修改表
local function test_alter_table()
    test_create_table()
    local adapter = ormadapter_mysql:new("admin")
    local orm_obj = ormtable:new("t_player")
    :int64("player_id")
    :int64("role_id")
    :int8("sex")
    :int8("nickname1")
    :set_keys("player_id","role_id","sex")
    :builder(adapter)

    local sqlret = mysqlf:instance("admin"):query("DESCRIBE t_player")

    assert(not sqlret.err,sqlret.err)
    assert(sqlret[1].Field == 'player_id' and sqlret[1].Type == 'bigint' and sqlret[1].Key == 'PRI')
    assert(sqlret[2].Field == 'role_id' and sqlret[2].Type == 'bigint' and sqlret[2].Key == 'PRI')
    assert(sqlret[3].Field == 'sex' and sqlret[3].Type == 'tinyint' and sqlret[3].Key == 'PRI')
    assert(sqlret[4].Field == 'nickname' and sqlret[4].Type == 'varchar(32)')
    assert(sqlret[5].Field == 'email' and sqlret[5].Type == 'varchar(64)')
    assert(sqlret[6].Field == 'sex1' and sqlret[6].Type == 'tinyint unsigned')
    assert(sqlret[7].Field == 'sex2' and sqlret[7].Type == 'smallint')
    assert(sqlret[8].Field == 'sex3' and sqlret[8].Type == 'smallint unsigned')
    assert(sqlret[9].Field == 'sex4' and sqlret[9].Type == 'int')
    assert(sqlret[10].Field == 'sex5' and sqlret[10].Type == 'int unsigned')
    assert(sqlret[11].Field == 'sex6' and sqlret[11].Type == 'bigint')
    assert(sqlret[12].Field == 'sex7' and sqlret[12].Type == 'varchar(128)')
    assert(sqlret[13].Field == 'sex8' and sqlret[13].Type == 'varchar(256)')
    assert(sqlret[14].Field == 'sex9' and sqlret[14].Type == 'varchar(512)')
    assert(sqlret[15].Field == 'sex10' and sqlret[15].Type == 'varchar(1024)')
    assert(sqlret[16].Field == 'sex11' and sqlret[16].Type == 'varchar(2048)')
    assert(sqlret[17].Field == 'sex12' and sqlret[17].Type == 'varchar(4096)')
    assert(sqlret[18].Field == 'sex13' and sqlret[18].Type == 'varchar(8192)')
    assert(sqlret[19].Field == 'sex14' and sqlret[19].Type == 'text')
    assert(sqlret[20].Field == 'sex15' and sqlret[20].Type == 'blob')
    assert(sqlret[21].Field == 'nickname1' and sqlret[21].Type == 'tinyint')
end

--测试新增数据
local function test_create_entry()

end

local function test()
    local adapter = ormadapter_mysql:new("admin")
    local orm_obj = ormtable:new("t_player")
    :int64("player_id")
    :int64("role_id")
    :string256("email")
    :string8192("content")
    :int8("flag1")
    :uint8("flag2")
    :string4096("content1")
    :text("text")
    :blob("content3")
    :uint32("level")
    :string32("teststr")
    :set_keys("player_id","role_id")
    :set_indexs("role_id")
    :set_cache_time(500)
    :builder(adapter)

    -- 插入数据
    orm_obj:create_entry({
        player_id = 10001,
        role_id = 10001,
        email = "168999454@qq.com"
    },{
        player_id = 10001,
        role_id = 10002,
        email = "168999454@qq.com"
    },{
        player_id = 10001,
        role_id = 10003,
        email = "168999454@qq.com"
    },{
        player_id = 10001,
        role_id = 10004,
        email = "168999454@qq.com"
    },{
        player_id = 10001,
        role_id = 10005,
        email = "168999454@qq.com"
    })

    -- 查询数据
    local entrylist = orm_obj:get_entry(10001)
    for k,entry in pairs(entrylist) do
        log.info(k, entry:get_entry_data())
    end

    local entry1 = entrylist[1]
    entry1:set('email',"9586694161")
    orm_obj:save_entry(entry1)
end

function CMD.start()
    skynet.fork(function()
        test_create_table(true)
        test_alter_table()
    end)
    return true
end

function CMD.exit()
    return true
end

return CMD