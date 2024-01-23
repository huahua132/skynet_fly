local contriner_client = require "contriner_client"
local table_util = require "table_util"
local string_util = require "string_util"
local mysqlf = require "mysqlf"
local log = require "log"

local FILED_TYPE = require "ormtable".FILED_TYPE

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

local FILED_TYPE_SQL_TYPE = {
    [FILED_TYPE.int8] = "tinyint",
    [FILED_TYPE.int16] = "smallint",
    [FILED_TYPE.int32] = "int",
    [FILED_TYPE.int64] = "bigint",
    [FILED_TYPE.uint8] = "tinyint unsigned",
    [FILED_TYPE.uint16] = "smallint unsigned",
    [FILED_TYPE.uint32] = "int unsigned",

    [FILED_TYPE.string32] = "varchar(32)",
    [FILED_TYPE.string64] = "varchar(64)",
    [FILED_TYPE.string128] = "varchar(128)",
    [FILED_TYPE.string256] = "varchar(256)",
    [FILED_TYPE.string512] = "varchar(512)",
    [FILED_TYPE.string1024] = "varchar(1024)",
    [FILED_TYPE.string2048] = "varchar(2048)",
    [FILED_TYPE.string4096] = "varchar(4096)",
    [FILED_TYPE.string8192] = "varchar(8192)",

    [FILED_TYPE.text] = "text",
    [FILED_TYPE.blob] = "blob",
}

local IS_NUMBER_TYPE = {
    [FILED_TYPE.int8] = true,
    [FILED_TYPE.int16] = true,
    [FILED_TYPE.int32] = true,
    [FILED_TYPE.int64] = true,
    [FILED_TYPE.uint8] = true,
    [FILED_TYPE.uint16] = true,
    [FILED_TYPE.uint32] = true,
}

local FILED_TYPE_LUA_TYPE = {}

do 
    for type,name in pairs(FILED_TYPE_SQL_TYPE) do
        FILED_TYPE_LUA_TYPE[name] = type
    end
end

local M = {}
local mata = {__index = M}

-- 新建适配对象
function M:new(db_name)
    local t = {
        _db = mysqlf:new(db_name),
        _tab_name = nil,
        _filed_list = nil,
        _filed_map = nil,
        _key_list = nil,
    }

    setmetatable(t, mata)

    return t
end

local function create_table(t)
    local filed_list = t._filed_list
    local filed_map = t._filed_map
    local key_list = t._key_list
    local sql_str = sformat("create table %s (\n", t._tab_name)
    for i = 1,#filed_list do
        local filed_name = filed_list[i]
        local filed_type = filed_map[filed_name]
        local convert_type = assert(FILED_TYPE_SQL_TYPE[filed_type],"unknown type : " .. filed_type)
        sql_str = sql_str .. sformat("\t%s %s,\n",filed_name, convert_type)
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
    local filed_list = t._filed_list
    local filed_map = t._filed_map
    local key_list = t._key_list
    local key_map = {}
    
    for i = 1,#key_list do
        key_map[key_list[i]] = true
        
    end

    local key_sort_map = {}
    for i = 1,#filed_list do
        key_sort_map[filed_list[i]] = i
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
    local pre_filed_map = {}
    for i = 1,#describe do
        local one_des = describe[i]
        local tp = one_des.Type:gsub("(%a*)int%(%d+%)", "%1int")
        local field_name = one_des.Field
        local lua_type = assert(FILED_TYPE_LUA_TYPE[tp],"not exists type " .. tp)
        pre_filed_map[field_name] = lua_type
    end

    local def = table_util.check_def_table(filed_map, pre_filed_map)
    local new_field_list = {} 
    for filed_name,def_info in pairs(def) do
        if def_info._flag == "add" then
            tinsert(new_field_list,filed_name)
        elseif def_info._flag == "valuedef" then
            error("can`t change type " .. filed_name .. ' new:' .. def_info._new .. ' old:' .. def_info._old) --不能修改类型
        end
    end

    --新增字段
    if next(new_field_list) then
        local sql_str = sformat("alter table %s\n", t._tab_name)
        for _,filed_name,is_end in table_util.sort_ipairs(new_field_list, function(a, b) return key_sort_map[a] < key_sort_map[b] end) do
            local filed_type = filed_map[filed_name]
            local convert_type = assert(FILED_TYPE_SQL_TYPE[filed_type],"unknown type : " .. filed_type)
            if not is_end then
                sql_str = sql_str .. sformat("add %s %s,\n", filed_name, convert_type)
            else
                sql_str = sql_str .. sformat("add %s %s;\n", filed_name, convert_type)
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
function M:builder(tab_name, filed_list, filed_map, key_list)
    self._tab_name = tab_name
    self._filed_map = filed_map
    self._key_list = key_list
    self._filed_list = filed_list

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

    local filed_index_map = {}

    local insert_format_head = sformat("insert into %s (",tab_name)
    local insert_format_end = "("
    local select_format_head = sformat("select ")
    local select_format_center = " where "
    local select_format_end = ""
    local select_format_end_list = {}
    local update_format_head = sformat("update %s set ",tab_name)
    local update_format_head_list = {}
    local update_format_end = " where "
    local delete_format_head = sformat("delete from %s",tab_name)
    local delete_format_center = " where "

    local len = #filed_list
    for i = 1,len do
        local filed_name = filed_list[i]
        local filed_type = filed_map[filed_name]
        if IS_NUMBER_TYPE[filed_type] then
            if i == len then
                insert_format_end = insert_format_end .. "%d" 
            else
                insert_format_end = insert_format_end .. "%d,"
            end
            update_format_head_list[i] = '`' .. filed_name .. "` = %d"
        else
            if i == len then
                insert_format_end = insert_format_end .. "'%s'" 
            else
                insert_format_end = insert_format_end .. "'%s',"
            end
            update_format_head_list[i] = '`' .. filed_name .. "` = '%s'"
        end
        if i == len then
            insert_format_head = insert_format_head .. '`' .. filed_name .. '`'
            select_format_head = select_format_head .. '`' .. filed_name .. '`'
            
        else
            insert_format_head = insert_format_head .. '`' .. filed_name .. '`,'
            select_format_head = select_format_head .. '`' .. filed_name .. '`,'
        end
        
        filed_index_map[filed_name] = i
    end

    len = #key_list
    for i = 1,len do
        local filed_name = key_list[i]
        local filed_type = filed_map[filed_name]
        if IS_NUMBER_TYPE[filed_type] then
            if i == len then
                select_format_end = select_format_end .. '`' .. filed_name .. '`=' .. "%d"
                update_format_end = update_format_end .. '`' .. filed_name .. '`=' .. "%d"
            else
                select_format_end = select_format_end .. '`' .. filed_name .. '`=' .. "%d"
                update_format_end = update_format_end .. '`' .. filed_name .. '`=' .. "%d and "
            end
        else
            if i == len then
                select_format_end = select_format_end .. '`' .. filed_name .. '`=' .. "'%s'"
                update_format_end = update_format_end .. '`' .. filed_name .. '`=' .. "'%s'"
            else
                select_format_end = select_format_end .. '`' .. filed_name .. '`=' .. "'%s'"
                update_format_end = update_format_end .. '`' .. filed_name .. '`=' .. "'%s' and "
            end
        end
       
        select_format_end_list[i] = select_format_end
        select_format_end = select_format_end .. ' and '
    end

    insert_format_head = insert_format_head .. ') value'
    insert_format_end = insert_format_end .. ')'
    select_format_head = select_format_head .. ' from ' .. tab_name

    local insert_list = {}                               
    local function entry_data_to_list(entry_data)
        for i = 1,#filed_list do
            local fn = filed_list[i]
            local ft = filed_map[fn]
            local fv = entry_data[fn]

            if type(fv) == 'string' then
                fv = string_util.quote_sql_str(fv)
            end
            insert_list[i] = fv
        end
        return insert_list
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
            return nil
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
            sql_str = select_format_head .. select_format_center .. sformat(select_format_end_list[len], tunpack(key_values))
        end
        local sql_ret = self._db:query(sql_str)
        if sql_ret.err then
            log.error("select err ",sql_str,sql_ret)
            error(sql_ret.err)
        end
        return sql_ret
    end

    --查询一条数据
    local keys_max_len = #key_list
    self._select_one = function(key_values)
        local sql_str = select_format_head .. select_format_center .. sformat(select_format_end_list[keys_max_len], tunpack(key_values))
        local sql_ret = self._db:query(sql_str)
        if sql_ret.err then
            log.error("_select_one err ",sql_str,sql_ret)
            error(sql_ret.err)
        end
        return sql_ret[1]
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
                    local index = filed_index_map[field_name]
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
            local index = filed_index_map[field_name]
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
        if not sql_ret then
            return false
        end
        if sql_ret.err then
            log.error("_update_one err ",sql_str,sql_ret)
            return false
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
            sql_str = delete_format_head .. delete_format_center .. sformat(select_format_end_list[len], tunpack(key_values))
        end
        
        local sql_ret = self._db:query(sql_str)
        if sql_ret.err then
            log.error("delete err ",sql_str,sql_ret)
            error(sql_ret.err)
        end
        return sql_ret.affected_rows
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

return M