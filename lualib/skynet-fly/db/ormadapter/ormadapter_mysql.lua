local contriner_client = require "skynet-fly.client.contriner_client"
local table_util = require "skynet-fly.utils.table_util"
local string_util = require "skynet-fly.utils.string_util"
local mysqlf = require "skynet-fly.db.mysqlf"
local log = require "skynet-fly.log"

local FIELD_TYPE = require "skynet-fly.db.orm.ormtable".FIELD_TYPE
local FIELD_LUA_DEFAULT = require "skynet-fly.db.orm.ormtable".FIELD_LUA_DEFAULT

local setmetatable = setmetatable
local sfild = string.find
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
}

local IS_NUMBER_TYPE = {
    [FIELD_TYPE.int8] = true,
    [FIELD_TYPE.int16] = true,
    [FIELD_TYPE.int32] = true,
    [FIELD_TYPE.int64] = true,
    [FIELD_TYPE.uint8] = true,
    [FIELD_TYPE.uint16] = true,
    [FIELD_TYPE.uint32] = true,
}

local FIELD_TYPE_LUA_TYPE = {}

do 
    for type,name in pairs(FIELD_TYPE_SQL_TYPE) do
        FIELD_TYPE_LUA_TYPE[name] = type
    end
end

local M = {}
local mata = {__index = M}

-- 新建适配对象
function M:new(db_name)
    local t = {
        _db = mysqlf:new(db_name),
        _tab_name = nil,
        _field_list = nil,
        _field_map = nil,
        _key_list = nil,
    }

    setmetatable(t, mata)

    return t
end

local function create_table(t)
    local field_list = t._field_list
    local field_map = t._field_map
    local key_list = t._key_list
    local sql_str = sformat("create table %s (\n", t._tab_name)
    for i = 1,#field_list do
        local field_name = field_list[i]
        local field_type = field_map[field_name]
        local convert_type = assert(FIELD_TYPE_SQL_TYPE[field_type],"unknown type : " .. field_type)
        if field_type == FIELD_TYPE.text or field_type == FIELD_TYPE.blob then          --text 和 blob类型不支持指定默认值
            sql_str = sql_str .. sformat("\t`%s` %s,\n", field_name, convert_type)
        else
            sql_str = sql_str .. sformat("\t`%s` %s NOT NULL DEFAULT '%s',\n", field_name, convert_type, FIELD_LUA_DEFAULT[field_type])
        end
    end

    sql_str = sql_str .. sformat("\tprimary key(%s)\n", tconcat(key_list,','))
    sql_str = sql_str .. ');'

    local ret = t._db:query(sql_str)
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
    local key_map = {}
    
    for i = 1,#key_list do
        key_map[key_list[i]] = true
        
    end

    local key_sort_map = {}
    for i = 1,#field_list do
        key_sort_map[field_list[i]] = i
    end

    local pre_key_map = {}

    for i = 1,#index_info do
        local info = index_info[i]
        local column_name = info.Column_name
        local key_name = info.Key_name
        if key_name == 'PRIMARY' then   --主键
            pre_key_map[column_name] = true
        end
    end

    local def = table_util.check_def_table(key_map, pre_key_map)
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
            error("can`t change type " .. field_name .. ' new:' .. def_info._new .. ' old:' .. def_info._old) --不能修改类型
        end
    end

    --新增字段
    if next(new_field_list) then
        local sql_str = sformat("alter table %s\n", t._tab_name)
        for _,field_name,is_end in table_util.sort_ipairs(new_field_list, function(a, b) return key_sort_map[a] < key_sort_map[b] end) do
            local field_type = field_map[field_name]
            local convert_type = assert(FIELD_TYPE_SQL_TYPE[field_type],"unknown type : " .. field_type)
            if not is_end then
                if field_type == FIELD_TYPE.text or field_type == FIELD_TYPE.blob then
                    sql_str = sql_str .. sformat("add `%s` %s,\n", field_name, convert_type)
                else
                    sql_str = sql_str .. sformat("add `%s` %s NOT NULL DEFAULT '%s',\n", field_name, convert_type, FIELD_LUA_DEFAULT[field_type])
                end
            else
                if field_type == FIELD_TYPE.text or field_type == FIELD_TYPE.blob then
                    sql_str = sql_str .. sformat("add `%s` %s;\n", field_name, convert_type)
                else
                    sql_str = sql_str .. sformat("add `%s` %s NOT NULL DEFAULT '%s';\n", field_name, convert_type, FIELD_LUA_DEFAULT[field_type])
                end
            end
        end

        local ret = t._db:query(sql_str)
        if not ret then
            log.error("alter_table err ",sql_str)
            error("alter_table table err")
        elseif ret.err then
            log.error("alter_table err ",ret,sql_str)
            error("alter_table table err ")
        end
    end
end
-- 构建表
function M:builder(tab_name, field_list, field_map, key_list)
    self._tab_name = tab_name
    self._field_map = field_map
    self._key_list = key_list
    self._field_list = field_list

    -- 查询表的字段信息
    local describe = self._db:query("DESCRIBE " .. tab_name)
    assert(describe, "not describe ret " .. tab_name)
    if describe.err then
        assert(sfild(describe.err, "doesn't exist", nil, true), "unknown")
        --不存在 创建
        create_table(self)
    else
        --存在 检查变更
        local index_info = self._db:query("show index from " .. tab_name)
        assert(index_info, "can`t get index_info ")
        alter_table(self, describe, index_info)
    end
    
    local packet_max = self._db:query("SHOW VARIABLES LIKE 'max_allowed_packet'")
    assert(packet_max and #packet_max >= 1, "can`t get packet max")

    local max_packet_size = tonumber(packet_max[1].Value)         --包最大长度
    local local_max_packet_size = self._db:max_packet_size()
    if local_max_packet_size < max_packet_size then
        max_packet_size = local_max_packet_size
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
    local delete_format_head = sformat("delete from %s",tab_name)
    local delete_format_center = " where "

    local len = #field_list
    for i = 1,len do
        local field_name = field_list[i]
        local field_type = field_map[field_name]
        if IS_NUMBER_TYPE[field_type] then
            if i == len then
                insert_format_end = insert_format_end .. "%d" 
            else
                insert_format_end = insert_format_end .. "%d,"
            end
            update_format_head_list[i] = '`' .. field_name .. "` = %d"
        else
            if i == len then
                insert_format_end = insert_format_end .. "'%s'" 
            else
                insert_format_end = insert_format_end .. "'%s',"
            end
            update_format_head_list[i] = '`' .. field_name .. "` = '%s'"
        end
        if i == len then
            insert_format_head = insert_format_head .. '`' .. field_name .. '`'
            select_format_head = select_format_head .. '`' .. field_name .. '`'
        else
            insert_format_head = insert_format_head .. '`' .. field_name .. '`,'
            select_format_head = select_format_head .. '`' .. field_name .. '`,'
        end
        
        field_index_map[field_name] = i
    end

    len = #key_list
    for i = 1,len do
        local field_name = key_list[i]
        local field_type = field_map[field_name]
        if IS_NUMBER_TYPE[field_type] then
            if i == len then
                select_format_end = select_format_end .. '`' .. field_name .. '`=' .. "%d"
                update_format_end = update_format_end .. '`' .. field_name .. '`=' .. "%d"
                select_format_key_head = select_format_key_head .. '`' .. field_name .. '`'
            else
                select_format_end = select_format_end .. '`' .. field_name .. '`=' .. "%d"
                update_format_end = update_format_end .. '`' .. field_name .. '`=' .. "%d and "
                select_format_key_head = select_format_key_head .. '`' .. field_name .. '`,'
            end
        else
            if i == len then
                select_format_end = select_format_end .. '`' .. field_name .. '`=' .. "'%s'"
                update_format_end = update_format_end .. '`' .. field_name .. '`=' .. "'%s'"
                select_format_key_head = select_format_key_head .. '`' .. field_name .. '`'
            else
                select_format_end = select_format_end .. '`' .. field_name .. '`=' .. "'%s'"
                update_format_end = update_format_end .. '`' .. field_name .. '`=' .. "'%s' and "
                select_format_key_head = select_format_key_head .. '`' .. field_name .. '`,'
            end
        end
       
        select_format_end_list[i] = select_format_end
        select_format_end = select_format_end .. ' and '
    end

    insert_format_head = insert_format_head .. ') value'
    insert_format_end = insert_format_end .. ')'
    select_format_key_head = select_format_key_head .. ' from ' .. tab_name
    select_format_head = select_format_head .. ' from ' .. tab_name

    local insert_list = {}                               
    local function entry_data_to_list(entry_data)
        for i = 1,#field_list do
            local fn = field_list[i]
            local fv = entry_data[fn]

            if type(fv) == 'string' then
                fv = string_util.quote_sql_str(fv)
            end
            insert_list[i] = fv
        end
        return insert_list
    end

    --防止sql注入
    local function quete_key_values(key_values)
        for i = 1, #key_values do
            local v = key_values[i]
            if type(v) == 'string' then
                key_values[i] = string_util.quote_sql_str(v)
            end
        end
    end

    local function handle_sql_ret(ret_list,s_start,s_end,sql_ret,sql_str)
        if not sql_ret or sql_ret.err then
            log.error("sql ret err ",sql_ret,sql_str)
            for i = s_start, s_end do
                ret_list[i] = false
            end
        else
            for i = s_start, s_end do
                ret_list[i] = true
            end
        end
    end

    --insert 批量插入
    self._insert = function(entry_data_list)
        local sql_str = insert_format_head
        local add_str = nil
        local add_count = 0
        local index = 1
        local len = #entry_data_list
        local sql_ret = nil
        local ret_list = {}
        local s_index = index

        while index <= len do
            local entry_data = entry_data_list[index]
            if not entry_data then break end

            add_str = add_str or sformat(insert_format_end, tunpack(entry_data_to_list(entry_data)))
            if sql_str:len() + add_str:len() > max_packet_size then
                --一条都超过
                assert(add_count ~= 0, "can`t insert max_packet_size:" .. max_packet_size .. ' packlen:' ..  sql_str:len() + add_str:len())
                --超过最大长度了 先插入一波
                sql_str = sql_str:sub(1,sql_str:len() - 1)
                sql_ret = self._db:query(sql_str)
                handle_sql_ret(ret_list, s_index, index - 1, sql_ret, sql_str)
                sql_str = insert_format_head
                add_count = 0
                s_index = index
            elseif index == len then  --到结尾了
                sql_str = sql_str .. add_str
                sql_ret = self._db:query(sql_str)
                handle_sql_ret(ret_list, s_index, index, sql_ret, sql_str)
                add_count = 0
                index = index + 1
                s_index = index
            else
                sql_ret = nil
                sql_str = sql_str .. add_str .. ','
                index = index + 1
                add_str = nil
                add_count = add_count + 1
            end
        end
        return ret_list
    end

    --insert_one插入单条
    self._insert_one = function(entry_data)
        local sql_str = insert_format_head .. sformat(insert_format_end, tunpack(entry_data_to_list(entry_data)))
        assert(sql_str:len() <= max_packet_size, "can`t insert max_packet_size:" .. max_packet_size .. ' packlen:' ..  sql_str:len())
        local sql_ret = self._db:query(sql_str)
        if not sql_ret or sql_ret.err then
            log.error("_insert_one err ",sql_ret,sql_str)
            error("_insert_one err " .. sql_str)
        end

        return true
    end

    --select 查询
    self._select = function(key_values)
        local len = #key_values
        assert(len >= 0 and len <= #select_format_end_list, "err key_values len " .. len)
        local sql_str = nil
        if len == 0 then
            sql_str = select_format_head
        else
            quete_key_values(key_values)
            sql_str = select_format_head .. select_format_center .. sformat(select_format_end_list[len], tunpack(key_values))
        end
        local sql_ret = self._db:query(sql_str)
        if not sql_ret or sql_ret.err then
            log.error("select err ",sql_str,sql_ret)
            error("select err ".. sql_str)
        end
        return sql_ret
    end

    --查询一条数据
    local keys_max_len = #key_list
    self._select_one = function(key_values)
        quete_key_values(key_values)
        local sql_str = select_format_head .. select_format_center .. sformat(select_format_end_list[keys_max_len], tunpack(key_values))
        local sql_ret = self._db:query(sql_str)
        if not sql_ret or sql_ret.err then
            log.error("_select_one err ",sql_str,sql_ret)
            error("_select_one err " .. sql_str)
        end
        return sql_ret[1]
    end

    --IN 查询
    self._select_in = function(in_values, key_values)
        local len = #key_values
        if type(in_values[1]) == 'string' then
            for i = 1,#in_values do
                in_values[i] = "'" .. in_values[i] .. "'"
            end
        end
        local end_field_name = key_list[len + 1]
        local endstr = ""
        quete_key_values(in_values)
        if len > 0 then
            quete_key_values(key_values)
            endstr = sformat(select_format_end_list[len], tunpack(key_values))
            endstr = endstr .. sformat(" and `%s` in(%s)", end_field_name, tconcat(in_values, ','))
        else
            endstr = endstr .. sformat(" `%s` in(%s)", end_field_name, tconcat(in_values, ','))
        end
        local sql_str = select_format_head .. select_format_center .. endstr
        local sql_ret = self._db:query(sql_str)
        if not sql_ret or sql_ret.err then
            log.error("_select_in err ",sql_str,sql_ret)
            error("_select_in err " .. sql_str)
        end
        return sql_ret
    end

    --分页 查询
    self._select_limit = function(cursor, limit, sort, key_values, is_only_key)
        assert(type(limit) == 'number')
        assert(type(sort) == 'number')
        if type(cursor) == 'string' then
            cursor = string_util.quote_sql_str(cursor)
        end
        quete_key_values(key_values)
        local len = #key_values
        local sql_str = ""
        local end_field_name = key_list[len + 1]
        local head = nil
        if is_only_key then         --是否仅查询主键
            head = select_format_key_head
        else
            head = select_format_head
        end

        local flag = nil
        local end_str = nil
        if sort == 1 then               --升序
            flag = '>'
            end_str = ' order by ' .. end_field_name
        else                            --降序 
            flag = '<'
            end_str = ' order by ' .. end_field_name .. ' desc'
        end

        if not cursor then --开头把总数查出来
            local keys_str = ""
            if len > 0 then
                keys_str = sformat(select_format_end_list[len], tunpack(key_values))
                sql_str = "select count(*) from " .. tab_name .. select_format_center .. keys_str .. ';'
                sql_str = sql_str .. head .. select_format_center .. keys_str .. end_str .. ' limit ' .. limit
            else
                sql_str = "select count(*) from " .. tab_name .. ';'
                sql_str = sql_str .. head .. end_str .. ' limit ' .. limit
            end
        else
            if len > 0 then
                sql_str = head .. select_format_center .. sformat(select_format_end_list[len] .. ' ', tunpack(key_values))
                .. ' and ' .. end_field_name .. flag .. cursor .. end_str .. ' limit ' .. limit
            else
                sql_str = head .. select_format_center .. end_field_name .. flag .. cursor .. end_str .. ' limit ' .. limit
            end
        end

        local sql_ret = self._db:query(sql_str)
        if not sql_ret or sql_ret.err then
            log.error("_select_limit err ",sql_str, sql_ret)
            error("_select_limit err " .. sql_str)
        end

        local cursor = nil
        local count = nil
        local ret_list = nil
        if sql_ret.multiresultset then
            count = sql_ret[1][1]["count(*)"]
            ret_list = sql_ret[2]
        else
            ret_list = sql_ret
        end
        if #ret_list > 0 then
            local end_ret = ret_list[#ret_list]
            cursor = end_ret[end_field_name]
        end
       
        return cursor, ret_list, count
    end

    --update 更新
    self._update = function(entry_data_list,change_map_list)
        local sql_str = ""
        local add_str = nil
        local add_count = 0
        local index = 1
        local len = #entry_data_list
        local sql_ret = nil
        local ret_list = {}
        local s_index = index

        while index <= len do
            local entry_data = entry_data_list[index]
            if not entry_data then break end
           
            if not add_str then
                local change_map = change_map_list[index]
                local center_str = ""
                for field_name in pairs(change_map) do
                    local index = field_index_map[field_name]
                    local field_value = entry_data[field_name]
                    if type(field_value) == 'string' then
                        field_value = string_util.quote_sql_str(field_value)
                    end
                    center_str = center_str .. sformat(update_format_head_list[index], field_value) .. ','
                end
                center_str = center_str:sub(1,center_str:len() - 1)
                local key_values = {}
                for i = 1,#key_list do
                    key_values[i] = entry_data[key_list[i]]
                end
                add_str = update_format_head .. center_str .. sformat(update_format_end,tunpack(key_values))
            end
            if sql_str:len() + add_str:len() > max_packet_size then
                --一条都超过
                assert(add_count ~= 0, "can`t update max_packet_size:" .. max_packet_size .. ' packlen:' ..  sql_str:len() + add_str:len())
                --超过最大长度了 先插入一波
                sql_str = sql_str:sub(1,sql_str:len() - 1)
                sql_ret = self._db:query(sql_str)
                handle_sql_ret(ret_list, s_index, index - 1, sql_ret, sql_str)
                sql_str = ""
                add_count = 0
                s_index = index
            elseif index == len then  --到结尾了
                sql_str = sql_str .. add_str
                sql_ret = self._db:query(sql_str)
                handle_sql_ret(ret_list, s_index, index, sql_ret, sql_str)
                add_count = 0
                index = index + 1
                s_index = index
            else
                sql_ret = nil
                sql_str = sql_str .. add_str .. ';'
                index = index + 1
                add_str = nil
                add_count = add_count + 1
            end
        end
        return ret_list
    end

    --更新一条数据
    self._update_one = function(entry_data, change_map)
        local center_str = ""
        for field_name in pairs(change_map) do
            local index = field_index_map[field_name]
            local field_value = entry_data[field_name]
            if type(field_value) == 'string' then
                field_value = string_util.quote_sql_str(field_value)
            end
            center_str = center_str .. sformat(update_format_head_list[index], field_value) .. ','
        end
        center_str = center_str:sub(1,center_str:len() - 1)
        local key_values = {}
        for i = 1,#key_list do
            key_values[i] = entry_data[key_list[i]]
        end
        local sql_str = update_format_head .. center_str .. sformat(update_format_end,tunpack(key_values))
        local sql_ret = self._db:query(sql_str)
        if not sql_ret or sql_ret.err then
            log.error("_update_one err ",sql_str,sql_ret)
            error("_update_one err " .. sql_str)
        end

        return true
    end

    self._delete = function(key_values)
        local len = #key_values
        assert(len >= 0 and len <= #select_format_end_list, "err key_values len " .. len)
        local sql_str = nil
        if len == 0 then
            sql_str = delete_format_head
        else
            quete_key_values(key_values)
            sql_str = delete_format_head .. delete_format_center .. sformat(select_format_end_list[len], tunpack(key_values))
        end
        
        local sql_ret = self._db:query(sql_str)
        if not sql_ret or sql_ret.err then
            log.error("_delete err ",sql_str,sql_ret)
            error("_delete err " .. sql_str)
        end
        return true
    end

    self._delete_by_range = function(left, right, key_values)
        local len = #key_values
        local end_field_name = key_list[len + 1]
        local sql_str = nil
        local end_str = nil
        local field_type = field_map[end_field_name]
        if type(left) == 'string' then
            left = string_util.quote_sql_str(left)
        end
        if type(right) == 'string' then
            right = string_util.quote_sql_str(right)
        end
        if left and right then
            if IS_NUMBER_TYPE[field_type] then
                end_str = sformat("`%s` >= %d and `%s` <= %d", end_field_name, left, end_field_name, right)
            else
                end_str = sformat("`%s` >= '%s' and `%s` <= '%s'", end_field_name, left, end_field_name, right)
            end
        elseif left then
            if IS_NUMBER_TYPE[field_type] then
                end_str = sformat("`%s` >= %d", end_field_name, left)
            else
                end_str = sformat("`%s` >= '%s'", end_field_name, left)
            end
        else
            if IS_NUMBER_TYPE[field_type] then
                end_str = sformat("`%s` <= %d", end_field_name, right)
            else
                end_str = sformat("`%s` <= '%s'", end_field_name, right)
            end
        end
        if len > 0 then
            quete_key_values(key_values)
            sql_str = delete_format_head .. delete_format_center .. sformat(select_format_end_list[len], tunpack(key_values)) .. ' and ' .. end_str
        else
            sql_str = delete_format_head .. delete_format_center .. end_str
        end

        local sql_ret = self._db:query(sql_str)
        if not sql_ret or sql_ret.err then
            log.error("_delete_by_range err ",sql_str,sql_ret)
            error("_delete_by_range err " .. sql_str)
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

return M