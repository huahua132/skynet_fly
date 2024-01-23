local contriner_client = require "contriner_client"
local table_util = require "table_util"
local string_util = require "string_util"
local mongof = require "mongof"
local log = require "log"

local FILED_TYPE = require "ormtable".FILED_TYPE

local setmetatable = setmetatable
local assert = assert
local pairs = pairs
local error = error
local next = next
local tunpack = table.unpack
local type = type
local tonumber = tonumber
local tinsert = table.insert
local pcall = pcall

local M = {}
local mata = {__index = M}

-- 新建适配对象
function M:new(db_name)
    local t = {
        _db = mongof.new_client(db_name),
        _tab_name = nil,
        _filed_list = nil,
        _filed_map = nil,
        _key_list = nil,
    }

    setmetatable(t, mata)

    return t
end

-- 构建表
function M:builder(tab_name, filed_list, filed_map, key_list)
    self._tab_name = tab_name
    self._filed_map = filed_map
    self._key_list = key_list
    self._filed_list = filed_list

    local args = {}
    local index_name = "index"
    for i = 1,#key_list do
        local filed_name = key_list[i]
        tinsert(args, {[filed_name] = 1})
        index_name = index_name .. "_" .. filed_name
    end
    args.unique = true
    args.name = index_name
    local collect_db = self._db[tab_name]
    local res = collect_db:create_index(args)
    if res.ok ~= 1 then
        log.error("builder err ", tab_name, res)
    end
    assert(res.ok == 1, "builder err")

    local key_len = #key_list
    --insert 创建
    self._insert = function(entry_data_list)
        local res_list = {}
        for i = 1,#entry_data_list do
            local entry_data = entry_data_list[i]
            local isok,err = collect_db:raw_safe_insert(entry_data)
            if not isok then
                log.error("insert doc err ",err)
                res_list[i] = false
            else
                res_list[i] = true
            end
        end
        return res_list
    end

    --insert_one 创建一条数据
    self._insert_one = function(entry_data)
        local isok,err = collect_db:raw_safe_insert(entry_data)
        if not isok then
            log.error("insert doc err ",err)
            return nil
        end
        return true
    end

    --select 查询
    self._select = function(key_values)
        local args = {}
        local len = #key_values
        for i = 1, len do
            args[key_list[i]] = key_values[i]
        end

        local res_list = {}
        if len == key_len then
            local ret = collect_db:find_one(args)
            if ret then
                ret._id = nil
                tinsert(res_list, ret)
            end
        else
            local ret = collect_db:find(args)
            while ret:has_next() do
                local entry_data = ret:next()
                entry_data._id = nil
                tinsert(res_list, entry_data)
            end
        end
    
        return res_list
    end

    --select_one 查询单条
    self._select_one = function(key_values)
        local args = {}
        for i = 1, key_len do
            args[key_list[i]] = key_values[i]
        end
        local ret = collect_db:find_one(args)
        if not ret then
            return nil
        else
            ret._id = nil
            return ret
        end
    end

    --update 更新
    local query = {}
    for i = 1,key_len do
        query[key_list[i]] = 0
    end
 
    self._update = function(entry_data_list,change_map_list)
        local res_list = {}
        for i = 1,#entry_data_list do
            local entry_data = entry_data_list[i]
            local change_map = change_map_list[i]
            for k,_ in pairs(query) do
                query[k] = entry_data[k]
            end
            local update = {}
            for k,_ in pairs(change_map) do
                update[k] = entry_data[k]
            end
            local ok,isok,err = pcall(collect_db.safe_update, collect_db, query, {['$set'] = update})
            if not ok or not isok then
                log.error("update doc err ",isok, err)
                res_list[i] = false
            else
                res_list[i] = true
            end
        end

        return res_list
    end

    self._update_one = function(entry_data, change_map)
        for k,_ in pairs(query) do
            query[k] = entry_data[k]
        end
        local update = {}
        for k,_ in pairs(change_map) do
            update[k] = entry_data[k]
        end
        local ok,isok,err = pcall(collect_db.safe_update, collect_db, query, {['$set'] = update})
        if not ok or not isok then
            log.error("_update_one doc err ",isok, err)
            return nil
        end
        return true
    end

    self._delete = function(key_values)
        local delete_query = {}
        for i = 1,#key_values do
            local filed_name = key_list[i]
            delete_query[filed_name] = key_values[i]
        end

        local isok,err = collect_db:safe_delete(delete_query)
        if not isok then
            log.error("delete doc err ",err)
        end
        return isok
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