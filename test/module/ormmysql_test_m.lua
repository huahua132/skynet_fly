local skynet = require "skynet"
local ormtable = require "skynet-fly.db.orm.ormtable"
local ormadapter_mysql = require "skynet-fly.db.ormadapter.ormadapter_mysql"
local math_util = require "skynet-fly.utils.math_util"
local string_util = require "skynet-fly.utils.string_util"
local table_util = require "skynet-fly.utils.table_util"
local mysqlf = require "skynet-fly.db.mysqlf"
local log = require "skynet-fly.log"

local assert = assert

local CMD = {}

local function delete_table()
    mysqlf:instance("admin"):query("drop table if exists t_player")
end

--测试创建表
local function test_create_table(is_del)
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
    :table("info")
    :set_keys("player_id","role_id","sex")
    :builder(adapter)

    local sqlret = mysqlf:instance("admin"):query("DESCRIBE t_player")
    for _, info in pairs(sqlret) do
        info.Type = info.Type:gsub("(%a*)int%(%d+%)", "%1int")
    end
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
        delete_table()
    end

    return orm_obj
end

--测试修改表
local function test_alter_table()
    test_create_table()
    local adapter = ormadapter_mysql:new("admin")
    local _ = ormtable:new("t_player")
    :int64("player_id")
    :int64("role_id")
    :int8("sex")
    :int8("nickname1")
    :table("info2")
    :set_keys("player_id","role_id","sex")
    :builder(adapter)

    local sqlret = mysqlf:instance("admin"):query("DESCRIBE t_player")
    for _, info in pairs(sqlret) do
        info.Type = info.Type:gsub("(%a*)int%(%d+%)", "%1int")
    end
    
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
    assert(sqlret[21].Field == 'info' and sqlret[21].Type == 'blob')
    assert(sqlret[22].Field == 'nickname1' and sqlret[22].Type == 'tinyint')
    assert(sqlret[23].Field == 'info2' and sqlret[23].Type == 'blob')
    
    delete_table()
end

--测试新增数据
local function test_create_entry()
    local orm_obj = test_create_table()

    --新建单条数据
    local new_data = {player_id = 10001,role_id = 1, sex = 1}
    local entry = orm_obj:create_one_entry(new_data)
    assert(entry)
    assert(entry:get('player_id') == 10001)
    assert(entry:get('role_id') == 1)
    assert(entry:get('sex') == 1)
    assert(entry:get('nickname') == "") --没有设置的string 会默认给个空 string
    assert(entry:get('sex1') == 0)      --没有设置的number 会默认给个 0

    --主键冲突
    local new_data = {player_id = 10001,role_id = 1, sex = 1}
    local isok = pcall(orm_obj.create_one_entry,orm_obj,new_data)
    assert(not isok)     

    --缺少主键数据
    local new_data = {player_id = 10001,role_id = 2}
    local isok = pcall(orm_obj.create_one_entry,orm_obj,new_data)
    assert(not isok) --会崩溃报错

    --新建多条数据
    local new_data_list = {
        {player_id = 10002,role_id = 1, sex = 1},
        {player_id = 10002,role_id = 2, sex = 1},
        {player_id = 10002,role_id = 3, sex = 1}
    }

    local res = orm_obj:create_entry(new_data_list)
    assert(#res == 3)
    for i,v in pairs(res) do
        assert(v)
    end

    -- 新增数据值范围要合理

    local new_data = {player_id = 100055,role_id = 1, sex = -128}
    local isok = pcall(orm_obj.create_one_entry,orm_obj,new_data)
    assert(isok)

    local new_data = {player_id = 10005,role_id = 1, sex = -129}
    local isok = pcall(orm_obj.create_one_entry,orm_obj,new_data)
    assert(not isok)

    local new_data = {player_id = 10006,role_id = 1, sex = 128}
    local isok = pcall(orm_obj.create_one_entry,orm_obj,new_data)
    assert(not isok)

    local new_data = {player_id = 100066,role_id = 1, sex = 127}
    local isok = pcall(orm_obj.create_one_entry,orm_obj,new_data)
    assert(isok)
    
    local new_data = {player_id = 10007,role_id = 1, sex = 1, sex1 = 256}
    local isok = pcall(orm_obj.create_one_entry,orm_obj,new_data)
    assert(not isok)

    local new_data = {player_id = 100077,role_id = 1, sex = 1, sex1 = 255}
    local isok = pcall(orm_obj.create_one_entry,orm_obj,new_data)
    assert(isok)

    local new_data = {player_id = 10008,role_id = 1, sex = 1, sex1 = -1}
    local isok = pcall(orm_obj.create_one_entry,orm_obj,new_data)
    assert(not isok)

    local new_data = {player_id = 100088,role_id = 1, sex = 1, sex1 = 0}
    local isok = pcall(orm_obj.create_one_entry,orm_obj,new_data)
    assert(isok)

    local new_data = {player_id = 11007,role_id = 1, sex = 1, sex2 = 32768}
    local isok = pcall(orm_obj.create_one_entry,orm_obj,new_data)
    assert(not isok)

    local new_data = {player_id = 110077,role_id = 1, sex = 1, sex2 = 32767}
    local isok = pcall(orm_obj.create_one_entry,orm_obj,new_data)
    assert(isok)

    local new_data = {player_id = 11008,role_id = 1, sex = 1, sex2 = -32769}
    local isok = pcall(orm_obj.create_one_entry,orm_obj,new_data)
    assert(not isok)

    local new_data = {player_id = 110088,role_id = 1, sex = 1, sex2 = -32768}
    local isok = pcall(orm_obj.create_one_entry,orm_obj,new_data)
    assert(isok)

    local new_data = {player_id = 12007,role_id = 1, sex = 1, sex3 = 65536}
    local isok = pcall(orm_obj.create_one_entry,orm_obj,new_data)
    assert(not isok)

    local new_data = {player_id = 120077,role_id = 1, sex = 1, sex3 = 65535}
    local isok = pcall(orm_obj.create_one_entry,orm_obj,new_data)
    assert(isok)

    local new_data = {player_id = 12008,role_id = 1, sex = 1, sex3 = -1}
    local isok = pcall(orm_obj.create_one_entry,orm_obj,new_data)
    assert(not isok)

    local new_data = {player_id = 120088,role_id = 1, sex = 1, sex3 = 0}
    local isok = pcall(orm_obj.create_one_entry,orm_obj,new_data)
    assert(isok)

    local new_data = {player_id = 13007,role_id = 1, sex = 1, sex4 = 2147483648}
    local isok = pcall(orm_obj.create_one_entry,orm_obj,new_data)
    assert(not isok)

    local new_data = {player_id = 130077,role_id = 1, sex = 1, sex4 = 2147483647}
    local isok = pcall(orm_obj.create_one_entry,orm_obj,new_data)
    assert(isok)

    local new_data = {player_id = 13008,role_id = 1, sex = 1, sex4 = -2147483649}
    local isok = pcall(orm_obj.create_one_entry,orm_obj,new_data)
    assert(not isok)

    local new_data = {player_id = 130088,role_id = 1, sex = 1, sex4 = -2147483648}
    local isok = pcall(orm_obj.create_one_entry,orm_obj,new_data)
    assert(isok)

    local new_data = {player_id = 14007,role_id = 1, sex = 1, sex5 = 4294967296}
    local isok = pcall(orm_obj.create_one_entry,orm_obj,new_data)
    assert(not isok)

    local new_data = {player_id = 140077,role_id = 1, sex = 1, sex5 = 4294967295}
    local isok = pcall(orm_obj.create_one_entry,orm_obj,new_data)
    assert(isok)

    local new_data = {player_id = 14008,role_id = 1, sex = 1, sex5 = -1}
    local isok = pcall(orm_obj.create_one_entry,orm_obj,new_data)
    assert(not isok)

    local new_data = {player_id = 140088,role_id = 1, sex = 1, sex5 = 0}
    local isok = pcall(orm_obj.create_one_entry,orm_obj,new_data)
    assert(isok)

    local new_data = {player_id = 15007,role_id = 1, sex = 1, sex6 = 9223372036854775808}
    local isok = pcall(orm_obj.create_one_entry,orm_obj,new_data)
    assert(not isok)

    local new_data = {player_id = 150077,role_id = 1, sex = 1, sex6 = 9223372036854775807}
    local isok = pcall(orm_obj.create_one_entry,orm_obj,new_data)
    assert(isok)

    local new_data = {player_id = 15008,role_id = 1, sex = 1, sex6 = -9223372036854775809}
    local isok,err = pcall(orm_obj.create_one_entry,orm_obj,new_data)
    assert(isok and type(err) == 'table')  --插入成功 数据会被修正为-9223372036854775808  

    local new_data = {player_id = 150088,role_id = 1, sex = 1, sex6 = -9223372036854775808}
    local isok,err = pcall(orm_obj.create_one_entry,orm_obj,new_data)
    assert(isok and type(err) == 'table') --插入成功 

    local test_str = ""
    for i = 1,33 do
        test_str = test_str .. 'i'
    end
    local new_data = {player_id = 10009,role_id = 1, sex = 1, nickname = test_str}
    local isok = pcall(orm_obj.create_one_entry,orm_obj,new_data)
    assert(not isok)

    local test_str = ""
    for i = 1,32 do
        test_str = test_str .. 'i'
    end
    local new_data = {player_id = 100099,role_id = 1, sex = 1, nickname = test_str}
    local isok = pcall(orm_obj.create_one_entry,orm_obj,new_data)
    assert(isok)

    local test_str = ""
    for i = 1,65 do
        test_str = test_str .. 'i'
    end
    local new_data = {player_id = 10010,role_id = 1, sex = 1, email = test_str}
    local isok = pcall(orm_obj.create_one_entry,orm_obj,new_data)
    assert(not isok)

    local test_str = ""
    for i = 1,64 do
        test_str = test_str .. 'i'
    end
    local new_data = {player_id = 100100,role_id = 1, sex = 1, email = test_str}
    local isok = pcall(orm_obj.create_one_entry,orm_obj,new_data)
    assert(isok)

    local test_str = ""
    for i = 1,129 do
        test_str = test_str .. 'i'
    end
    local new_data = {player_id = 10011,role_id = 1, sex = 1, sex7 = test_str}
    local isok = pcall(orm_obj.create_one_entry,orm_obj,new_data)
    assert(not isok)

    local test_str = ""
    for i = 1,128 do
        test_str = test_str .. 'i'
    end
    local new_data = {player_id = 100111,role_id = 1, sex = 1, sex7 = test_str}
    local isok = pcall(orm_obj.create_one_entry,orm_obj,new_data)
    assert(isok)

    local test_str = ""
    for i = 1,257 do
        test_str = test_str .. 'i'
    end
    local new_data = {player_id = 10012,role_id = 1, sex = 1, sex8 = test_str}
    local isok = pcall(orm_obj.create_one_entry,orm_obj,new_data)
    assert(not isok)

    local test_str = ""
    for i = 1,256 do
        test_str = test_str .. 'i'
    end
    local new_data = {player_id = 100122,role_id = 1, sex = 1, sex8 = test_str}
    local isok = pcall(orm_obj.create_one_entry,orm_obj,new_data)
    assert(isok)

    local test_str = ""
    for i = 1,513 do
        test_str = test_str .. 'i'
    end
    local new_data = {player_id = 10013,role_id = 1, sex = 1, sex9 = test_str}
    local isok = pcall(orm_obj.create_one_entry,orm_obj,new_data)
    assert(not isok)

    local test_str = ""
    for i = 1,512 do
        test_str = test_str .. 'i'
    end
    local new_data = {player_id = 100133,role_id = 1, sex = 1, sex9 = test_str}
    local isok = pcall(orm_obj.create_one_entry,orm_obj,new_data)
    assert(isok)

    local test_str = ""
    for i = 1,1025 do
        test_str = test_str .. 'i'
    end
    local new_data = {player_id = 10014,role_id = 1, sex = 1, sex10 = test_str}
    local isok = pcall(orm_obj.create_one_entry,orm_obj,new_data)
    assert(not isok)

    local test_str = ""
    for i = 1,1024 do
        test_str = test_str .. 'i'
    end
    local new_data = {player_id = 100144,role_id = 1, sex = 1, sex10 = test_str}
    local isok = pcall(orm_obj.create_one_entry,orm_obj,new_data)
    assert(isok)

    local test_str = ""
    for i = 1,2049 do
        test_str = test_str .. 'i'
    end
    local new_data = {player_id = 10015,role_id = 1, sex = 1, sex11 = test_str}
    local isok = pcall(orm_obj.create_one_entry,orm_obj,new_data)
    assert(not isok)

    
    local test_str = ""
    for i = 1,2048 do
        test_str = test_str .. 'i'
    end
    local new_data = {player_id = 100155,role_id = 1, sex = 1, sex11 = test_str}
    local isok = pcall(orm_obj.create_one_entry,orm_obj,new_data)
    assert(isok)

    local test_str = ""
    for i = 1,4097 do
        test_str = test_str .. 'i'
    end
    local new_data = {player_id = 10016,role_id = 1, sex = 1, sex12 = test_str}
    local isok = pcall(orm_obj.create_one_entry,orm_obj,new_data)
    assert(not isok)

    local test_str = ""
    for i = 1,4096 do
        test_str = test_str .. 'i'
    end
    local new_data = {player_id = 100166,role_id = 1, sex = 1, sex12 = test_str}
    local isok = pcall(orm_obj.create_one_entry,orm_obj,new_data)
    assert(isok)

    local test_str = ""
    for i = 1,8193 do
        test_str = test_str .. 'i'
    end
    local new_data = {player_id = 10017,role_id = 1, sex = 1, sex13 = test_str}
    local isok = pcall(orm_obj.create_one_entry,orm_obj,new_data)
    assert(not isok)

    local test_str = ""
    for i = 1,8192 do
        test_str = test_str .. 'i'
    end
    local new_data = {player_id = 100177,role_id = 1, sex = 1, sex13 = test_str}
    local isok = pcall(orm_obj.create_one_entry,orm_obj,new_data)
    assert(isok)

    delete_table()
end

--测试查询数据
local function test_select_entry()
    local orm_obj = test_create_table()
    --新建多条数据
    local new_data_list = {
        {player_id = 10002,role_id = 1, sex = 1},
        {player_id = 10002,role_id = 2, sex = 1},
        {player_id = 10002,role_id = 2, sex = 2},
        {player_id = 10002,role_id = 3, sex = 2},
        {player_id = 10003,role_id = 1, sex = 1},
        {player_id = 10003,role_id = 2, sex = 1},
        {player_id = 10003,role_id = 2, sex = 2},
        {player_id = 10003,role_id = 3, sex = 2},
    }

    local res = orm_obj:create_entry(new_data_list)
    assert(#res == 8)
    for i,v in pairs(res) do
        assert(v)
    end

    --通过player_id查询
    local entry_list = orm_obj:get_entry(10002)
    assert(#entry_list == 4) --有四条数据
    for i,entry in ipairs(entry_list) do
        assert(entry:get('player_id') == new_data_list[i].player_id)
        assert(entry:get('role_id') == new_data_list[i].role_id)
        assert(entry:get('sex') == new_data_list[i].sex)
    end

    --通过player_id 加 role_id 查询
    local entry_list = orm_obj:get_entry(10002,2)
    assert(#entry_list == 2) --有2条数据

    --通过player_id 加 role_id 加 sex 查询
    local entry_list = orm_obj:get_entry(10002,2,1)
    assert(#entry_list == 1) --有1条数据

    --查询不存在的数据
    local entry_list = orm_obj:get_entry(10004)
    assert(#entry_list == 0)
    local entry_list = orm_obj:get_entry(10004,1)
    assert(#entry_list == 0)
    local entry_list = orm_obj:get_entry(10004,1,1)
    assert(#entry_list == 0)

    --查询版本一用，版本二不用，版本三再用，字段取出不能为nil
    
    --版本二只有3个主键
    local adapter = ormadapter_mysql:new("admin")
    local orm_obj = ormtable:new("t_player")
    :int64("player_id")
    :int64("role_id")
    :int8("sex")
    :set_keys("player_id","role_id","sex")
    :builder(adapter)

    local res = orm_obj:create_one_entry({player_id = 10004,role_id = 1, sex = 1})
    assert(res)

    --版本三又用回来
    orm_obj = test_create_table()
    local entry_list = orm_obj:get_entry(10004)
    local entry = assert(entry_list[1])

    assert(entry:get('nickname') == "")
    assert(entry:get('sex4') == 0)

    delete_table()
end

--测试变更保存数据
local function test_save_entry()
    delete_table()
    local orm_obj = test_create_table()
    local entry = orm_obj:create_one_entry({player_id = 10004,role_id = 1, sex = 1, nickname = "ddasda", sex1 = 222})
    
    --主键值不能修改
    local isok = pcall(entry.set,entry,'player_id',1000)
    assert(not isok)
    local isok = pcall(entry.set,entry,'role_id',1000)
    assert(not isok)
    local isok = pcall(entry.set,entry,'sex',2)
    assert(not isok)

    --修改数据范围要合理
    local isok = pcall(entry.set,entry,'sex1',256)
    assert(not isok)

    local isok = pcall(entry.set,entry,'sex1',-1)
    assert(not isok)

    local isok = pcall(entry.set,entry,'nickname',"1111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111")
    assert(not isok)

    --修改单条数据
    entry:set('nickname',"abcde")
    entry:set('sex1',111)

    local res = orm_obj:save_one_entry(entry)
    assert(res)

    local entry_list = orm_obj:get_entry(10004)
    local entry = assert(entry_list[1])
    assert(entry:get('nickname') == "abcde")
    assert(entry:get('sex1') == 111)

    --修改多条数据
    local res = orm_obj:create_entry({
        {player_id = 11001,role_id = 1, sex = 1, nickname = "abcd", sex1 = 1},
        {player_id = 11002,role_id = 1, sex = 1, nickname = "efgh", sex1 = 2}
    })
    local entry1 = assert(res[1])
    entry1:set('nickname',"abcde")
    entry1:set('sex1',111)
    local entry2 = assert(res[2])
    entry2:set('nickname',"efghg")
    entry2:set('sex1',222)

    local res = orm_obj:save_entry({entry1, entry2})
    assert(res[1])
    assert(res[2])

    local res = orm_obj:get_entry(11001)
    entry1 = assert(res[1])

    local res = orm_obj:get_entry(11002)
    entry2 = assert(res[1])

    assert(entry1:get('nickname') == "abcde")
    assert(entry1:get('sex1') == 111)

    assert(entry2:get('nickname') == "efghg")
    assert(entry2:get('sex1') == 222)

    delete_table()
end

--测试删除数据
local function test_delete_entry()
    local orm_obj = test_create_table()
    local _ = orm_obj:create_entry({
        {player_id = 10004,role_id = 1, sex = 1, nickname = "ddasda", sex1 = 222},
        {player_id = 10004,role_id = 1, sex = 2, nickname = "ddasda", sex1 = 223},
        {player_id = 10004,role_id = 1, sex = 3, nickname = "ddasda", sex1 = 224},
        {player_id = 10004,role_id = 2, sex = 1, nickname = "ddasda", sex1 = 222},
        {player_id = 10004,role_id = 2, sex = 2, nickname = "ddasda", sex1 = 223},
        {player_id = 10004,role_id = 2, sex = 3, nickname = "ddasda", sex1 = 224},
        {player_id = 10004,role_id = 3, sex = 3, nickname = "ddasda", sex1 = 224},
        {player_id = 10005,role_id = 2, sex = 1, nickname = "ddasda", sex1 = 224}
    })

    --删除一条数据 （使用三个关联唯一key）
    local res = orm_obj:delete_entry(10004, 1, 1)
    assert(res)

    local entry_list = orm_obj:get_entry(10004, 1, 1)
    assert(not next(entry_list))

    --应该还有两条数据
    local entry_list = orm_obj:get_entry(10004, 1)
    assert(#entry_list == 2)

    --删除数据 （使用 2个 关联 key）
    local res = orm_obj:delete_entry(10004, 1)
    assert(res)

    --应该还有四条数据
    local entry_list = orm_obj:get_entry(10004)
    assert(#entry_list == 4)

    -- 删除数据 （使用 1个 关联 key）
    local res = orm_obj:delete_entry(10004)
    assert(res)

    --应该没有条数据
    local entry_list = orm_obj:get_entry(10004)
    assert(#entry_list == 0)

    --10005应该还存在
    local entry_list = orm_obj:get_entry(10005)
    assert(#entry_list == 1)

    delete_table()
end

--测试本地缓存
local function test_cache_entry()
    local adapter = ormadapter_mysql:new("admin")
    local orm_obj = ormtable:new("t_player")
    :int64("player_id")
    :int64("role_id")
    :int8("sex")
    :string32("nickname")
    :string64("email")
    :uint8("sex1")
    :set_keys("player_id","role_id","sex")
    :set_cache(500, 100) --缓存5秒
    :builder(adapter)

    --创建entry 建立缓存 
    local entry = orm_obj:create_one_entry({player_id = 10001, role_id = 1, sex = 1})

    local get_entry_list = orm_obj:get_entry(10001)
    local get_entry = assert(get_entry_list[1])
    assert(entry == get_entry) --是同一个表
    skynet.sleep(600)

    --缓存过期
    local gg_entry_list,is_cache = orm_obj:get_entry(10001)
    local gg_entry = assert(gg_entry_list[1])
    assert(not is_cache)

    assert(entry ~= gg_entry) --不是同一个表

    --查询建立了缓存，再次查询应命中缓存
    local reget_entry_list,is_cache = orm_obj:get_entry(10001)
    local reget_entry = assert(reget_entry_list[1])

    assert(gg_entry == reget_entry)
    assert(is_cache)

    skynet.sleep(300)
    --查询延迟缓存时间 重置为5秒
    local _ = orm_obj:get_entry(10001)
    skynet.sleep(300)
    local rrr_list,is_cache = orm_obj:get_entry(10001)
    local rrr_entry = assert(rrr_list[1])
    assert(rrr_entry == reget_entry)
    assert(is_cache)

    -- 多条数据命中缓存
    local entry_list = orm_obj:create_entry({
        {player_id = 10002, role_id = 1, sex = 1},
        {player_id = 10002, role_id = 2, sex = 1},
        {player_id = 10002, role_id = 3, sex = 1},
        {player_id = 10002, role_id = 1, sex = 2},
        {player_id = 10002, role_id = 2, sex = 2},
        {player_id = 10002, role_id = 3, sex = 2},
        {player_id = 10003, role_id = 1, sex = 1},
        {player_id = 10003, role_id = 2, sex = 1},
        {player_id = 10003, role_id = 3, sex = 1},
        {player_id = 10003, role_id = 1, sex = 2},
        {player_id = 10003, role_id = 2, sex = 2},
        {player_id = 10003, role_id = 3, sex = 2}
    })

    --两个关联key
    local get_entry_list = orm_obj:get_entry(10002, 1)
    assert(entry_list[1] == get_entry_list[1])
    assert(entry_list[4] == get_entry_list[2])

    --1个关联key
    local gg_entry_list = orm_obj:get_entry(10002)
    assert(entry_list[1] == gg_entry_list[1])
    -- 多条数据中 有数据缓存过期查询应重拉数据
    skynet.sleep(600)

    --两个关联key
    local ggg_entry_list = orm_obj:get_entry(10002, 1)

    skynet.sleep(300)
    orm_obj:get_entry(10002, 1, 1) --保活一条数据
    skynet.sleep(300) --3秒后过期1条数据

    local gggg_entry_list,is_cache = orm_obj:get_entry(10002, 1) --拉取新的
    --1因为缓存还在 2缓存不在
    assert(ggg_entry_list[1] == gggg_entry_list[1])
    assert(ggg_entry_list[2] ~= gggg_entry_list[2])
    assert(not is_cache)

    skynet.sleep(600)
    --1个关联key
    local ggg_entry_list = orm_obj:get_entry(10002)
    skynet.sleep(300)
    orm_obj:get_entry(10002, 1, 1) --保活一条数据

    skynet.sleep(300) --3秒后过期5条数据
    local gggg_entry_list,is_cache = orm_obj:get_entry(10002) --拉取新的
    assert(ggg_entry_list[1] == gggg_entry_list[1])
    assert(ggg_entry_list[2] ~= gggg_entry_list[2])
    assert(not is_cache)

    --删除数据后拿取关联多条，应命中缓存
    local _ = orm_obj:get_entry(10003)
    orm_obj:delete_entry(10003, 3, 2)
    local _,is_cache = orm_obj:get_entry(10003)
    assert(is_cache)
    
    delete_table()
end

--测试定期自动保存数据
local function test_inval_save()
    delete_table()
    local adapter = ormadapter_mysql:new("admin")
    local orm_obj = ormtable:new("t_player")
    :int64("player_id")
    :int64("role_id")
    :int8("sex")
    :string32("nickname")
    :string64("email")
    :uint8("sex1")
    :set_keys("player_id","role_id","sex")
    :set_cache(500,100)   --1保存一次
    :builder(adapter)

    -- 自动保存数据
    local entry_list = orm_obj:create_entry({
        {player_id = 10002, role_id = 1, sex = 1},
        {player_id = 10002, role_id = 2, sex = 1},
        {player_id = 10002, role_id = 3, sex = 1},
        {player_id = 10002, role_id = 1, sex = 2},
        {player_id = 10002, role_id = 2, sex = 2},
        {player_id = 10002, role_id = 3, sex = 2},
        {player_id = 10003, role_id = 1, sex = 1},
        {player_id = 10003, role_id = 2, sex = 1},
        {player_id = 10003, role_id = 3, sex = 1},
        {player_id = 10003, role_id = 1, sex = 2},
        {player_id = 10003, role_id = 2, sex = 2},
        {player_id = 10003, role_id = 3, sex = 2}
    })

    for i,entry in ipairs(entry_list) do
        entry:set("email", "emailssss")
    end

    skynet.sleep(1000)

    local entry_list = orm_obj:get_entry(10002)
    for i,entry in ipairs(entry_list) do
        local email = entry:get("email")
        assert(email == "emailssss", email)
    end

    delete_table()
end

--测试定期保存数据，数据库挂了之后再启动，数据应该还能落地
local function test_sql_over()
    delete_table()
    local adapter = ormadapter_mysql:new("admin")
    local orm_obj = ormtable:new("t_player")
    :int64("player_id")
    :int64("role_id")
    :int8("sex")
    :string32("nickname")
    :string64("email")
    :uint8("sex1")
    :set_keys("player_id","role_id","sex")
    :set_cache(500,500)   --5秒保存一次
    :builder(adapter)

    -- 自动保存数据
    local entry_list = orm_obj:create_entry({
        {player_id = 10002, role_id = 1, sex = 1},
        {player_id = 10002, role_id = 2, sex = 1},
        {player_id = 10002, role_id = 3, sex = 1},
        {player_id = 10002, role_id = 1, sex = 2},
        {player_id = 10002, role_id = 2, sex = 2},
        {player_id = 10002, role_id = 3, sex = 2},
        {player_id = 10003, role_id = 1, sex = 1},
        {player_id = 10003, role_id = 2, sex = 1},
        {player_id = 10003, role_id = 3, sex = 1},
        {player_id = 10003, role_id = 1, sex = 2},
        {player_id = 10003, role_id = 2, sex = 2},
        {player_id = 10003, role_id = 3, sex = 2}
    })

    for i,entry in ipairs(entry_list) do
        entry:set("email", "emailssss")
    end

    --杀掉数据库
    os.execute("pkill mysql")
    log.info("杀掉数据库》》》》》》》》》》》》》")

    skynet.sleep(6000)

    os.execute("systemctl start mysql")
    log.info("启动数据库》》》》》》》》》》》》》")

    --等待缓存过期
    log.info("等待缓存过期》》》》》》》》》》》》》")
    skynet.sleep(1000)
    log.info("缓存过期》》》》》》》》》》》》》")

    local entry_list = orm_obj:get_entry(10002)
    for i,entry in ipairs(entry_list) do
        local email = entry:get("email")
        assert(email == "emailssss")
    end
    log.info("保存成功》》》》》》》》》》》》》")
    delete_table()
end

--测试对象没用后的定时器清除
local function test_over_clear_time()
    delete_table()
    local adapter = ormadapter_mysql:new("admin")
    local orm_obj = ormtable:new("t_player")
    :int64("player_id")
    :int64("role_id")
    :int8("sex")
    :string32("nickname")
    :string64("email")
    :uint8("sex1")
    :set_keys("player_id","role_id","sex")
    :set_cache(500,500)   --5秒保存一次
    :builder(adapter)

    local time_obj = orm_obj._time_obj
    orm_obj = nil
 
    collectgarbage("collect")
    collectgarbage("collect")
    assert(time_obj.is_cancel == true)

    delete_table()
end

--测试缓存不过期
local function test_permanent()
    delete_table()
    local adapter = ormadapter_mysql:new("admin")
    local orm_obj = ormtable:new("t_player")
    :int64("player_id")
    :int64("role_id")
    :int8("sex")
    :string32("nickname")
    :string64("email")
    :uint8("sex1")
    :set_keys("player_id","role_id","sex")
    :set_cache(0,500)   --5秒保存一次
    :builder(adapter)

    local entry = orm_obj:create_one_entry({
        player_id = 10001,
        role_id = 1,
        sex = 1
    })

    skynet.sleep(1)

    local get_entry_List,is_cache = orm_obj:get_entry(10001)
    assert(is_cache)
    local g_entry = get_entry_List[1]

    assert(entry == g_entry)

    delete_table()
end

--测试查询所有数据
local function test_get_all()
    delete_table()
    local adapter = ormadapter_mysql:new("admin")
    local orm_obj = ormtable:new("t_player")
    :int64("player_id")
    :int64("role_id")
    :int8("sex")
    :string32("nickname")
    :string64("email")
    :uint8("sex1")
    :set_keys("player_id","role_id","sex")
    :set_cache(500,500)   --5秒保存一次
    :builder(adapter)

    local entry_list = orm_obj:create_entry({
        {player_id = 10002, role_id = 1, sex = 1},
        {player_id = 10002, role_id = 2, sex = 1},
        {player_id = 10002, role_id = 3, sex = 1},
        {player_id = 10002, role_id = 1, sex = 2},
        {player_id = 10002, role_id = 2, sex = 2},
        {player_id = 10002, role_id = 3, sex = 2},
        {player_id = 10003, role_id = 1, sex = 1},
        {player_id = 10003, role_id = 2, sex = 1},
        {player_id = 10003, role_id = 3, sex = 1},
        {player_id = 10003, role_id = 1, sex = 2},
        {player_id = 10003, role_id = 2, sex = 2},
        {player_id = 10003, role_id = 3, sex = 2}
    })

    local get_entry_list,is_cache = orm_obj:get_all_entry()
    assert(not is_cache and #get_entry_list == #entry_list)--首次查询，不确定缓存数量与实际数量是否一致

    local get_entry_list,is_cache = orm_obj:get_all_entry()
    assert(is_cache and #get_entry_list == #entry_list)--首次查询，第二次查询应命中缓存

    skynet.sleep(300)

    local _,is_cache = orm_obj:get_entry(10002) --保活
    assert(not is_cache)
    skynet.sleep(300)
    assert(orm_obj._main_index._cache_count == 6 and orm_obj._main_index._cache_total_count == nil)
    local _,is_cache = orm_obj:get_all_entry()
    assert(not is_cache)
    assert(orm_obj._main_index._cache_count == 12 and orm_obj._main_index._cache_total_count == 12)

    orm_obj:delete_entry(10002, 1, 1)
    assert(orm_obj._main_index._cache_count == 11 and orm_obj._main_index._cache_total_count == 11)

    orm_obj:create_one_entry({player_id = 10004, role_id = 3, sex = 2})
    assert(orm_obj._main_index._cache_count == 12 and orm_obj._main_index._cache_total_count == 12)
    delete_table()
end

--测试删除所有数据
local function test_delete_all()
    delete_table()
    local adapter = ormadapter_mysql:new("admin")
    local orm_obj = ormtable:new("t_player")
    :int64("player_id")
    :int64("role_id")
    :int8("sex")
    :string32("nickname")
    :string64("email")
    :uint8("sex1")
    :set_keys("player_id","role_id","sex")
    :set_cache(500,500)   --5秒保存一次
    :builder(adapter)

    local _ = orm_obj:create_entry({
        {player_id = 10002, role_id = 1, sex = 1},
        {player_id = 10002, role_id = 2, sex = 1},
        {player_id = 10002, role_id = 3, sex = 1},
        {player_id = 10002, role_id = 1, sex = 2},
        {player_id = 10002, role_id = 2, sex = 2},
        {player_id = 10002, role_id = 3, sex = 2},
        {player_id = 10003, role_id = 1, sex = 1},
        {player_id = 10003, role_id = 2, sex = 1},
        {player_id = 10003, role_id = 3, sex = 1},
        {player_id = 10003, role_id = 1, sex = 2},
        {player_id = 10003, role_id = 2, sex = 2},
        {player_id = 10003, role_id = 3, sex = 2}
    })

    orm_obj:delete_all_entry()

    assert(orm_obj._main_index._cache_count == 0)

    local entry_list = orm_obj:get_all_entry()
    assert(#entry_list == 0)

    local _ = orm_obj:create_one_entry({player_id = 10002, role_id = 1, sex = 1})
    assert(orm_obj._main_index._cache_count == 1 and orm_obj._main_index._cache_total_count == 1)

    local entry_list = orm_obj:get_all_entry()
    assert(#entry_list == 1)

    delete_table()
end

-- 测试创建单条数据
local function test_craete_one()
    delete_table()
    local orm_obj = test_create_table()

    --新建单条数据
    local new_data = {player_id = 10001,role_id = 1, sex = 1}
    local entry = orm_obj:create_one_entry(new_data)
    assert(entry)
    assert(entry:get('player_id') == 10001)
    assert(entry:get('role_id') == 1)
    assert(entry:get('sex') == 1)
    assert(entry:get('nickname') == "") --没有设置的string 会默认给个空 string
    assert(entry:get('sex1') == 0)      --没有设置的number 会默认给个 0

    --主键冲突
    local new_data = {player_id = 10001,role_id = 1, sex = 1}
    local isok = pcall(orm_obj.create_one_entry, orm_obj, new_data)
    assert(not isok)     

    --缺少主键数据
    local new_data = {player_id = 10001,role_id = 2}
    local isok = pcall(orm_obj.create_one_entry,orm_obj,new_data)
    assert(not isok) --会崩溃报错

    delete_table()
end

-- 测试查询单条数据
local function test_select_one()
    delete_table()
    local orm_obj = test_create_table()
    --新建多条数据
    local new_data_list = {
        {player_id = 10002,role_id = 1, sex = 1},
        {player_id = 10002,role_id = 2, sex = 1},
        {player_id = 10002,role_id = 2, sex = 2},
        {player_id = 10002,role_id = 3, sex = 2},
        {player_id = 10003,role_id = 1, sex = 1},
        {player_id = 10003,role_id = 2, sex = 1},
        {player_id = 10003,role_id = 2, sex = 2},
        {player_id = 10003,role_id = 3, sex = 2},
    }

    local res = orm_obj:create_entry(new_data_list)
    assert(#res == 8)
    for i,v in pairs(res) do
        assert(v)
    end

    --通过player_id查询
    local entry = orm_obj:get_one_entry(10002, 1, 1)
    assert(entry:get('player_id') == new_data_list[1].player_id)
    assert(entry:get('role_id') == new_data_list[1].role_id)
    assert(entry:get('sex') == new_data_list[1].sex)

    --缺少2个参数
    local isok,_ = pcall(orm_obj.get_one_entry, orm_obj, 10002)
    assert(not isok)
    --缺少1个参数
    local isok,_ = pcall(orm_obj.get_one_entry, orm_obj, 10002, 1)
    assert(not isok)

    --查询不存在数据
    local entry = orm_obj:get_one_entry(10004, 1, 1)
    assert(not entry)

    delete_table()
end

--测试连接断开后的API效果
local function test_disconnect()
    delete_table()
    --批量创建
    --因为批量创建可能存在分批请求mysql，所有过程中不能断言，结果应该是全部创建失败
    local orm_obj = test_create_table()

    local entry_list = orm_obj:create_entry({
        {player_id = 110002,role_id = 1, sex = 1},
        {player_id = 110002,role_id = 2, sex = 1},
        {player_id = 110002,role_id = 2, sex = 2},
        {player_id = 110002,role_id = 3, sex = 2},
        {player_id = 110003,role_id = 1, sex = 1},
        {player_id = 110003,role_id = 2, sex = 1},
        {player_id = 110003,role_id = 2, sex = 2},
        {player_id = 110003,role_id = 3, sex = 2},
    })

    os.execute("pkill mysql")
    log.info("杀掉数据库》》》》》》》》》》》》》")
    skynet.sleep(500)
    --新建多条数据
    local new_data_list = {
        {player_id = 10002,role_id = 1, sex = 1},
        {player_id = 10002,role_id = 2, sex = 1},
        {player_id = 10002,role_id = 2, sex = 2},
        {player_id = 10002,role_id = 3, sex = 2},
        {player_id = 10003,role_id = 1, sex = 1},
        {player_id = 10003,role_id = 2, sex = 1},
        {player_id = 10003,role_id = 2, sex = 2},
        {player_id = 10003,role_id = 3, sex = 2},
    }

    local res = orm_obj:create_entry(new_data_list)
    for i = 1, #res do
        assert(res[i] == false)
    end

    --新建单条数据
    --创建失败，应该出现断言错误

    local isok, err = pcall(orm_obj.create_one_entry, orm_obj, {
        player_id = 10005, role_id = 3, sex = 2
    })
    log.error("create_one_entry:", isok, err)
    assert(not isok)

    --批量查询
    --数据库断开了，查询失败，应该断言
    local isok, err = pcall(orm_obj.get_entry, orm_obj, 10002, 1)

    log.error("get_entry:", isok, err)
    assert(not isok)

    --查询单条数据
    local isok,err = pcall(orm_obj.get_one_entry, orm_obj, 10003, 3, 2)
    log.error("get_one_entry:", isok, err)
    assert(not isok)

    --批量保存数据
    --因为保存也是批量分配执行的，并且设置间隔保存的时候会自动重试，所以不能断言。
    for _,entry in ipairs(entry_list) do
        entry:set("nickname", "skynet_fly")
    end
    local ret_list = orm_obj:save_entry(entry_list)
    log.error("save_entry:", ret_list)
    for _,v in ipairs(ret_list) do
        assert(v == false)
    end

    --保存一条数据，失败应该断言
    local isok, err = pcall(orm_obj.save_one_entry, orm_obj, entry_list[1])
    log.error("save_one_entry:", isok, err)
    assert(not isok)

    --删除数据，失败应该断言
    local isok, err = pcall(orm_obj.delete_entry, orm_obj, 10003, 3, 2)
    log.error("delete_entry:", isok, err)
    assert(not isok)

    --查询所有数据，失败应该断言
    local isok, err = pcall(orm_obj.get_all_entry, orm_obj)
    log.error("get_all_entry:", isok, err)
    assert(not isok)

    --删除所有数据，失败应该断言
    local isok, err = pcall(orm_obj.delete_all_entry, orm_obj)
    log.error("delete_all_entry:", isok, err)
    assert(not isok)

    --通过数据查询出entry，失败应该断言
    local isok, err = pcall(orm_obj.get_entry_by_data, orm_obj, {player_id = 10003, role_id = 3, sex = 1})
    log.error("get_entry_by_data:", isok, err)
    assert(not isok)

    log.info("启动数据库》》》》》》》》》》》》》")
    os.execute("systemctl start mysql")
    delete_table()
end
--测试缓存超上限，剔除最快过期
local function test_tti()
    delete_table()
    local adapter = ormadapter_mysql:new("admin")
    local orm_obj = ormtable:new("t_player")
    :int64("player_id")
    :int64("role_id")
    :int8("sex")
    :string32("nickname")
    :string64("email")
    :uint8("sex1")
    :set_keys("player_id","role_id","sex")
    :set_cache(6000,2000, 10)   --缓存60秒,20秒保存一次，最大缓存10条
    :builder(adapter)

    local entry_list = {}
    for i = 1, 15 do
        local entry = orm_obj:create_one_entry({
            player_id = tonumber(1000 .. i),
            role_id = 101,
            sex = 1,
        })
        table.insert(entry_list, entry)
        if i == 3 then
            entry:set("nickname", "ddd")
        end
        skynet.sleep(100)
    end

    local entry = orm_obj:get_one_entry(10001, 101, 1)
    assert(entry ~= entry_list[1])
    local entry7 = orm_obj:get_one_entry(10007, 101, 1)
    assert(entry7 == entry_list[7])
    delete_table()
end

--测试占位缓存
local function test_invalid_entry()
    delete_table()
    local adapter = ormadapter_mysql:new("admin")
    local orm_obj = ormtable:new("t_player")
    :int64("player_id")
    :int64("role_id")
    :int8("sex")
    :string32("nickname")
    :string64("email")
    :uint8("sex1")
    :set_keys("player_id","role_id","sex")
    :set_cache(500, 100, 10)   --缓存5秒,1秒保存一次，最大缓存10条
    :builder(adapter)

    --首次查询不存在的数据
    local entry_list,is_cache = orm_obj:get_entry(10001)
    --首次查询不会命中缓存
    assert(not is_cache)
    --没有数据
    assert(#entry_list <= 0)
    skynet.yield()
    --二次查询不存在的数据
    entry_list,is_cache = orm_obj:get_entry(10001)
    --二次查询应命中缓存
    assert(is_cache)
    --二次查询还是没数据
    assert(#entry_list <= 0)
    skynet.yield()
    --首次查询不存在的数据
    local entry_list,is_cache = orm_obj:get_entry(10001, 1)
    --首次查询不会命中缓存
    assert(not is_cache)
    --没有数据
    assert(#entry_list <= 0)
    skynet.yield()
    --二次查询不存在的数据
    entry_list,is_cache = orm_obj:get_entry(10001, 1)
    --二次查询应命中缓存
    assert(is_cache)
    --二次查询还是没数据
    assert(#entry_list <= 0)
    skynet.yield()
    --首次查询不存在的数据
    local entry_list,is_cache = orm_obj:get_entry(10001, 1, 1)
    --首次查询不会命中缓存
    assert(not is_cache)
    --没有数据
    assert(#entry_list <= 0)
    skynet.yield()
    --二次查询不存在的数据
    entry_list,is_cache = orm_obj:get_entry(10001, 1, 1)
    --二次查询应命中缓存
    assert(is_cache)
    --二次查询还是没数据
    assert(#entry_list <= 0)
    skynet.yield()
    --首次查询不存在的数据
    local entry,is_cache = orm_obj:get_one_entry(10001, 1, 2)
    --首次查询不会命中缓存
    assert(not is_cache)
    --没有数据
    assert(not entry)
    skynet.yield()
    --二次查询不存在的数据
    entry,is_cache = orm_obj:get_one_entry(10001, 1, 2)
    --二次查询应命中缓存
    assert(is_cache)
    --二次查询还是没数据
    assert(not entry)

    skynet.yield()
    --创建数据应覆盖缓存
    local entry = orm_obj:create_one_entry({player_id = 10001, role_id = 1, sex = 2})
    assert(entry)

    skynet.yield()
    local get_entry, is_cache = orm_obj:get_one_entry(10001, 1, 2)
    assert(is_cache)
    assert(get_entry == entry)

    skynet.yield()
    --查询10001命中缓存
    local entry_list,is_cache = orm_obj:get_entry(10001)
    assert(is_cache)
    assert(#entry_list == 1)

    skynet.yield()
    --查询10001 1 命中缓存
    local entry_list,is_cache = orm_obj:get_entry(10001, 1)
    assert(is_cache)
    assert(#entry_list == 1)

    skynet.yield()
    --查询10001 2 没有
    local entry_list,is_cache = orm_obj:get_entry(10001, 2)
    assert(not is_cache)
    assert(#entry_list == 0)

    skynet.yield()
    --创建 10001 2 2
    local entry = orm_obj:create_one_entry({player_id = 10001, role_id = 2, sex = 2})
    assert(entry)
    --查询10001 2 命中缓存
    local entry_list,is_cache = orm_obj:get_entry(10001, 2)
    assert(is_cache)
    assert(#entry_list == 1)

    skynet.yield()
    --查询10001命中缓存
    local entry_list,is_cache = orm_obj:get_entry(10001)
    assert(is_cache)
    assert(#entry_list == 2)

    skynet.sleep(600)
    --查询10001 3 没有
    local entry_list,is_cache = orm_obj:get_entry(10001, 3)
    assert(not is_cache)
    assert(#entry_list == 0)

    skynet.yield()
    --创建10001 3
    local entry = orm_obj:create_one_entry({player_id = 10001, role_id = 3, sex = 1})
    assert(entry)

    skynet.yield()
    --查询10001 应不命中缓存
    local entry_list,is_cache = orm_obj:get_entry(10001)
    assert(not is_cache)
    assert(#entry_list == 3)

    skynet.yield()
    --创建10001 3 0
    local entry = orm_obj:create_one_entry({player_id = 10001, role_id = 3, sex = 0})
    assert(entry)
    skynet.yield()
    --查询10001 3 应命中缓存
    local entry_list,is_cache = orm_obj:get_entry(10001, 3)
    assert(is_cache)
    assert(#entry_list == 2)

    skynet.sleep(600)
    --查询10001 3 2 不存在
    local entry_list,is_cache = orm_obj:get_entry(10001, 3, 2)
    assert(not is_cache)
    assert(#entry_list == 0)

    skynet.yield()
    --创建10001 3 2
    local entry = orm_obj:create_one_entry({player_id = 10001, role_id = 3, sex = 2})
    assert(entry)

    skynet.yield()
    --查询10001 3应不命中缓存
    local entry_list,is_cache = orm_obj:get_entry(10001, 3)
    assert(not is_cache)
    assert(#entry_list == 3)

    skynet.yield()
    --查询10001 3 3 不存在
    local entry = orm_obj:get_one_entry(10001, 3, 3)
    assert(not is_cache)
    assert(not entry)
    skynet.yield()
    --创建 10001 3 3
    local entry = orm_obj:create_one_entry({player_id = 10001, role_id = 3, sex = 3})
    assert(entry)

    skynet.yield()
    local entry, is_cache = orm_obj:get_one_entry(10001, 3, 3)
    assert(is_cache)
    assert(entry)

    skynet.yield()
    local entry, is_cache = orm_obj:get_entry(10001, 3, 3)
    assert(is_cache)
    assert(entry)

    skynet.yield()
    --查询10001 3应命中缓存
    local entry_list,is_cache = orm_obj:get_entry(10001, 3)
    assert(is_cache)
    assert(#entry_list == 4)

    --等待缓存过期
    --查询应不命中缓存
    skynet.sleep(600)
    local entry, is_cache = orm_obj:get_one_entry(10001, 3, 3)
    assert(not is_cache)
    assert(entry)


    delete_table()

    --测试全表
    local adapter = ormadapter_mysql:new("admin")
    local orm_obj = ormtable:new("t_player")
    :int64("player_id")
    :int64("role_id")
    :int8("sex")
    :string32("nickname")
    :string64("email")
    :uint8("sex1")
    :set_keys("player_id","role_id","sex")
    :set_cache(500, 100, 10)   --缓存5秒,1秒保存一次，最大缓存10条
    :builder(adapter)

    local entry_list, is_cache = orm_obj:get_all_entry()
    assert(not is_cache)
    assert(#entry_list == 0)
    skynet.yield()

    local entry_list, is_cache = orm_obj:get_all_entry()
    assert(is_cache)
    assert(#entry_list == 0)
    skynet.yield()

    --创建数据
    local entry = orm_obj:create_one_entry({player_id = 10001,role_id = 1, sex = 2})
    assert(entry)
    skynet.yield()
   
    local entry_list, is_cache = orm_obj:get_all_entry()
    assert(is_cache)
    assert(#entry_list == 1)
    skynet.yield()

    skynet.sleep(600)

    --创建数据
    local entry = orm_obj:create_one_entry({player_id = 10001,role_id = 1, sex = 3})
    assert(entry)
    skynet.yield()

    local entry_list, is_cache = orm_obj:get_all_entry()
    assert(not is_cache)
    assert(#entry_list == 2)
    skynet.yield()
    
    delete_table()
end

--测试永久缓存
local function test_every_cache()
    delete_table()

    local adapter = ormadapter_mysql:new("admin")
    local orm_obj = ormtable:new("t_player")
    :int64("player_id")
    :int64("role_id")
    :int8("sex")
    :string32("nickname")
    :string64("email")
    :uint8("sex1")
    :set_keys("player_id","role_id","sex")
    :set_cache(0, 100)   --缓存5秒,1秒保存一次，最大缓存10条
    :builder(adapter)

    --永久缓存，缓存没有就是没有数据，不需要查询数据库
    --首次查询不存在的数据
    local entry_list,is_cache = orm_obj:get_entry(10001)
    --首次查询会命中缓存
    assert(is_cache)
    assert(#entry_list == 0)
    
    local entry, is_cache = orm_obj:get_one_entry(10001, 1, 1)
    assert(not entry)
    assert(is_cache)

    local entry_list = orm_obj:create_entry({
        {player_id = 10001, role_id = 1, sex = 1},
        {player_id = 10001, role_id = 2, sex = 1},
        {player_id = 10001, role_id = 3, sex = 1},
    })

    orm_obj:save_entry(entry_list)
    
    orm_obj = ormtable:new("t_player")
    :int64("player_id")
    :int64("role_id")
    :int8("sex")
    :string32("nickname")
    :string64("email")
    :uint8("sex1")
    :set_keys("player_id","role_id","sex")
    :set_cache(0, 100)   --缓存5秒,1秒保存一次，最大缓存10条
    :builder(adapter)

    local entry, is_cache = orm_obj:get_one_entry(10001, 4, 1)
    assert(not entry)
    assert(is_cache)

    local entry, is_cache = orm_obj:get_one_entry(10001, 1, 1)
    assert(entry)
    assert(is_cache)

    delete_table()
end

--测试间隔保存前删除了
local function test_inval_save_del()
    delete_table()
    local adapter = ormadapter_mysql:new("admin")
    local orm_obj = ormtable:new("t_player")
    :int64("player_id")
    :int64("role_id")
    :int8("sex")
    :string32("nickname")
    :string64("email")
    :uint8("sex1")
    :set_keys("player_id","role_id","sex")
    :set_cache(500,500)   --5秒保存一次
    :builder(adapter)

    -- 自动保存数据
    local entry_list = orm_obj:create_entry({
        {player_id = 10002, role_id = 1, sex = 1},
    })

    for i,entry in ipairs(entry_list) do
        entry:set("email", "emailssss")
    end

    orm_obj:delete_entry(10002, 1, 1)
    local _ = orm_obj:create_entry({
        {player_id = 10002, role_id = 1, sex = 1},
    })

    skynet.sleep(500)

    local entry = orm_obj:get_one_entry(10002, 1, 1)
    log.info(">>>", entry:get_entry_data())
    assert(entry:get('email') == "")
    delete_table()
end

--压测
--stress testing
local function stress_testing()
    delete_table()
    local adapter = ormadapter_mysql:new("admin")
    local orm_obj = ormtable:new("t_player")
    :int64("player_id")
    :int64("role_id")
    :int8("sex")
    :string32("nickname")
    :string64("email")
    :uint8("sex1")
    :set_keys("player_id","role_id","sex")
    :set_cache(500,500)   --5秒保存一次
    :builder(adapter)

    local pre_time = skynet.time()
    local count = 10000
    for i = 1, count do
        orm_obj:create_one_entry({player_id = i, role_id = 1, sex = 1})
    end
    
    local use_time = skynet.time() - pre_time
    log.info("qps:", count / use_time)

    delete_table()
end

local function test_get_entry_in()
    delete_table()
    local adapter = ormadapter_mysql:new("admin")
    local orm_obj = ormtable:new("t_player")
    :int64("player_id")
    :int64("role_id")
    :int8("sex")
    :string32("nickname")
    :string64("email")
    :uint8("sex1")
    :set_keys("player_id","role_id","sex")
    :set_cache(500,500)   --5秒保存一次
    :builder(adapter)

    local entry_data_list = {
        {player_id = 10001, role_id = 1, sex = 1},
        {player_id = 10001, role_id = 1, sex = 2},
        {player_id = 10001, role_id = 2, sex = 1},
        {player_id = 10001, role_id = 2, sex = 2},
        {player_id = 10002, role_id = 1, sex = 1},
        {player_id = 10002, role_id = 1, sex = 2},
        {player_id = 10002, role_id = 2, sex = 1},
        {player_id = 10002, role_id = 2, sex = 2},
    }
    orm_obj:create_entry(entry_data_list)

    --查询 key1
    local entry_list, is_cache = orm_obj:get_entry_by_in({10001, 10002})
    assert(#entry_list == 8)
    assert(not is_cache)        --第一次没有缓存

    local entry_list, is_cache = orm_obj:get_entry_by_in({10001, 10002})
    assert(#entry_list == 8)
    assert(is_cache)            --第二次中缓存
    local entry_list, is_cache = orm_obj:get_entry_by_in({10001})
    assert(#entry_list == 4)
    assert(is_cache)            --中缓存

    --查询不存在
    local entry_list, is_cache = orm_obj:get_entry_by_in({10003, 10004})
    assert(#entry_list == 0)
    assert(not is_cache)        --第一次没有缓存

    local entry_list, is_cache = orm_obj:get_entry_by_in({10003, 10004})
    assert(#entry_list == 0)
    assert(is_cache)            --中缓存

    local entry_list, is_cache = orm_obj:get_entry_by_in({10003})
    assert(#entry_list == 0)
    assert(is_cache)            --中缓存

    skynet.sleep(600)

    --查询key2
    local entry_list, is_cache = orm_obj:get_entry_by_in({1, 2}, 10001)
    assert(#entry_list == 4)
    assert(not is_cache)        --第一次没有缓存

    local entry_list, is_cache = orm_obj:get_entry_by_in({1, 2}, 10001)
    assert(#entry_list == 4)
    assert(is_cache)

    local entry_list, is_cache = orm_obj:get_entry_by_in({2}, 10001)
    assert(#entry_list == 2)
    assert(is_cache)

    --查询不存在
    local entry_list, is_cache = orm_obj:get_entry_by_in({4, 3}, 10001)
    assert(#entry_list == 0)
    assert(not is_cache)        --第一次没有缓存

    local entry_list, is_cache = orm_obj:get_entry_by_in({4, 3}, 10001)
    assert(#entry_list == 0)
    assert(is_cache)            --中缓存

    skynet.sleep(600)
    --查询key3
    local entry_list, is_cache = orm_obj:get_entry_by_in({1, 2}, 10001, 1)
    assert(#entry_list == 2)
    assert(not is_cache)        --第一次没有缓存

    local entry_list, is_cache = orm_obj:get_entry_by_in({1, 2}, 10001, 1)
    assert(#entry_list == 2)
    assert(is_cache)        --中缓存

    
    local entry_list, is_cache = orm_obj:get_entry_by_in({1}, 10001, 1)
    assert(#entry_list == 1)
    assert(is_cache)        --中缓存

    --查询不存在
    local entry_list, is_cache = orm_obj:get_entry_by_in({4, 3}, 10001, 1)
    assert(#entry_list == 0)
    assert(not is_cache)        --第一次没有缓存

    local entry_list, is_cache = orm_obj:get_entry_by_in({4, 3}, 10001, 1)
    assert(#entry_list == 0)
    assert(is_cache)            --中缓存

    delete_table()
end

local function test_get_entry_limit()
    delete_table()
    --测试有缓存的
    local adapter = ormadapter_mysql:new("admin")
    local orm_obj = ormtable:new("t_player")
    :int64("player_id")
    :int64("role_id")
    :int8("sex")
    :string32("nickname")
    :string64("email")
    :uint8("sex1")
    :set_keys("player_id","role_id","sex")
    :set_cache(500,500)   --5秒保存一次
    :builder(adapter)

    for i = 1, 100 do
        orm_obj:create_one_entry({player_id = 10001, role_id = 10000, sex = i})
    end

    --测试升序
    local entry_list = nil
    local curson = nil
    local count = nil
    for i = 1, 10 do
        curson, entry_list, count = orm_obj:get_entry_by_limit(curson, 10, 1, 10001, 10000)
        assert(curson == i * 10)

        if i == 1 then
            assert(count == 100)
        else
            assert(not count)
        end

        for k,v in ipairs(entry_list) do
            assert(v:get('sex') == (i - 1) * 10 + k)
        end
    end

    --测试降序
    local entry_list = nil
    local curson = nil
    local count = nil
    for i = 1, 10 do
        curson, entry_list, count = orm_obj:get_entry_by_limit(curson, 10, -1, 10001, 10000)
        assert(curson == (10 - i) * 10 + 1)

        if i == 1 then
            assert(count == 100)
        else
            assert(not count)
        end

        for k,v in ipairs(entry_list) do
            assert(v:get('sex') == (10 - i + 1) * 10 - (k - 1))
        end
    end

    delete_table()

    --测试没有缓存的
    local adapter = ormadapter_mysql:new("admin")
    local orm_obj = ormtable:new("t_player")
    :int64("player_id")
    :int64("role_id")
    :int8("sex")
    :string32("nickname")
    :string64("email")
    :uint8("sex1")
    :set_keys("player_id","role_id","sex")
    :builder(adapter)

    for i = 1, 100 do
        orm_obj:create_one_entry({player_id = 10001, role_id = 10000, sex = i})
    end

    --测试升序
    local entry_list = nil
    local curson = nil
    local count = nil
    for i = 1, 10 do
        curson, entry_list, count = orm_obj:get_entry_by_limit(curson, 10, 1, 10001, 10000)
        assert(curson == i * 10)

        if i == 1 then
            assert(count == 100)
        else
            assert(not count)
        end

        for k,v in ipairs(entry_list) do
            assert(v:get('sex') == (i - 1) * 10 + k)
        end
    end

    --测试降序
    local entry_list = nil
    local curson = nil
    local count = nil
    for i = 1, 10 do
        curson, entry_list, count = orm_obj:get_entry_by_limit(curson, 10, -1, 10001, 10000)
        assert(curson == (10 - i) * 10 + 1)

        if i == 1 then
            assert(count == 100)
        else
            assert(not count)
        end

        for k,v in ipairs(entry_list) do
            assert(v:get('sex') == (10 - i + 1) * 10 - (k - 1))
        end
    end
    delete_table()

    --测试1个key
    delete_table()
    --测试有缓存的
    local adapter = ormadapter_mysql:new("admin")
    local orm_obj = ormtable:new("t_player")
    :int64("player_id")
    :int64("role_id")
    :int8("sex")
    :set_keys("player_id")
    :set_cache(500,500)   --5秒保存一次
    :builder(adapter)

    for i = 1, 100 do
        orm_obj:create_one_entry({player_id = i})
    end

    --测试升序
    local entry_list = nil
    local curson = nil
    local count = nil
    for i = 1, 10 do
        curson, entry_list, count = orm_obj:get_entry_by_limit(curson, 10, 1)
        assert(curson == i * 10)

        if i == 1 then
            assert(count == 100)
        else
            assert(not count)
        end

        for k,v in ipairs(entry_list) do
            assert(v:get('player_id') == (i - 1) * 10 + k)
        end
    end

    --测试降序
    local entry_list = nil
    local curson = nil
    local count = nil
    for i = 1, 10 do
        curson, entry_list, count = orm_obj:get_entry_by_limit(curson, 10, -1)
        assert(curson == (10 - i) * 10 + 1)

        if i == 1 then
            assert(count == 100)
        else
            assert(not count)
        end

        for k,v in ipairs(entry_list) do
            assert(v:get('player_id') == (10 - i + 1) * 10 - (k - 1))
        end
    end

    delete_table()

    --测试没有缓存的
    local adapter = ormadapter_mysql:new("admin")
    local orm_obj = ormtable:new("t_player")
    :int64("player_id")
    :int64("role_id")
    :int8("sex")
    :set_keys("player_id")
    :builder(adapter)

    for i = 1, 100 do
        orm_obj:create_one_entry({player_id = i})
    end

    --测试升序
    local entry_list = nil
    local curson = nil
    local count = nil
    for i = 1, 10 do
        curson, entry_list, count = orm_obj:get_entry_by_limit(curson, 10, 1)
        assert(curson == i * 10)

        if i == 1 then
            assert(count == 100)
        else
            assert(not count)
        end

        for k,v in ipairs(entry_list) do
            assert(v:get('player_id') == (i - 1) * 10 + k)
        end
    end

    --测试降序
    local entry_list = nil
    local curson = nil
    local count = nil
    for i = 1, 10 do
        curson, entry_list, count = orm_obj:get_entry_by_limit(curson, 10, -1)
        assert(curson == (10 - i) * 10 + 1)

        if i == 1 then
            assert(count == 100)
        else
            assert(not count)
        end

        for k,v in ipairs(entry_list) do
            assert(v:get('player_id') == (10 - i + 1) * 10 - (k - 1))
        end
    end
    delete_table()
end

local function test_delete_by_range()
    delete_table()

    local adapter = ormadapter_mysql:new("admin")
    local orm_obj = ormtable:new("t_player")
    :int64("player_id")
    :int64("role_id")
    :int8("sex")
    :string32("nickname")
    :string64("email")
    :uint8("sex1")
    :set_keys("player_id","role_id","sex")
    :set_cache(500,500)   --5秒保存一次
    :builder(adapter)

    local entry_data_list = {
        {player_id = 10001, role_id = 1, sex = 1},
        {player_id = 10001, role_id = 1, sex = 2},
        {player_id = 10001, role_id = 2, sex = 1},
        {player_id = 10001, role_id = 2, sex = 2},
        {player_id = 10001, role_id = 3, sex = 1},
        {player_id = 10001, role_id = 3, sex = 2},
        {player_id = 10001, role_id = 4, sex = 1},
        {player_id = 10001, role_id = 4, sex = 2},

        {player_id = 10002, role_id = 1, sex = 1},
        {player_id = 10002, role_id = 1, sex = 2},
        {player_id = 10002, role_id = 2, sex = 1},
        {player_id = 10002, role_id = 2, sex = 2},
        {player_id = 10002, role_id = 3, sex = 1},
        {player_id = 10002, role_id = 3, sex = 2},
        {player_id = 10002, role_id = 4, sex = 1},
        {player_id = 10002, role_id = 4, sex = 2},
        
        {player_id = 10003, role_id = 1, sex = 1},
        {player_id = 10003, role_id = 1, sex = 2},
        {player_id = 10003, role_id = 2, sex = 1},
        {player_id = 10003, role_id = 2, sex = 2},
        {player_id = 10003, role_id = 3, sex = 1},
        {player_id = 10003, role_id = 3, sex = 2},
        {player_id = 10003, role_id = 4, sex = 1},
        {player_id = 10003, role_id = 4, sex = 2},
        
        {player_id = 10004, role_id = 1, sex = 1},
        {player_id = 10004, role_id = 1, sex = 2},
        {player_id = 10004, role_id = 2, sex = 1},
        {player_id = 10004, role_id = 2, sex = 2},
        {player_id = 10004, role_id = 3, sex = 1},
        {player_id = 10004, role_id = 3, sex = 2},
        {player_id = 10004, role_id = 4, sex = 1},
        {player_id = 10004, role_id = 4, sex = 2},
    }
    orm_obj:create_entry(entry_data_list)

    local ret = orm_obj:delete_entry_by_range(1, 2, 10001, 1)
    assert(ret)

    local entry_list = orm_obj:get_entry(10001, 1)
    assert(#entry_list == 0)

    local ret = orm_obj:delete_entry_by_range(3, nil, 10001)
    assert(ret)
    local entry_list = orm_obj:get_entry(10001)
    assert(#entry_list == 2)

    local ret = orm_obj:delete_entry_by_range(nil, 10003)
    assert(ret)

    local entry_list = orm_obj:get_all_entry()
    assert(#entry_list == 8)

    delete_table()
end

--测试防止sql注入
local function test_quete_key_values()
    mysqlf:instance("admin"):query("drop table if exists t_user")
    local adapter = ormadapter_mysql:new("admin")
    local orm_obj = ormtable:new("t_user")
    :string64("acoount")
    :int64("role_id")
    :int8("sex")
    :set_keys("acoount", "role_id")
    :builder(adapter)

    local entry = orm_obj:create_one_entry({acoount = "test", role_id = 1, sex = 1})
    assert(entry)

    local entry = orm_obj:get_one_entry("test' or '1'='1", 1)
    assert(not entry)

    mysqlf:instance("admin"):query("drop table if exists t_user")
end

--测试table
local function test_table_type()
    delete_table()

    local adapter = ormadapter_mysql:new("admin")
    local orm_obj = ormtable:new("t_player")
    :int64("player_id")
    :table("info")
    :set_keys("player_id")
    :builder(adapter)

    local entry = orm_obj:create_one_entry({player_id = 10001, info = {a = 1, b = 2, c = "'"}})
    assert(entry)
    local info = entry:get('info')
    info.d = 100
    info.c = nil
    entry:set('info', info)
    orm_obj:save_one_entry(entry)

    local entry = orm_obj:get_one_entry(10001)
    assert(entry)
    local info = entry:get('info')
    assert(info.c == nil)
    assert(info.d == 100)

    delete_table()
end

--测试delete in
local function test_delete_in(is_cache)
    delete_table()
    local adapter = ormadapter_mysql:new("admin")
    local orm_obj = ormtable:new("t_player")
    :int64("player_id")
    :int64("role_id")
    :int8("sex")
    :string32("nickname")
    :string64("email")
    :uint8("sex1")
    :set_keys("player_id","role_id","sex")

    if is_cache then
        orm_obj = orm_obj:set_cache(500, 500) --5秒保存一次
    end
    
    orm_obj = orm_obj:builder(adapter)
    local new_data_list = {
        {player_id = 10001, role_id = 1, sex = 1},
        {player_id = 10001, role_id = 1, sex = 2},
        {player_id = 10001, role_id = 2, sex = 1},
        {player_id = 10001, role_id = 2, sex = 2},
        {player_id = 10001, role_id = 3, sex = 1},
        {player_id = 10001, role_id = 3, sex = 2},
        {player_id = 10001, role_id = 4, sex = 1},
        {player_id = 10001, role_id = 4, sex = 2},

        {player_id = 10002, role_id = 1, sex = 1},
        {player_id = 10002, role_id = 1, sex = 2},
        {player_id = 10002, role_id = 2, sex = 1},
        {player_id = 10002, role_id = 2, sex = 2},
        {player_id = 10002, role_id = 3, sex = 1},
        {player_id = 10002, role_id = 3, sex = 2},
        {player_id = 10002, role_id = 4, sex = 1},
        {player_id = 10002, role_id = 4, sex = 2},
    }

    orm_obj:create_entry(new_data_list)

    --测试 传入2个key
    local ret = orm_obj:delete_entry_by_in({2}, 10001, 1) --删除 player_id = 10001 , role_id = 1, sex = 2
    assert(ret)

    local del_num = 0
    local entry = orm_obj:get_one_entry(10001, 1, 2)
    assert(not entry)   --被删除了，肯定查不到
    del_num = del_num + 1   --删掉了一条数据
    local entry_list = orm_obj:get_all_entry()
    assert(#entry_list == #new_data_list - del_num, string.format("err len[%s] datalen[%s] del_num[%s]", #entry_list, #new_data_list, del_num))     

    --测试传入1个key
    local ret = orm_obj:delete_entry_by_in({2}, 10001) --删除 player_id = 10001 role_id = 2
    assert(ret)
    del_num = del_num + 2   --删掉了二条数据

    local entry_list = orm_obj:get_entry(10001, 2)
    assert(#entry_list == 0, #entry_list)

    local entry_list = orm_obj:get_all_entry()
    assert(#entry_list == #new_data_list - del_num, string.format("err len[%s] datalen[%s] del_num[%s]", #entry_list, #new_data_list, del_num))

    --测试不传入key
    local ret = orm_obj:delete_entry_by_in({10002})
    assert(ret)
    local entrt_list = orm_obj:get_entry(10002)
    assert(#entrt_list == 0)
    del_num = del_num + 8 --删掉了8条数据

    local entry_list = orm_obj:get_all_entry()
    assert(#entry_list == #new_data_list - del_num, string.format("err len[%s] datalen[%s] del_num[%s]", #entry_list, #new_data_list, del_num))

    delete_table()
end

--测试批量删除
local function test_batch_delete()
    delete_table()
    local adapter = ormadapter_mysql:new("admin"):set_batch_delete_num(5)
    local orm_obj = ormtable:new("t_player")
    :int64("player_id")
    :int64("role_id")
    :string32("nickname")
    :set_keys("player_id","role_id")
    :builder(adapter)

    for i = 1, 100 do
        for j = 1, 3 do
            orm_obj:create_one_entry({player_id = i, role_id = j})
        end
    end

    --测试2个key删除 删除1-51的第三条数据
    local keys_list = {}
    for i = 1, 51 do
        table.insert(keys_list, {i, 3})
    end
    local res = orm_obj:batch_delete_entry(keys_list)
    for i = 1, #res do
        assert(res[i])
    end

    for i = 1, #keys_list do
        local one_data = keys_list[i]
        --查询3数据不存在
        local entry = orm_obj:get_one_entry(one_data[1], one_data[2])
        assert(not entry)
        --还有 role_id = 1和2两条数据
        local entry_list = orm_obj:get_entry(one_data[1])
        assert(#entry_list == 2)
        assert(entry_list[1]:get('role_id') == 1)
        assert(entry_list[2]:get('role_id') == 2)
    end

    --测试1个key删除 删除52-101
    local keys_list = {}
    for i = 52, 101 do
        table.insert(keys_list, {i})
    end
    local res = orm_obj:batch_delete_entry(keys_list)
    for i = 1, #res do
        assert(res[i])
    end

    -- 52 - 101 都没有数据了
    for i = 52, 101 do
        local entry_list = orm_obj:get_entry(i)
        assert(#entry_list == 0, i .. ":" .. #entry_list)
    end

    --1 - 51 都还剩下role_id = 1 和 2 
    for i = 1, 51 do
        local entry_list = orm_obj:get_entry(i)
        assert(#entry_list == 2)
        assert(entry_list[1]:get('role_id') == 1)
        assert(entry_list[2]:get('role_id') == 2)
    end

    delete_table()
end

--测试批量范围删除
local function test_batch_range_delete()
    delete_table()
    local adapter = ormadapter_mysql:new("admin"):set_batch_delete_num(5)
    local orm_obj = ormtable:new("t_player")
    :int64("player_id")
    :int64("role_id")
    :string32("nickname")
    :set_keys("player_id","role_id", "nickname")
    :builder(adapter)

    for i = 1, 100 do
        for j = 1, 5 do
            for k = 1, 5 do
                orm_obj:create_one_entry({player_id = i, role_id = j, nickname = i ..':' .. j .. ':' .. k})
            end
        end
    end

    --测试2个key删除 删除 role_id = 1 nickanme >= 2
    local query_list = {}
    for i = 1, 51 do
        local query = {
            key_values = {i, 1},
            left = i .. ':1:2',
        }
        table.insert(query_list, query)
    end
    local res = orm_obj:batch_delete_entry_by_range(query_list)
    for i = 1, #res do
        assert(res[i])
    end

    for i = 1, #query_list do
        local query = query_list[i]
        local key_values = query.key_values
        local entry_list = orm_obj:get_entry(key_values[1], key_values[2])
        assert(#entry_list == 1, #entry_list)
        assert(entry_list[1]:get('nickname') == i .. ":1:1", entry_list[1]:get('nickname'))
    end

    --测试2个key删除 删除 role_id = 2 nickanme <= 4
    local query_list = {}
    for i = 1, 51 do
        local query = {
            key_values = {i, 2},
            right = i .. ':2:4',
        }
        table.insert(query_list, query)
    end
    local res = orm_obj:batch_delete_entry_by_range(query_list)
    for i = 1, #res do
        assert(res[i])
    end

    for i = 1, #query_list do
        local query = query_list[i]
        local key_values = query.key_values
        local entry_list = orm_obj:get_entry(key_values[1], key_values[2])
        assert(#entry_list == 1)
        assert(entry_list[1]:get('nickname') == i .. ":2:5", entry_list[1]:get('nickname'))
    end

    --测试2个key删除 删除 role_id = 3 nickname >= 2 and nickname <= 4
    local query_list = {}
    for i = 1, 51 do
        local query = {
            key_values = {i, 3},
            left = i .. ':3:2',
            right = i .. ':3:4',
        }
        table.insert(query_list, query)
    end
    local res = orm_obj:batch_delete_entry_by_range(query_list)
    for i = 1, #res do
        assert(res[i])
    end

    for i = 1, #query_list do
        local query = query_list[i]
        local key_values = query.key_values
        local entry_list = orm_obj:get_entry(key_values[1], key_values[2])
        assert(#entry_list == 2)
        assert(entry_list[1]:get('nickname') == i .. ":3:1", entry_list[1]:get('nickname'))
        assert(entry_list[2]:get('nickname') == i .. ":3:5", entry_list[2]:get('nickname'))
    end

    --测试1个key删除 删除 role_id >= 2
    local query_list = {}
    for i = 52, 63 do
        local query = {
            key_values = {i},
            left = 2,
        }
        table.insert(query_list, query)
    end
    local res = orm_obj:batch_delete_entry_by_range(query_list)
    for i = 1, #res do
        assert(res[i])
    end
    for i = 1, #query_list do
        local query = query_list[i]
        local key_values = query.key_values
        local entry_list = orm_obj:get_entry(key_values[1])
        assert(#entry_list == 5)
        for _, one_entry in pairs(entry_list) do
            assert(one_entry:get('role_id') == 1, one_entry:get('role_id'))
        end
    end

    --测试1个key删除 删除role_id <= 4
    local query_list = {}
    for i = 64, 78 do
        local query = {
            key_values = {i},
            right = 4,
        }
        table.insert(query_list, query)
    end
    local res = orm_obj:batch_delete_entry_by_range(query_list)
    for i = 1, #res do
        assert(res[i])
    end
    for i = 1, #query_list do
        local query = query_list[i]
        local key_values = query.key_values
        local entry_list = orm_obj:get_entry(key_values[1])
        assert(#entry_list == 5)
        for _, one_entry in pairs(entry_list) do
            assert(one_entry:get('role_id') == 5, one_entry:get('role_id'))
        end
    end

    --测试1个key删除 删除role_id >= 2 and role_id <= 4
    local query_list = {}
    for i = 79, 100 do
        local query = {
            key_values = {i},
            left = 2,
            right = 4,
        }
        table.insert(query_list, query)
    end
    local res = orm_obj:batch_delete_entry_by_range(query_list)
    for i = 1, #res do
        assert(res[i])
    end
    for i = 1, #query_list do
        local query = query_list[i]
        local key_values = query.key_values
        local entry_list = orm_obj:get_entry(key_values[1])
        assert(#entry_list == 10)
        for _, one_entry in pairs(entry_list) do
            local role_id = one_entry:get('role_id')
            assert(role_id == 1 or role_id == 5, role_id)
        end
    end

    delete_table()
end

--测试创建修改普通索引
local function test_create_change_index()
    delete_table()
    local adapter = ormadapter_mysql:new("admin")
    local _ = ormtable:new("t_player")
    :int64("player_id")
    :int64("role_id")
    :string32("nickname")
    :set_keys("player_id","role_id")
    :set_index("name_index", "nickname")
    :set_index("role_name_index", "role_id", "nickname")
    :builder(adapter)

    local _ = ormtable:new("t_player")
    :int64("player_id")
    :int64("role_id")
    :string32("nickname")
    :string32("phone")
    :set_keys("player_id","role_id")
    :set_index("name_index", "nickname")
    :set_index("phone_index", "phone")
    :builder(adapter)

    delete_table()
end

--测试通过普通索引查询
local function test_idx_get_entry()
    delete_table()
    local adapter = ormadapter_mysql:new("admin")
    local ormobj = ormtable:new("t_player")
    :int64("player_id")
    :int64("role_id")
    :string32("nickname")
    :string32("phone")
    :set_keys("player_id","role_id")
    :set_index("phone_index", "phone")
    :set_index("role_name_index", "role_id", "nickname")
    :set_cache(500, 100)
    :builder(adapter)

    local create_entry_list = ormobj:create_entry {
        {player_id = 10001, role_id = 101, nickname = "skynet_fly", phone = "13211322990"},
        {player_id = 10002, role_id = 101, nickname = "skynet", phone = "132113221"},
        {player_id = 10003, role_id = 101, nickname = "skynet_fly", phone = "132113221"},
        {player_id = 10004, role_id = 101, nickname = "skynet", phone = "132113222"},
        {player_id = 10005, role_id = 101, nickname = "skynet_fly", phone = "13211322993"},
        {player_id = 10006, role_id = 102, nickname = "skynet_fly", phone = "13211322991"},
        {player_id = 10007, role_id = 102, nickname = "skynet", phone = "132113222"},
        {player_id = 10008, role_id = 102, nickname = "skynet_fly", phone = "13211322992"},
        {player_id = 10009, role_id = 102, nickname = "skynet", phone = "132113222"},
        {player_id = 10010, role_id = 102, nickname = "skynet_fly", phone = "13211322993"},

        {player_id = 10011, role_id = 103, nickname = "skynet_fly", phone = "13211322995"},
        {player_id = 10012, role_id = 104, nickname = "skynet_fly", phone = "13211322995"},
        {player_id = 10013, role_id = 105, nickname = "skynet_fly", phone = "13211322995"},
        {player_id = 10014, role_id = 106, nickname = "skynet_fly", phone = "13211322995"},
        {player_id = 10015, role_id = 107, nickname = "skynet_fly", phone = "13211322995"},
        {player_id = 10016, role_id = 103, nickname = "skynet_fly", phone = "13211322996"},
        {player_id = 10017, role_id = 104, nickname = "skynet_fly", phone = "13211322996"},
        {player_id = 10018, role_id = 105, nickname = "skynet_fly", phone = "13211322996"},
        {player_id = 10019, role_id = 106, nickname = "skynet_fly", phone = "13211322996"},
        {player_id = 10020, role_id = 107, nickname = "skynet_fly", phone = "13211322996"},
    }

    local isok = pcall(ormobj.idx_get_entry, ormobj, {nickname = "skynet"})--这样不行，必须先得有前缀索引 role_id
    assert(not isok)

    local entry_list = ormobj:idx_get_entry({phone = '132113221'})      --手机号查询
    assert(#entry_list == 2)

    local entry_list = ormobj:idx_get_entry({phone = '13211322990'})    --缓存entry唯一性
    assert(entry_list[1] == create_entry_list[1])

    local entry_list = ormobj:idx_get_entry({phone = '132113222', role_id = 102})   --多普通索引查询
    assert(#entry_list == 2)

    local entry_list = ormobj:idx_get_entry({role_id = 102, nickname = 'skynet_fly'})
    assert(#entry_list == 3)

    local entry_list = ormobj:idx_get_entry({role_id = {['$gte'] = 103, ['$lte'] = 104}})
    assert(#entry_list == 4)

    local entry_list = ormobj:idx_get_entry({role_id = {['$gte'] = 103, ['$lte'] = 104}, phone = '13211322996'})
    assert(#entry_list == 2)

    local entry_list = ormobj:idx_get_entry({role_id = {['$gt'] = 103, ['$lte'] = 104}})
    assert(#entry_list == 2)

    local entry_list = ormobj:idx_get_entry({role_id = {['$gt'] = 103, ['$lte'] = 104}, phone = '13211322996'})
    assert(#entry_list == 1)

    delete_table()
end

--测试分页查询
local function test_idx_get_entry_by_limit()
    delete_table()

    local adapter = ormadapter_mysql:new("admin")
    local ormobj = ormtable:new("t_player")
    :int64("player_id")
    :int64("role_id")
    :string32("nickname")
    :uint8("age")
    :set_keys("player_id","role_id")
    :set_index("age_index", "age")
    :set_index("role_name_index", "role_id", "nickname")
    :set_cache(500, 100)
    :builder(adapter)

    for i = 1, 100 do
        local rid = 1
        if i > 50 then
            rid = 2
        end
        ormobj:create_one_entry({player_id = i, role_id = rid, nickname = '' .. i, age = i})
    end

    --通过age查询
    local cursor = nil
    local limit = 10
    local sort = 1
    local count = 0
    local check = {}
    --升序查询
    for i = 1, 10 do
        local entry_list
        cursor, entry_list, count = ormobj:idx_get_entry_by_limit(cursor, limit, sort, "age")
        if i == 1 then
            assert(count == 100)
        end
        for _, entry in ipairs(entry_list) do
            local age = entry:get('age')
            assert(not check[age])
            check[age] = true
        end
        local age_f = entry_list[1]:get('age')
        local age_l = entry_list[10]:get('age')
        assert(age_l > age_f)
    end

    check = {}
    sort = -1
    cursor = nil
    --降序查询
    for i = 1, 10 do
        local entry_list
        cursor, entry_list, count = ormobj:idx_get_entry_by_limit(cursor, limit, sort, "age")
        if i == 1 then
            assert(count == 100)
        end
        for _, entry in ipairs(entry_list) do
            local age = entry:get('age')
            assert(not check[age])
            check[age] = true
        end
        local age_f = entry_list[1]:get('age')
        local age_l = entry_list[10]:get('age')
        assert(age_l < age_f)
    end

    check = {}
    sort = 1
    cursor = nil

    --通过role_id age查询
    for i = 1, 5 do
        local entry_list
        cursor, entry_list, count = ormobj:idx_get_entry_by_limit(cursor, limit, sort, "age", {role_id = 2})
        if i == 1 then
            assert(count == 50)
        end
        for _, entry in ipairs(entry_list) do
            local age = entry:get('age')
            assert(not check[age])
            check[age] = true
        end
        local age_f = entry_list[1]:get('age')
        local age_l = entry_list[10]:get('age')
        assert(age_l > age_f)
    end

    check = {}
    sort = -1   --降序
    cursor = nil

    --通过role_id age查询
    for i = 1, 5 do
        local entry_list
        cursor, entry_list, count = ormobj:idx_get_entry_by_limit(cursor, limit, sort, "age", {role_id = 2})
        if i == 1 then
            assert(count == 50)
        end
        for _, entry in ipairs(entry_list) do
            local age = entry:get('age')
            assert(not check[age])
            check[age] = true
        end
        local age_f = entry_list[1]:get('age')
        local age_l = entry_list[10]:get('age')
        assert(age_l < age_f)
    end

    check = {}
    sort = 1
    cursor = nil

    --通过role_id nickname查询
    for i = 1, 5 do
        local entry_list
        cursor, entry_list, count = ormobj:idx_get_entry_by_limit(cursor, limit, sort, "nickname", {role_id = 1})
        if i == 1 then
            assert(count == 50)
        end
        for _, entry in ipairs(entry_list) do
            local nickname = entry:get('nickname')
            assert(not check[nickname])
            check[nickname] = true
        end
        local age_f = entry_list[1]:get('nickname')
        local age_l = entry_list[10]:get('nickname')
        assert(age_l > age_f)
    end

    check = {}
    sort = -1
    cursor = nil

    --通过role_id nickname查询
    for i = 1, 5 do
        local entry_list
        cursor, entry_list, count = ormobj:idx_get_entry_by_limit(cursor, limit, sort, "nickname", {role_id = 1})
        if i == 1 then
            assert(count == 50)
        end
        for _, entry in ipairs(entry_list) do
            local nickname = entry:get('nickname')
            assert(not check[nickname])
            check[nickname] = true
        end
        local age_f = entry_list[1]:get('nickname')
        local age_l = entry_list[10]:get('nickname')
        assert(age_l < age_f)
    end

    check = {}
    sort = 1
    cursor = nil
    --通过role_id age查询
    for i = 1, 2 do
        local entry_list
        cursor, entry_list, count = ormobj:idx_get_entry_by_limit(cursor, limit, sort, "age", {role_id = 2, age = {['$gte'] = 61, ['$lte'] = 80}})
        if i == 1 then
            assert(count == 20)
        end
        for _, entry in ipairs(entry_list) do
            local age = entry:get('age')
            assert(not check[age])
            check[age] = true
        end
        local age_f = entry_list[1]:get('age')
        local age_l = entry_list[10]:get('age')
        assert(age_l > age_f)
    end

    check = {}
    sort = 1
    cursor = nil
    --通过role_id age查询
    for i = 1, 2 do
        local entry_list
        cursor, entry_list, count = ormobj:idx_get_entry_by_limit(cursor, limit, sort, "age", {role_id = 2, age = {['$gte'] = 61, ['$lte'] = 100}}, 10)
        if i == 1 then
            assert(count == 40)
        end
        for _, entry in ipairs(entry_list) do
            local age = entry:get('age')
            assert(not check[age])
            check[age] = true
        end
        local age_f = entry_list[1]:get('age')
        local age_l = entry_list[10]:get('age')
        assert(age_l > age_f)
    end

    delete_table()
end

--测试普通索引删除
local function test_idx_delete_entry()
    delete_table()
    local adapter = ormadapter_mysql:new("admin")
    local ormobj = ormtable:new("t_player")
    :int64("player_id")
    :int64("role_id")
    :string32("nickname")
    :uint8("age")
    :set_keys("player_id","role_id")
    :set_index("age_index", "age")
    :set_index("role_name_index", "role_id", "nickname")
    :set_cache(500, 100)
    :builder(adapter)

    for i = 1, 100 do
        local rid = 1
        if i > 50 then
            rid = 2
        end
        ormobj:create_one_entry({player_id = i, role_id = rid, nickname = '' .. i, age = i})
    end

    for i = 1, 2 do
        --删除age等于i
        local ret = ormobj:idx_delete_entry({age = i})
        assert(ret)

        local entry = ormobj:get_one_entry(i, 1)
        assert(not entry)

        local entry_list = ormobj:idx_get_entry({age = i})
        assert(#entry_list <= 0)

        --删除age >= 20 <=30
        local ret = ormobj:idx_delete_entry({age = {['$gte'] = 20, ['$lte'] = 30}})
        assert(ret)
        for i = 20, 30 do
            local entry_list = ormobj:idx_get_entry({age = i})
            assert(#entry_list <= 0)
        end
    end

    local ret = ormobj:idx_delete_entry({role_id = 1})
    assert(ret)

    local entry_list = ormobj:get_all_entry()
    assert(#entry_list == 50)

    delete_table()
end

--测试普通索引范围查询
local function test_idx_get_delete_entry_by_range()
    delete_table()
    local adapter = ormadapter_mysql:new("admin")
    local ormobj = ormtable:new("t_player")
    :int64("player_id")
    :int64("role_id")
    :string32("nickname")
    :uint8("age")
    :set_keys("player_id","role_id")
    :set_index("age_index", "age")
    :set_index("role_name_index", "role_id", "nickname")
    :set_cache(500, 100)
    :builder(adapter)

    for i = 1, 100 do
        local rid = 1
        if i > 50 then
            rid = 2
        end
        ormobj:create_one_entry({player_id = i, role_id = rid, nickname = '' .. i, age = i})
    end

    --测试查询
    for i = 1, 2 do
        --通过age查询
        local entry_list = ormobj:idx_get_entry({age = { ['$gte'] = 11, ['$lte'] = 20 }})
        assert(#entry_list == 10)

        local f_entry = entry_list[1]
        local l_entry = entry_list[10]
        assert(f_entry:get('age') == 11)
        assert(l_entry:get('age') == 20)

        local entry_list = ormobj:idx_get_entry({age = { ['$gte'] = 11}})
        assert(#entry_list == 90)

        local f_entry = entry_list[1]
        local l_entry = entry_list[90]
        assert(f_entry:get('age') == 11)
        assert(l_entry:get('age') == 100)

        local entry_list = ormobj:idx_get_entry({age = { ['$lte'] = 30 }})
        assert(#entry_list == 30)

        local f_entry = entry_list[1]
        local l_entry = entry_list[30]
        assert(f_entry:get('age') == 1)
        assert(l_entry:get('age') == 30)

        --通过role_id,age查询

        local entry_list = ormobj:idx_get_entry({role_id = 1, age = { ['$gte'] = 11, ['$lte'] = 20 }})
        assert(#entry_list == 10)

        local f_entry = entry_list[1]
        local l_entry = entry_list[10]
        assert(f_entry:get('age') == 11)
        assert(l_entry:get('age') == 20)

        local entry_list = ormobj:idx_get_entry({role_id = 1, age = { ['$gte'] = 11 }})
        assert(#entry_list == 40)
        local f_entry = entry_list[1]
        local l_entry = entry_list[40]
        assert(f_entry:get('age') == 11)
        assert(l_entry:get('age') == 50)

        local entry_list = ormobj:idx_get_entry({role_id = 2, age = { ['$lte'] = 30 }})
        assert(#entry_list == 0)
    end

    --测试删除
    for i = 1, 2 do
        --通过age删除
        local ret = ormobj:idx_delete_entry({age = { ['$gte'] = 11, ['$lte'] = 20 }})
        assert(ret)
        local entry = ormobj:get_one_entry(11, 1)
        assert(not entry)

        local ret = ormobj:idx_delete_entry({age = { ['$gte'] = 90}})
        assert(ret)
        local entry = ormobj:get_one_entry(100, 2)
        assert(not entry)

        local ret = ormobj:idx_delete_entry({age = { ['$lte'] = 30}})
        assert(ret)
        local entry = ormobj:get_one_entry(29, 1)
        assert(not entry)

        --通过role_id,age删除
        local ret = ormobj:idx_delete_entry({role_id = 1, age = { ['$gte'] = 50, ['$lte'] = 50 }})
        assert(ret)
        local entry = ormobj:get_one_entry(50, 1)
        assert(not entry)

        local ret = ormobj:idx_delete_entry({role_id = 2, age = { ['$gte'] = 80}})
        assert(ret)
        local entry = ormobj:get_one_entry(80, 2)
        assert(not entry)


        local ret = ormobj:idx_delete_entry({role_id = 2, age = {['$lte'] = 60 }})
        assert(ret)
        local entry = ormobj:get_one_entry(60, 2)
        assert(not entry)
    end

    delete_table()
end

function CMD.start()
    skynet.fork(function()
        delete_table()
        log.info("test start >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>")
        log.info("test_create_table>>>>>")
        test_create_table(true)
        log.info("test_alter_table>>>>>")
        test_alter_table()
        log.info("test_create_entry>>>>>")
        test_create_entry()
        log.info("test_select_entry>>>>>")
        test_select_entry()
        log.info("test_save_entry>>>>>")
        test_save_entry()
        log.info("test_delete_entry>>>>>")
        test_delete_entry()
        log.info("test_cache_entry>>>>>")
        test_cache_entry()
        log.info("test_inval_save>>>>>")
        test_inval_save()
        log.info("test_sql_over>>>>>")
        test_sql_over()
        log.info("test_over_clear_time>>>>>")
        test_over_clear_time()
        log.info("test_permanent>>>>>")
        test_permanent()
        log.info("test_get_all>>>>>")
        test_get_all()
        log.info("test_delete_all>>>>>")
        test_delete_all()
        log.info("test_craete_one>>>>>")
        test_craete_one()
        log.info("test_select_one>>>>>")
        test_select_one()
        log.info("test_disconnect>>>>>")
        test_disconnect()
        log.info("test_tti>>>>>")
        test_tti()
        log.info("test_invalid_entry>>>>>")
        test_invalid_entry()
        log.info("test_every_cache>>>>>")
        test_every_cache()
        log.info("test_inval_save_del>>>>>")
        test_inval_save_del()
        log.info("stress_testing")
        stress_testing()
        log.info("test_get_entry_in")
        test_get_entry_in()
        log.info("test_get_entry_limit")
        test_get_entry_limit()
        log.info("test_delete_by_range")
        test_delete_by_range()
        log.info("test_quete_key_values")
        test_quete_key_values()
        log.info("test_table_type")
        test_table_type()
        log.info("test_delete_in cache")
        test_delete_in(true)
        log.info("test_delete_in not cache")
        test_delete_in()
        log.info("test_batch_delete")
        test_batch_delete()
        log.info("test_batch_range_delete")
        test_batch_range_delete()
        log.info("test_create_change_index")
        test_create_change_index()
        log.info("test_idx_get_entry")
        test_idx_get_entry()
        log.info("test_idx_get_entry_by_limit")
        test_idx_get_entry_by_limit()
        log.info("test_idx_delete_entry")
        test_idx_delete_entry()
        log.info("test_idx_get_delete_entry_by_range")
        test_idx_get_delete_entry_by_range()
        delete_table()
        log.info("test over >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>")
    end)
    return true
end

function CMD.exit()
    return true
end

return CMD