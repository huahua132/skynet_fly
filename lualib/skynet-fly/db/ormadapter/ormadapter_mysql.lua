---#API
---#content ---
---#content title: orm mysql适配器
---#content date: 2024-06-29 22:00:00
---#content categories: ["skynet_fly API 文档","数据库相关"]
---#content category_bar: true
---#content tags: [skynet_fly_api]
---#content ---
---#content [ormadapter_mysql](https://github.com/huahua132/skynet_fly/blob/master/lualib/skynet-fly/db/ormadapter/ormadapter_mysql.lua)

local contriner_client = require "skynet-fly.client.contriner_client"
local table_util = require "skynet-fly.utils.table_util"
local string_util = require "skynet-fly.utils.string_util"
local mysqli = require "skynet-fly.db.mysqli"
local log = require "skynet-fly.log"
local json = require "cjson"

local FIELD_TYPE = require "skynet-fly.db.orm.ormtable".FIELD_TYPE
local FIELD_LUA_DEFAULT = require "skynet-fly.db.orm.ormtable".FIELD_LUA_DEFAULT

local setmetatable = setmetatable
local sfind = string.find
local sformat = string.format
local assert = assert
local tconcat = table.concat
local pairs = pairs
local error = error
local next = next
local tunpack = table.unpack
local type = type
local tonumber = tonumber
local tinsert = table.insert
local tremove = table.remove
local tsort = table.sort
local pcall = pcall
local math = math
local schar = string.char

local FIELD_TYPE_SQL_TYPE = {
    [FIELD_TYPE.int8] = "tinyint",
    [FIELD_TYPE.int16] = "smallint",
    [FIELD_TYPE.int32] = "int",
    [FIELD_TYPE.int64] = "bigint",
    [FIELD_TYPE.uint8] = "tinyint unsigned",
    [FIELD_TYPE.uint16] = "smallint unsigned",
    [FIELD_TYPE.uint32] = "int unsigned",

    [FIELD_TYPE.string32] = "varchar(32)",
    [FIELD_TYPE.string64] = "varchar(64)",
    [FIELD_TYPE.string128] = "varchar(128)",
    [FIELD_TYPE.string256] = "varchar(256)",
    [FIELD_TYPE.string512] = "varchar(512)",
    [FIELD_TYPE.string1024] = "varchar(1024)",
    [FIELD_TYPE.string2048] = "varchar(2048)",
    [FIELD_TYPE.string4096] = "varchar(4096)",
    [FIELD_TYPE.string8192] = "varchar(8192)",

    [FIELD_TYPE.text] = "text",
    [FIELD_TYPE.blob] = "blob",
    [FIELD_TYPE.table] = "blob",
}

local FIELD_TYPE_LUA_TYPE = {}

do 
    for type,name in pairs(FIELD_TYPE_SQL_TYPE) do
        FIELD_TYPE_LUA_TYPE[name] = type
    end
end

local function new_prepare_obj(prepare_str)
    local t = {
        prepare_str = prepare_str,
    }

    return t
end

local function get_stmt(db, prepare_obj)
    if not prepare_obj.stmt then
        local ret = db.conn:prepare(prepare_obj.prepare_str)
        if ret.err then
            error(ret.err)
        end
        prepare_obj.stmt = ret
    end
    return prepare_obj.stmt
end

local function prepare_execute(db, prepare_obj, ...)
    local stmt = get_stmt(db, prepare_obj)
    local ret = db.conn:execute(stmt, ...)
    if ret.err and sfind(ret.err, "Unknown prepared", nil, true) then
        prepare_obj.stmt = nil
        stmt = get_stmt(db, prepare_obj)
    else
        return ret
    end
    
    return db.conn:execute(stmt, ...)
end

local M = {}
local mata = {__index = M}

---#desc 新建适配器对象
---@param db_name? string 对应share_config_m 中写的key为mysql表的名为db_name的连接配置
---@param db? table 可选自己传入连接对象
---@return table obj
function M:new(db_name, db)
    local t = {
        _db = db or mysqli.new_client(db_name),
        _tab_name = nil,
        _field_list = nil,
        _field_map = nil,
        _key_list = nil,
        _tab_encode = json.encode,
        _tab_decode = json.decode,
        batch_insert_num = 10,
        batch_update_num = 10,
        batch_delete_num = 10,
    }

    setmetatable(t, mata)

    return t
end

---#desc 设置单次整合批量插入的数量
---@param num number 数量 默认10
---@return table obj
function M:set_batch_insert_num(num)
    assert(num > 0)
    self.batch_insert_num = num
    return self
end

---#desc 设置单次整合批量更新的数量
---@param num number 数量 默认10
---@return table obj
function M:set_batch_update_num(num)
    assert(num > 0)
    self.batch_update_num = num
    return self
end

---#desc 设置单次整合批量删除的数量
---@param num number 数量 默认10
---@return table obj
function M:set_batch_delete_num(num)
    assert(num > 0)
    self.batch_delete_num = num
    return self
end

---#desc 设置table类型的打包解包函数
---@param encode function 默认json
---@param decode function 默认json
---@return table obj
function M:set_table_pack(encode, decode)
    self._tab_encode = encode
    self._tab_decode = decode
    return self
end

local function create_table(t)
    local field_list = t._field_list
    local field_map = t._field_map
    local key_list = t._key_list
    local indexs_list = t._indexs_list

    local sql_str = sformat("create table %s (\n", t._tab_name)
    for i = 1,#field_list do
        local field_name = field_list[i]
        local field_type = field_map[field_name]
        local convert_type = assert(FIELD_TYPE_SQL_TYPE[field_type],"unknown type : " .. field_type)
        if field_type == FIELD_TYPE.text or field_type == FIELD_TYPE.blob or field_type == FIELD_TYPE.table then          --text 和 blob类型不支持指定默认值
            sql_str = sql_str .. sformat("\t`%s` %s,\n", field_name, convert_type)
        else
            sql_str = sql_str .. sformat("\t`%s` %s NOT NULL DEFAULT '%s',\n", field_name, convert_type, FIELD_LUA_DEFAULT[field_type])
        end
    end

    for index_name, list in pairs(indexs_list) do
        sql_str = sql_str .. sformat("\tINDEX `%s` (%s),\n", index_name, tconcat(list, ','))
    end

    sql_str = sql_str .. sformat("\tprimary key(%s)\n", tconcat(key_list,','))
    sql_str = sql_str .. ');'

    local ret = t._db.conn:query(sql_str)
    if not ret then
        error("create table err", sql_str) 
    elseif ret.err then
        log.error("create table err ",ret.err, sql_str)
        error("create table err ")
    end
end

local function alter_table(t, describe, index_info)
    local field_list = t._field_list
    local field_map = t._field_map
    local key_list = t._key_list
    local indexs_list = t._indexs_list

    local key_sort_map = {}
    for i = 1,#field_list do
        key_sort_map[field_list[i]] = i
    end

    local pre_key_list = {}
    local pre_indexs_list = {}

    for i = 1,#index_info do
        local info = index_info[i]
        local column_name = info.Column_name
        local key_name = info.Key_name
        local seq_in_index = info.Seq_in_index
        local non_unique = info.Non_unique
        if key_name == 'PRIMARY' then   --主键
            pre_key_list[seq_in_index] = column_name
        else
            --普通索引
            if non_unique == 1 then
                if not pre_indexs_list[key_name] then
                    pre_indexs_list[key_name] = {}
                end
                pre_indexs_list[key_name][seq_in_index] = column_name
            end
        end
    end

    local def = table_util.check_def_table(key_list, pre_key_list)
    assert(not next(def),"can`t change keys " .. table_util.def_tostring(def))     --不能修改主键

    -- 不能修改字段类型
    local pre_field_map = {}
    for i = 1,#describe do
        local one_des = describe[i]
        local tp = one_des.Type:gsub("(%a*)int%(%d+%)", "%1int")
        local field_name = one_des.Field
        local lua_type = assert(FIELD_TYPE_LUA_TYPE[tp],"not exists type " .. tp)
        pre_field_map[field_name] = lua_type
    end

    local def = table_util.check_def_table(field_map, pre_field_map)
    local new_field_list = {} 
    for field_name,def_info in pairs(def) do
        if def_info._flag == "add" then
            tinsert(new_field_list,field_name)
        elseif def_info._flag == "valuedef" then
            if (def_info._new == FIELD_TYPE.blob and def_info._old == FIELD_TYPE.table) or
            (def_info._new == FIELD_TYPE.table and def_info._old == FIELD_TYPE.blob) then
            else
                error("can`t change type " .. field_name .. ' new:' .. def_info._new .. ' old:' .. def_info._old) --不能修改类型
            end
        end
    end

    --新增字段
    if next(new_field_list) then
        local sql_str = sformat("alter table %s\n", t._tab_name)
        for _,field_name,is_end in table_util.sort_ipairs(new_field_list, function(a, b) return key_sort_map[a] < key_sort_map[b] end) do
            local field_type = field_map[field_name]
            local convert_type = assert(FIELD_TYPE_SQL_TYPE[field_type],"unknown type : " .. field_type)
            if not is_end then
                if field_type == FIELD_TYPE.text or field_type == FIELD_TYPE.blob or field_type == FIELD_TYPE.table then
                    sql_str = sql_str .. sformat("add `%s` %s,\n", field_name, convert_type)
                else
                    sql_str = sql_str .. sformat("add `%s` %s NOT NULL DEFAULT '%s',\n", field_name, convert_type, FIELD_LUA_DEFAULT[field_type])
                end
            else
                if field_type == FIELD_TYPE.text or field_type == FIELD_TYPE.blob or field_type == FIELD_TYPE.table then
                    sql_str = sql_str .. sformat("add `%s` %s;\n", field_name, convert_type)
                else
                    sql_str = sql_str .. sformat("add `%s` %s NOT NULL DEFAULT '%s';\n", field_name, convert_type, FIELD_LUA_DEFAULT[field_type])
                end
            end
        end

        local ret = t._db.conn:query(sql_str)
        if not ret then
            log.error("alter_table err ",sql_str)
            error("alter_table table err")
        elseif ret.err then
            log.error("alter_table err ",ret,sql_str)
            error("alter_table table err ")
        end
    end

    --新增修改删除普通索引
    local def = table_util.check_def_table(indexs_list, pre_indexs_list)
    local del_index_map = {}
    local add_index_map = {}
    for index_name,def_info in pairs(def) do
        if def_info._flag == 'reduce' then  --删除索引
            del_index_map[index_name] = true
        elseif def_info._flag == 'add' then --新增索引
            add_index_map[index_name] = true
        else
            log.error("alter_table err", index_name, def_info)
            error("alter_table can`t change index")
        end
    end

    --删除索引
    for index_name in pairs(del_index_map) do
        log.warn_fmt("%s del index[%s]", t._tab_name, index_name)
        local sql_str = sformat('DROP INDEX `%s` ON %s;', index_name, t._tab_name)
        local ret = t._db.conn:query(sql_str)
        if not ret then
            log.error("alter_table del index err ",sql_str)
            error("alter_table del index err")
        elseif ret.err then
            log.error("alter_table del index err ",ret,sql_str)
            error("alter_table del index err ")
        end
    end

    --新增索引
    for index_name in pairs(add_index_map) do
        local list = indexs_list[index_name]
        local field_list_str = tconcat(list, ',')
        log.warn_fmt("%s add index[%s] field_list(%s)", t._tab_name, index_name, field_list_str)
        local sql_str = sformat('CREATE INDEX `%s` ON %s (%s);', index_name, t._tab_name, field_list_str)
        local ret = t._db.conn:query(sql_str)
        if not ret then
            log.error("alter_table add index err ",sql_str)
            error("alter_table add index err")
        elseif ret.err then
            log.error("alter_table add index err ",ret,sql_str)
            error("alter_table add index err ")
        end
    end
end
-- 构建表
function M:builder(tab_name, field_list, field_map, key_list, indexs_list)
    self._tab_name = tab_name
    self._field_map = field_map
    self._key_list = key_list
    self._field_list = field_list
    self._indexs_list = indexs_list

    local tab_encode = self._tab_encode
    local tab_decode = self._tab_decode
    local table_field_list = {}
    -- 查询表的字段信息
    local describe = self._db.conn:query("DESCRIBE " .. tab_name)
    assert(describe, "not describe ret " .. tab_name)
    if describe.err then
        assert(sfind(describe.err, "doesn't exist", nil, true), "unknown")
        --不存在 创建
        create_table(self)
    else
        --存在 检查变更
        local index_info = self._db.conn:query("show index from " .. tab_name)
        assert(index_info, "can`t get index_info ")
        alter_table(self, describe, index_info)
    end

    local field_index_map = {}

    local insert_format_head = sformat("insert into %s (",tab_name)
    local insert_format_end = "("
    local select_format_head = sformat("select ")
    local select_format_key_head = sformat("select ")
    local select_format_center = " where "
    local select_format_end = ""
    local select_format_end_list = {}
    local update_format_head = sformat("update %s set ",tab_name)
    local update_format_head_list = {}
    local update_format_end = " where "
    local updates_format_end = " where("
    local updates_format_key = "("
    local delete_format_head = sformat("delete from %s",tab_name)
    local desc_key_str = ""
    local asc_key_str = ""

    local len = #field_list
    for i = 1,len do
        local field_name = field_list[i]
        local field_type = field_map[field_name]
        update_format_head_list[i] = '`' .. field_name .. "`=?,"
        if i == len then
            insert_format_end = insert_format_end .. "?" 
        else
            insert_format_end = insert_format_end .. "?,"
        end

        if i == len then
            insert_format_head = insert_format_head .. '`' .. field_name .. '`'
            select_format_head = select_format_head .. '`' .. field_name .. '`'
        else
            insert_format_head = insert_format_head .. '`' .. field_name .. '`,'
            select_format_head = select_format_head .. '`' .. field_name .. '`,'
        end
        
        field_index_map[field_name] = i

        if field_type == FIELD_TYPE.table then
            tinsert(table_field_list, field_name)
        end
    end

    local table_field_len = #table_field_list

    len = #key_list
    for i = 1,len do
        local field_name = key_list[i]
        if i == len then
            select_format_end = select_format_end .. '`' .. field_name .. '`=' .. "?"
            update_format_end = update_format_end .. '`' .. field_name .. '`=' .. "?;"
            select_format_key_head = select_format_key_head .. '`' .. field_name .. '`'
            updates_format_end = updates_format_end .. '`' .. field_name .. '`)'
            updates_format_key = updates_format_key .. '?)'
            desc_key_str = desc_key_str .. '`' .. field_name .. '` desc '
            asc_key_str = asc_key_str .. '`' .. field_name .. '` desc '
        else
            select_format_end = select_format_end .. '`' .. field_name .. '`=' .. "?"
            update_format_end = update_format_end .. '`' .. field_name .. '`=' .. "? and "
            select_format_key_head = select_format_key_head .. '`' .. field_name .. '`,'
            updates_format_end = updates_format_end .. '`' .. field_name .. '`,'
            updates_format_key = updates_format_key .. '?,'
            desc_key_str = desc_key_str .. '`' .. field_name .. '` desc,'
            asc_key_str = asc_key_str .. '`' .. field_name .. '` desc,'
        end
       
        select_format_end_list[i] = select_format_end
        select_format_end = select_format_end .. ' and '
    end

    insert_format_head = insert_format_head .. ') value'
    insert_format_end = insert_format_end .. ')'
    select_format_key_head = select_format_key_head .. ' from ' .. tab_name
    select_format_head = select_format_head .. ' from ' .. tab_name

    --insert prepare 处理
    local insert_prepare_list = {}
    for i = 1, self.batch_insert_num do
        local end_str = ""
        for j = 1, i do
            if j ~= i then
                end_str = end_str .. insert_format_end .. ','
            else
                end_str = end_str .. insert_format_end
            end
        end

        insert_prepare_list[i] = new_prepare_obj(insert_format_head .. end_str)
    end

    insert_format_head = nil
    insert_format_end = nil

    --select prepare 处理
    local select_prepare_list = {}
    select_prepare_list[0] = new_prepare_obj(select_format_head)
    for i = 1, len do
        select_prepare_list[i] = new_prepare_obj(select_format_head .. select_format_center .. select_format_end_list[i])
    end

    -- select * from player where key1 in (?);
    -- select * from player where key1=?,key2 in (?);
    -- select * from player where key1=?,key2=?,key3 in (?);
    --select in prepare 处理
    local select_in_prepare_list = {}
    for i = 1, len do
        local end_field_name = key_list[i]
        if i == 1 then
            select_in_prepare_list[i] = sformat("%s%s`%s` in ", select_format_head, select_format_center, end_field_name)
        else
            select_in_prepare_list[i] = sformat("%s%s%s and `%s` in ", select_format_head, select_format_center, select_format_end_list[i - 1], end_field_name)
        end
    end

    --select limit prepare 处理
    --select * from player where key1 > ? order by ? desc limit ?
    --select * from player where key1 < ? order by ? limit ?
    local count_sql = nil
    if len == 1 then
        count_sql = sformat("select count(*) from %s;", self._tab_name)
    else
        count_sql = sformat("select count(*) from %s where %s;", self._tab_name, select_format_end_list[len - 1])
    end
    local select_limit_desc_pre_pare
    local select_limit_pre_pare
    local select_limit_k_desc_pre_pare
    local select_limit_k_pre_pare
    local select_f_limit_desc_pre_pare
    local select_f_limit_pre_pare
    local select_f_limit_k_desc_pre_pare
    local select_f_limit_k_pre_pare

    local select_count_pre_pare
    
    local end_field_name = key_list[len]
    if len == 1 then
        select_limit_desc_pre_pare = new_prepare_obj(sformat("%s%s`%s` < ? order by `%s` desc limit ?", select_format_head, select_format_center, end_field_name, end_field_name))
        select_limit_pre_pare = new_prepare_obj(sformat("%s%s`%s` > ? order by `%s` limit ?", select_format_head, select_format_center, end_field_name, end_field_name))
        select_limit_k_desc_pre_pare = new_prepare_obj(sformat("%s%s`%s` < ? order by `%s` desc limit ?", select_format_key_head, select_format_center, end_field_name, end_field_name))
        select_limit_k_pre_pare = new_prepare_obj(sformat("%s%s`%s` > ? order by `%s` limit ?", select_format_key_head, select_format_center, end_field_name, end_field_name))

        select_f_limit_desc_pre_pare = new_prepare_obj(sformat("%s order by `%s` desc limit ?", select_format_head, end_field_name))
        select_f_limit_pre_pare = new_prepare_obj(sformat("%s order by `%s` limit ?", select_format_head, end_field_name))
        select_f_limit_k_desc_pre_pare = new_prepare_obj(sformat("%s order by `%s` desc limit ?", select_format_key_head, end_field_name))
        select_f_limit_k_pre_pare = new_prepare_obj(sformat("%s order by `%s` limit ?", select_format_key_head, end_field_name))
    else
        select_limit_desc_pre_pare = new_prepare_obj(sformat("%s%s%s and `%s` < ? order by `%s` desc limit ?", select_format_head, select_format_center, select_format_end_list[len - 1], end_field_name, end_field_name))
        select_limit_pre_pare = new_prepare_obj(sformat("%s%s%s and `%s` > ? order by `%s` limit ?", select_format_head, select_format_center, select_format_end_list[len - 1], end_field_name, end_field_name))
        select_limit_k_desc_pre_pare = new_prepare_obj(sformat("%s%s%s and `%s` < ? order by `%s` desc limit ?", select_format_key_head, select_format_center, select_format_end_list[len - 1], end_field_name, end_field_name))
        select_limit_k_pre_pare = new_prepare_obj(sformat("%s%s%s and `%s` > ? order by `%s` limit ?", select_format_key_head, select_format_center, select_format_end_list[len - 1], end_field_name, end_field_name))

        select_f_limit_desc_pre_pare = new_prepare_obj(sformat("%s%s%s order by `%s` desc limit ?", select_format_head, select_format_center, select_format_end_list[len - 1], end_field_name))
        select_f_limit_pre_pare = new_prepare_obj(sformat("%s%s%s order by `%s` limit ?", select_format_head, select_format_center, select_format_end_list[len - 1], end_field_name))
        select_f_limit_k_desc_pre_pare = new_prepare_obj(sformat("%s%s%s order by `%s` desc limit ?", select_format_key_head, select_format_center, select_format_end_list[len - 1], end_field_name))
        select_f_limit_k_pre_pare = new_prepare_obj(sformat("%s%s%s order by `%s` limit ?", select_format_key_head, select_format_center, select_format_end_list[len - 1], end_field_name))
    end

    
    select_count_pre_pare = new_prepare_obj(count_sql)
    -- delete from player where key1 in (?);
    -- delete from player where key1=?,key2 in (?);
    -- delete from player where key1=?,key2=?,key3 in (?);
    --delete in prepare 处理
    local delete_in_prepare_list = {}
    for i = 1, len do
        local end_field_name = key_list[i]
        if i == 1 then
            delete_in_prepare_list[i] = sformat("%s%s`%s` in ", delete_format_head, select_format_center, end_field_name)
        else
            delete_in_prepare_list[i] = sformat("%s%s%s and `%s` in ", delete_format_head, select_format_center, select_format_end_list[i - 1], end_field_name)
        end
    end

    select_format_key_head = nil
    count_sql = nil
    select_format_end = nil

    --update prepare
    local update_pre_pare_map = {}
    local function get_update_pre_pare(change_map)
        local index_list = {}
        for field_name in pairs(change_map) do
            local index = field_index_map[field_name]
            tinsert(index_list, index)
        end
        tsort(index_list)
        local indexs_str = tconcat(index_list, '')
        if not update_pre_pare_map[indexs_str] then
            local sql_str = update_format_head
            for i = 1, #index_list do
                local index = index_list[i]
                sql_str = sql_str .. update_format_head_list[index]
            end
            sql_str = sql_str:sub(1,sql_str:len() - 1) .. update_format_end
            update_pre_pare_map[indexs_str] = new_prepare_obj(sql_str)
        end

        return update_pre_pare_map[indexs_str], index_list
    end

    --delete prepare
    local delete_prepare_list = {}
    local batch_delete_prepare_list = {}
    
    delete_prepare_list[0] = new_prepare_obj(delete_format_head)
    for i = 1, len do
        local one_str = delete_format_head .. select_format_center .. '(' .. select_format_end_list[i] .. ')'
        delete_prepare_list[i] = new_prepare_obj(one_str)

        if not batch_delete_prepare_list[i] then
            batch_delete_prepare_list[i] = {}
        end
        batch_delete_prepare_list[i][1] = delete_prepare_list[i]
        local batch_str = one_str
        for j = 2, self.batch_delete_num do
            batch_str = batch_str .. ' or ' .. '(' .. select_format_end_list[i] .. ')'
            batch_delete_prepare_list[i][j] = new_prepare_obj(batch_str)
        end
    end

    --delete byrange prepare
    --delete from player where key1=? and key2>=? and key2<=?;
    --delete from player where key1=? and key2>=?;
    --delete from player where key1=? and key2<=?;
    local delete_range_prepare_list_b = {}          --大于等于
    local delete_range_prepare_list_s = {}          --小于等于
    local delete_range_prepare_list_c = {}          --大于等于 and 小于等于

    local batch_delete_range_prepare_list_b = {}
    local batch_delete_range_prepare_list_s = {}
    local batch_delete_range_prepare_list_c = {}
    for i = 1, len do
        local end_field_name = key_list[i]
        if i == 1 then
            delete_range_prepare_list_b[i] = new_prepare_obj(sformat("%s%s`%s`>=?", delete_format_head, select_format_center, end_field_name))
            delete_range_prepare_list_s[i] = new_prepare_obj(sformat("%s%s`%s`<=?", delete_format_head, select_format_center, end_field_name))
            delete_range_prepare_list_c[i] = new_prepare_obj(sformat("%s%s`%s`>=? and `%s` <=?", delete_format_head, select_format_center, end_field_name, end_field_name))
        else
            delete_range_prepare_list_b[i] = new_prepare_obj(sformat("%s%s%s and `%s`>=?", delete_format_head, select_format_center, select_format_end_list[i-1], end_field_name))
            delete_range_prepare_list_s[i] = new_prepare_obj(sformat("%s%s%s and `%s`<=?", delete_format_head, select_format_center, select_format_end_list[i-1], end_field_name))
            delete_range_prepare_list_c[i] = new_prepare_obj(sformat("%s%s%s and `%s`>=? and `%s` <=?", delete_format_head, select_format_center, select_format_end_list[i-1], end_field_name, end_field_name))

            if not batch_delete_range_prepare_list_c[i] then
                batch_delete_range_prepare_list_b[i] = {}
                batch_delete_range_prepare_list_s[i] = {}
                batch_delete_range_prepare_list_c[i] = {}
            end

            local batch_str_b = delete_format_head .. select_format_center
            local batch_str_s = delete_format_head .. select_format_center
            local batch_str_c = delete_format_head .. select_format_center
            for j = 1, self.batch_delete_num do
                batch_str_b = batch_str_b .. sformat("(%s and `%s`>=?)", select_format_end_list[i-1], end_field_name)
                batch_delete_range_prepare_list_b[i][j] = new_prepare_obj(batch_str_b)
                batch_str_b = batch_str_b .. ' or '

                batch_str_s = batch_str_s .. sformat("(%s and `%s`<=?)", select_format_end_list[i-1], end_field_name)
                batch_delete_range_prepare_list_s[i][j] = new_prepare_obj(batch_str_s)
                batch_str_s = batch_str_s .. ' or '

                batch_str_c = batch_str_c .. sformat("(%s and `%s`>=? and `%s`<=?)", select_format_end_list[i-1], end_field_name, end_field_name)
                batch_delete_range_prepare_list_c[i][j] = new_prepare_obj(batch_str_c)
                batch_str_c = batch_str_c .. ' or '
            end
        end
    end

    local insert_list = {}                               
    local function entry_data_to_list(entry_data, add_list)
        for i = 1,#field_list do
            local fn = field_list[i]
            local field_type = field_map[fn]
            local fv = entry_data[fn]
            if field_type == FIELD_TYPE.table then
                fv = tab_encode(fv)
            end
            if not add_list then
                insert_list[i] = fv
            else
                add_list[#add_list + 1] = fv
            end
        end
        return insert_list
    end

    --解包查询结果的table
    local function decode_tables(sql_ret)
        if table_field_len <= 0 then return end
        for i = 1,#sql_ret do
            local one_ret = sql_ret[i]
            for j = 1, table_field_len do
                local fn = table_field_list[j]
                local v = one_ret[fn]
                if v then
                    one_ret[fn] = tab_decode(v)
                end
            end
        end
    end

    --insert 批量插入
    self._insert = function(entry_data_list)
         --批量插入
         local res_list = {}
         local ref_list = {}
         local cur = 1
         local ret_index = 1
         local len = #entry_data_list
         while true do
            if cur > len then break end
            local add_list = {}
            local cnt = 0
            for j = 1, self.batch_insert_num do
                local entry_data = entry_data_list[cur]
                if entry_data then
                    entry_data_to_list(entry_data, add_list)
                    ref_list[j] = entry_data
                    cur = cur + 1
                    cnt = cnt + 1
                else
                    break 
                end
            end
 
            if cnt <= 0 then break end
            local prepare_obj = insert_prepare_list[cnt]
            local isok, ret = pcall(prepare_execute, self._db, prepare_obj, tunpack(add_list))
            if isok and ret and not ret.err then
                for i = 1, cnt do
                    res_list[ret_index] = true
                    ret_index = ret_index + 1
                end
            else
                log.error("_insert err ", self._tab_name, ret, ref_list)
                for i = 1, cnt do
                    res_list[ret_index] = false
                    ret_index = ret_index + 1
                end
             end
         end
 
         return res_list
    end

    --insert_one插入单条
    self._insert_one = function(entry_data)
        local prepare_obj = insert_prepare_list[1]
        local add_list = entry_data_to_list(entry_data)
        local isok, ret = pcall(prepare_execute, self._db, prepare_obj, tunpack(add_list))
        if not isok or not ret or ret.err then
            log.error("_insert_one err ", ret, entry_data)
            error("_insert_one err ")
        end
        return true
    end

    --select 查询
    self._select = function(key_values)
        local len = #key_values
        assert(len >= 0 and len <= #key_list, "err key_values len " .. len)
        local prepare_obj = select_prepare_list[len]
        local isok, ret = pcall(prepare_execute, self._db, prepare_obj, tunpack(key_values))
        if not isok or not ret or ret.err then
            log.error("_select err ", ret, key_values)
            error("_select err ")
        end

        decode_tables(ret)
        return ret
    end

    --查询一条数据
    local keys_max_len = #key_list
    self._select_one = function(key_values)
        local prepare_obj = select_prepare_list[keys_max_len]
        local isok, ret = pcall(prepare_execute, self._db, prepare_obj, tunpack(key_values))
        if not isok or not ret or ret.err then
            log.error("_select_one err ", ret, key_values)
            error("_select_one err ")
        end

        decode_tables(ret)
        return ret[1]
    end

    --IN 查询
    self._select_in = function(in_values, key_values)
        local len = #key_values
        local prepare_str = select_in_prepare_list[len + 1]
        prepare_str = prepare_str .. '('
        local in_len = #in_values

        local args = {}
        for i = 1, len do
            args[#args + 1] = key_values[i]  
        end
        for i = 1, in_len do
            if i == in_len then
                prepare_str = prepare_str .. '?'
            else
                prepare_str = prepare_str .. '?,'
            end
            args[#args + 1] = in_values[i]
        end
        prepare_str = prepare_str .. ')'
        local prepare_obj = new_prepare_obj(prepare_str)
        local isok, ret = pcall(prepare_execute, self._db, prepare_obj, tunpack(args))
        
        local stmt = prepare_obj.stmt
        if stmt then
            pcall(self._db.conn.stmt_close, self._db.conn, stmt)
        end
        if not isok or not ret or ret.err then
            log.error("_select_in err ", ret, key_values)
            error("_select_in err ")
        end

        decode_tables(ret)
        return ret
    end

    --分页 查询
    self._select_limit = function(cursor, limit, sort, key_values, is_only_key)
        local len = #key_values
        local end_field_name = key_list[len + 1]
        local prepare_obj = nil

        local args = {}
        if not cursor then
            if is_only_key then
                if sort == 1 then  --升序
                    prepare_obj = select_f_limit_k_pre_pare
                else
                    prepare_obj = select_f_limit_k_desc_pre_pare
                end
            else
                if sort == 1 then  --升序
                    prepare_obj = select_f_limit_pre_pare
                else
                    prepare_obj = select_f_limit_desc_pre_pare
                end
            end
        else
            if is_only_key then
                if sort == 1 then  --升序
                    prepare_obj = select_limit_k_pre_pare
                else
                    prepare_obj = select_limit_k_desc_pre_pare
                end
            else
                if sort == 1 then  --升序
                    prepare_obj = select_limit_pre_pare
                else
                    prepare_obj = select_limit_desc_pre_pare
                end
            end
        end
       
        local count = nil
        --拿一下count
        if not cursor then
            local isok, ret = pcall(prepare_execute, self._db, select_count_pre_pare, tunpack(key_values))
            if not isok or not ret or ret.err then
                log.error("_select_limit err ", ret, key_values)
                error("_select_limit err ")
            end
            count = ret[1]["count(*)"]
        end

        --where参数
        for i = 1, len do
            args[#args + 1] = key_values[i]
        end
        if cursor then
            args[#args + 1] = cursor
        end
        args[#args + 1] = limit

        local isok, ret = pcall(prepare_execute, self._db, prepare_obj, tunpack(args))
        
        if not isok or not ret or ret.err then
            log.error("_select_limit err ", ret, key_values)
            error("_select_limit err ")
        end
        
        local cursor = nil
        if #ret > 0 then
            local end_ret = ret[#ret]
            cursor = end_ret[end_field_name]
        end
        decode_tables(ret)
        return cursor, ret, count
    end

    --update 更新
    self._update = function(entry_data_list,change_map_list)
        local res_list = {}
        local cur = 1
        local ret_index = 1
        local len = #entry_data_list
        local min_len = self.batch_update_num
        if len < min_len then
            min_len = len
        end

        while true do
            if cur > len then break end
            local updates = {}
            local changes = {}
            local field_name_map = {}
            local fcnt = 0
            for i = 1, self.batch_update_num do
                local entry_data = entry_data_list[cur]
                local change_map = change_map_list[cur]
                cur = cur + 1
                if entry_data then
                    for field_name in pairs(change_map) do
                        if not field_name_map[field_name] then
                            field_name_map[field_name] = {}
                            fcnt = fcnt + 1
                        end
                        local field_n_list = field_name_map[field_name]
                        field_n_list[#field_n_list + 1] = entry_data
                    end
                    
                    updates[i] = entry_data
                    changes[i] = change_map
                else
                    break
                end
            end

            local prepare_str = update_format_head
            local args = {}
            local key_len = #key_list
            local center_str = select_format_end_list[key_len]
            local ucnt = 0
            for field_name, list in pairs(field_name_map) do
                ucnt = ucnt + 1
                prepare_str = prepare_str .. '`' .. field_name .. '`=case\n'
                for i = 1, #list do
                    prepare_str = prepare_str .. "when " .. center_str .. " then ?\n"
                    local entry_data = list[i]
                    for j = 1, key_len do
                        local kn = key_list[j]
                        local kv = entry_data[kn]
                        args[#args + 1] = kv
                    end

                    local fv = entry_data[field_name]
                    local ft = field_map[field_name]
                    if ft == FIELD_TYPE.table then
                        fv = tab_encode(fv)
                    end
                    args[#args + 1] = fv
                end

                if ucnt < fcnt then
                    prepare_str = prepare_str .. 'else `' .. field_name .. '`\n end,\n'
                else
                    prepare_str = prepare_str .. 'else `' .. field_name .. '`\n end\n'
                end
            end

            prepare_str = prepare_str .. updates_format_end .. ' in ('
            local uplen = #updates
            for i = 1, uplen do
                local entry_data = updates[i]
                if i == uplen then
                    prepare_str = prepare_str .. updates_format_key
                else
                    prepare_str = prepare_str .. updates_format_key .. ','
                end
                for j = 1, key_len do
                    local kn = key_list[j]
                    local kv = entry_data[kn]
                    args[#args + 1] = kv
                end
            end
            prepare_str = prepare_str .. ');'

            if uplen <= 0 then break end
            local prepare_obj = new_prepare_obj(prepare_str)
            local isok, ret = pcall(prepare_execute, self._db, prepare_obj, tunpack(args))
            if not isok or not ret or ret.err then
                log.error("_update_one err ", ret, updates, changes)
                for i = 1, uplen do
                    res_list[ret_index] = false
                    ret_index = ret_index + 1
                end
            else
                for i = 1, uplen do
                    res_list[ret_index] = true
                    ret_index = ret_index + 1
                end
            end
            local stmt = prepare_obj.stmt
            if stmt then
                pcall(self._db.conn.stmt_close, self._db.conn, stmt)
            end
        end

        return res_list
    end

    --更新一条数据
    self._update_one = function(entry_data, change_map)
        local prepare_obj, index_list = get_update_pre_pare(change_map)
        local args = {}
        for i = 1, #index_list do
            local index = index_list[i]
            local field_name = field_list[index]
            local field_type = field_map[field_name]
            local field_value = entry_data[field_name]
            if field_type == FIELD_TYPE.table then
                field_value = tab_encode(field_value)
            end
            args[#args + 1] = field_value
        end

        for i = 1,#key_list do
            args[#args + 1] = entry_data[key_list[i]]
        end

        local isok, ret = pcall(prepare_execute, self._db, prepare_obj, tunpack(args))
        if not isok or not ret or ret.err then
            log.error("_update_one err ", ret, entry_data, change_map)
            error("_update_one err ")
        end

        return true
    end

    self._delete = function(key_values)
        local len = #key_values
        assert(len >= 0 and len <= #select_format_end_list, "err key_values len " .. len)
        local prepare_obj = delete_prepare_list[len]
        local isok, ret = pcall(prepare_execute, self._db, prepare_obj, tunpack(key_values))
        if not isok or not ret or ret.err then
            log.error("_delete err ", ret, key_values)
            error("_delete err ")
        end
        
        return true
    end

    self._delete_by_range = function(left, right, key_values)
        local len = #key_values
        local args = {}
        for i = 1, len do
            args[#args + 1] = key_values[i]
        end
        local prepare_obj = nil
        if left and right then
            prepare_obj = delete_range_prepare_list_c[len + 1]
            args[#args + 1] = left
            args[#args + 1] = right
        elseif left then
            prepare_obj = delete_range_prepare_list_b[len + 1]
            args[#args + 1] = left
        else
            prepare_obj = delete_range_prepare_list_s[len + 1]
            args[#args + 1] = right
        end

        local isok, ret = pcall(prepare_execute, self._db, prepare_obj, tunpack(args))
        if not isok or not ret or ret.err then
            log.error("_delete_by_range err ", ret, key_values)
            error("_delete_by_range err ")
        end

        return true
    end

    self._delete_in = function(in_values, key_values)
        local len = #key_values
        local prepare_str = delete_in_prepare_list[len + 1]
        prepare_str = prepare_str .. '('
        local in_len = #in_values

        local args = {}
        for i = 1, len do
            args[#args + 1] = key_values[i]  
        end
        for i = 1, in_len do
            if i == in_len then
                prepare_str = prepare_str .. '?'
            else
                prepare_str = prepare_str .. '?,'
            end
            args[#args + 1] = in_values[i]
        end
        prepare_str = prepare_str .. ')'

        local prepare_obj = new_prepare_obj(prepare_str)
        local isok, ret = pcall(prepare_execute, self._db, prepare_obj, tunpack(args))
        
        local stmt = prepare_obj.stmt
        if stmt then
            pcall(self._db.conn.stmt_close, self._db.conn, stmt)
        end
        if not isok or not ret or ret.err then
            log.error("_delete_in err ", ret, key_values)
            error("_delete_in err ")
        end

        return true
    end

    self._batch_delete = function(keys_list)
        local len = #keys_list[1]
        local res_list = {}
        local total_len = #keys_list
        local batch = math.ceil(total_len / self.batch_delete_num)
        for i = 1, batch do
            local end_index = i * self.batch_delete_num
            local start_index = end_index - self.batch_delete_num + 1

            local args = {}
            local count = 0
            for j = start_index, end_index do
                local key_values = keys_list[j]
                if key_values then
                    count = count + 1
                    for i = 1, #key_values do
                        tinsert(args, key_values[i])
                    end
                else
                    break
                end
            end

            if count <= 0 then break end

            local prepare_obj = batch_delete_prepare_list[len][count]
            local isok, ret = pcall(prepare_execute, self._db, prepare_obj, tunpack(args))
            if isok and ret and not ret.err then
                for i = 1, count do
                    res_list[start_index + i - 1] = true
                end
            else
                log.error("_batch_delete err ", self._tab_name, ret, args)
                for i = 1, count do
                    res_list[start_index + i - 1] = false
                end
            end
        end

        return res_list
    end

    self._batch_delete_by_range = function(query_list)
        local first_query = query_list[1]
        local first_left = first_query.left
        local first_right = first_query.right
        local prepare_list = nil
        if first_left and first_right then
            prepare_list = batch_delete_range_prepare_list_c
        elseif first_left then
            prepare_list = batch_delete_range_prepare_list_b
        else
            prepare_list = batch_delete_range_prepare_list_s
        end
        local len = #first_query.key_values + 1
        local res_list = {}
        local total_len = #query_list
        local batch = math.ceil(total_len / self.batch_delete_num)
        for i = 1, batch do
            local end_index = i * self.batch_delete_num
            local start_index = end_index - self.batch_delete_num + 1

            local args = {}
            local count = 0
            for j = start_index, end_index do
                local query = query_list[j]
                if query then
                    local key_values = query.key_values
                    count = count + 1
                    for i = 1, #key_values do
                        tinsert(args, key_values[i])
                    end
                    if query.left then
                        tinsert(args, query.left)
                    end

                    if query.right then
                        tinsert(args, query.right)
                    end
                else
                    break
                end
            end

            if count <= 0 then break end

            local prepare_obj = prepare_list[len][count]
            local isok, ret = pcall(prepare_execute, self._db, prepare_obj, tunpack(args))
            if isok and ret and not ret.err then
                for i = 1, count do
                    res_list[start_index + i - 1] = true
                end
            else
                log.error("_batch_delete_by_range err ", self._tab_name, ret, args)
                for i = 1, count do
                    res_list[start_index + i - 1] = false
                end
            end
        end

        return res_list
    end

    local _idx_preparecache_map = {}

    local function parse_query(query)
        local field_values = {}
        local field_names = {}
        local args = {}
        local cache_key = ""
        if query then
            for field_name, field_value in table_util.kvsortipairs(query) do
                tinsert(field_names, field_name)
                tinsert(field_values, field_value)
                if type(field_value) ~= 'table' then
                    tinsert(args, field_value)
                    cache_key = cache_key .. field_name .. '-'
                else
                    cache_key = cache_key .. '-'
                    if field_value['$gt'] then
                        tinsert(args, field_value['$gt'])
                        cache_key = cache_key .. 'g'
                    end

                    if field_value['$gte'] then
                        tinsert(args, field_value['$gte'])
                        cache_key = cache_key .. 'ge'
                    end

                    if field_value['$lt'] then
                        tinsert(args, field_value['$lt'])
                        cache_key = cache_key .. 'l'
                    end

                    if field_value['$lte'] then
                        tinsert(args, field_value['$lte'])
                        cache_key = cache_key .. 'le'
                    end
                    cache_key = cache_key .. '-'
                end
            end
        end
        return field_values, field_names, args, cache_key
    end

    local function join_query_prepare_str(field_name, field_value, prepare_str)
        local isL = false
        if field_value['$gt'] then
            prepare_str = prepare_str .. sformat('`%s`>?', field_name)
            isL = true
        end

        if field_value['$gte'] then
            prepare_str = prepare_str .. sformat('`%s`>=?', field_name)
            isL = true
        end

        if field_value['$lt'] then
            if isL then
                prepare_str = prepare_str .. sformat(' and `%s`<?', field_name)
            else
                prepare_str = prepare_str .. sformat('`%s`<?', field_name)
            end
        end

        if field_value['$lte'] then
            if isL then
                prepare_str = prepare_str .. sformat(' and `%s`<=?', field_name)
            else
                prepare_str = prepare_str .. sformat('`%s`<=?', field_name)
            end
        end

        return prepare_str
    end

    self._idx_select = function(query)
        local field_values, field_names, args, cache_key = parse_query(query)
        local prepare_obj = nil
        
        if _idx_preparecache_map[cache_key] then
            prepare_obj = _idx_preparecache_map[cache_key]
        else
            local prepare_str = select_format_head .. select_format_center
            local len = #field_names
            for i = 1, len do
                local field_name = field_names[i]
                local field_value = field_values[i]
                if type(field_value) ~= 'table' then
                    prepare_str = prepare_str .. sformat('`%s` = ?', field_name)
                else
                    prepare_str = join_query_prepare_str(field_name, field_value, prepare_str)
                end
                if i ~= len then
                    prepare_str = prepare_str .. ' and '
                end
            end
            
            prepare_obj = new_prepare_obj(prepare_str)
            _idx_preparecache_map[cache_key] = prepare_obj
        end

        local isok, ret = pcall(prepare_execute, self._db, prepare_obj, tunpack(args))
        if not isok or not ret or ret.err then
            log.error("_idx_select err ", ret, query)
            error("_idx_select err ")
        end

        decode_tables(ret)
        return ret
    end

    local _idx_limit_preparecache_map = {}
    local _idx_limit_count_prepare_cache_map = {}
    self._idx_get_entry_by_limit = function(cursor, limit, sort, sort_field_name, query, next_offset)
        local end_field_name = sort_field_name
        local field_values, field_names, args, cache_key = parse_query(query)
        local is_have_cursor = cursor and 1 or 0
        local is_have_offset = next_offset and 1 or 0
        cache_key = cache_key .. sformat(",%s_%s_%s_%s", sort_field_name, sort, is_have_cursor, is_have_offset)

        local prepare_obj = nil
        if _idx_limit_preparecache_map[cache_key] then
            prepare_obj = _idx_limit_preparecache_map[cache_key]
        else
            local prepare_str = nil
            local len = #field_names
            if len > 0 or cursor then
                prepare_str = select_format_head .. select_format_center
            else
                prepare_str = select_format_head
            end
            for i = 1, len do
                local field_name = field_names[i]
                local field_value = field_values[i]
                if type(field_value) ~= 'table' then
                    prepare_str = prepare_str .. sformat('`%s` = ?', field_name)
                else
                    prepare_str = join_query_prepare_str(field_name, field_value, prepare_str)
                end
                if i ~= len or cursor then
                    prepare_str = prepare_str .. ' and '
                end
            end
            if not cursor then
                if sort == 1 then  --升序
                    prepare_str = prepare_str .. sformat(' order by `%s` asc, %s limit ?', end_field_name, asc_key_str)
                else
                    prepare_str = prepare_str .. sformat(' order by `%s` desc, %s limit ?', end_field_name, desc_key_str)
                end
            else
                if sort == 1 then  --升序
                    prepare_str = prepare_str .. sformat('`%s` >= ? order by `%s` asc, %s limit ?', end_field_name, end_field_name, asc_key_str)
                else
                    prepare_str = prepare_str .. sformat('`%s` <= ? order by `%s` desc, %s limit ?', end_field_name, end_field_name, desc_key_str)
                end
            end
            if next_offset then
                prepare_str = prepare_str .. ' offset ?'
            end
            
            prepare_obj = new_prepare_obj(prepare_str)
            _idx_limit_preparecache_map[cache_key] = prepare_obj
        end
        
        local count = nil
        --拿一下count
        if not cursor then
            local count_prepare_obj = nil
            if _idx_limit_count_prepare_cache_map[cache_key] then
                count_prepare_obj = _idx_limit_count_prepare_cache_map[cache_key]
            else
                local count_pre_pare_str = nil
                local len = #field_names
                if len > 0 then
                    count_pre_pare_str = sformat("select count(*) from %s where ", self._tab_name)
                else
                    count_pre_pare_str = sformat("select count(*) from %s;", self._tab_name)
                end
                for i = 1, len do
                    local field_name = field_names[i]
                    local field_value = field_values[i]
                    if type(field_value) ~= 'table' then
                        count_pre_pare_str = count_pre_pare_str .. sformat('`%s` = ?', field_name)
                    else
                        count_pre_pare_str = join_query_prepare_str(field_name, field_value, count_pre_pare_str)
                    end
                    if i ~= len then
                        count_pre_pare_str = count_pre_pare_str .. ' and '
                    end
                end
                count_prepare_obj = new_prepare_obj(count_pre_pare_str)
                _idx_limit_count_prepare_cache_map[cache_key] = count_prepare_obj
            end
            local isok, ret = pcall(prepare_execute, self._db, count_prepare_obj, tunpack(args))
            if not isok or not ret or ret.err then
                log.error("_idx_get_entry_by_limit err ", ret, cursor, limit, sort, sort_field_name, query)
                error("_idx_get_entry_by_limit err ")
            end
            count = ret[1]["count(*)"]
        end
        if cursor then
            args[#args + 1] = cursor
        end

        args[#args + 1] = limit

        if next_offset then
            args[#args + 1] = next_offset
        end

        local isok, ret = pcall(prepare_execute, self._db, prepare_obj, tunpack(args))
        
        if not isok or not ret or ret.err then
            log.error("_idx_get_entry_by_limit err ", ret, cursor, limit, sort, sort_field_name, query, next_offset)
            error("_idx_get_entry_by_limit err ")
        end
        
        local next_cursor = nil
        local pre_offset = next_offset
        next_offset = 0
        if #ret > 0 then
            local end_ret = ret[#ret]
            next_offset = 1
            next_cursor = end_ret[end_field_name]
            for i = #ret - 1, 1, -1 do
                local one_ret = ret[i]
                if one_ret[end_field_name] == next_cursor then
                    next_offset = next_offset + 1
                else
                    break
                end
            end
            if cursor == next_cursor then
                if pre_offset then
                    next_offset = next_offset + pre_offset
                end
            end
        end
        decode_tables(ret)
        return next_cursor, ret, count, next_offset
    end
    
    local _idx_delete_preparecache_map = {}
    self._idx_delete_entry = function(query)
        local field_values, field_names, args, cache_key = parse_query(query)
        local prepare_obj = nil
        if _idx_delete_preparecache_map[cache_key] then
            prepare_obj = _idx_delete_preparecache_map[cache_key]
        else
            local prepare_str = delete_format_head .. select_format_center
            local len = #field_names
            for i = 1, len do
                local field_name = field_names[i]
                local field_value = field_values[i]
                if type(field_value) ~= 'table' then
                    prepare_str = prepare_str .. sformat('`%s` = ?', field_name)
                else
                    prepare_str = join_query_prepare_str(field_name, field_value, prepare_str)
                end
                if i ~= len then
                    prepare_str = prepare_str .. ' and '
                end
            end
            prepare_obj = new_prepare_obj(prepare_str)
            _idx_delete_preparecache_map[cache_key] = prepare_obj
        end

        local isok, ret = pcall(prepare_execute, self._db, prepare_obj, tunpack(args))
        if not isok or not ret or ret.err then
            log.error("_idx_delete_entry err ", ret, query)
            error("_idx_delete_entry err ")
        end

        return true
    end

    return self
end

-- 批量创建表数据
function M:create_entry(entry_data_list)
    return self._insert(entry_data_list)
end

-- 创建一条数据
function M:create_one_entry(entry_data)
    return self._insert_one(entry_data)
end

-- 查询表数据
function M:get_entry(key_values)
    return self._select(key_values)
end

-- 查询一条表数据
function M:get_one_entry(key_values)
    return self._select_one(key_values)
end

-- 保存表数据
function M:save_entry(entry_data_list, change_map_list)
    return self._update(entry_data_list, change_map_list)
end

-- 保存一条数据
function M:save_one_entry(entry_data, change_map)
    return self._update_one(entry_data, change_map)
end

-- 删除表数据
function M:delete_entry(key_values)
    return self._delete(key_values)
end

-- IN 查询
function M:get_entry_by_in(in_values, key_values)
    return self._select_in(in_values, key_values)
end

-- 分页查询
function M:get_entry_by_limit(cursor, limit, sort, key_values, is_only_key)
    return self._select_limit(cursor, limit, sort, key_values, is_only_key)
end

-- 范围删除
function M:delete_entry_by_range(left, right, key_values)
    return self._delete_by_range(left, right, key_values)
end

-- IN 删除
function M:delete_entry_by_in(in_values, key_values)
    return self._delete_in(in_values, key_values)
end

-- 批量删除
function M:batch_delete_entry(keys_list)
    return self._batch_delete(keys_list)
end

--批量范围删除
function M:batch_delete_entry_by_range(query_list)
    return self._batch_delete_by_range(query_list)
end

--通过普通索引查询
function M:idx_get_entry(query)
    return self._idx_select(query)
end

--通过普通索引分页查询
function M:idx_get_entry_by_limit(cursor, limit, sort, sort_field_name, query, next_offset)
    return self._idx_get_entry_by_limit(cursor, limit, sort, sort_field_name, query, next_offset)
end

--通过普通索引删除
function M:idx_delete_entry(query)
    return self._idx_delete_entry(query)
end

return M