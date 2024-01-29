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
        batch_insert_num = 10,
        batch_update_num = 10,
    }

    setmetatable(t, mata)

    return t
end

--设置单次整合批量插入的数量
function M:set_batch_insert_num(num)
    assert(num > 0)
    self.batch_insert_num = num
    return self
end

--设置单次整合批量更新的数量
function M:set_batch_update_num(num)
    assert(num > 0)
    self.batch_update_num = num
    return self
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
        --批量插入
        local res_list = {}
        local insert_list = {}
        local ref_list = {}     --引用一下，用于错误打印
        local cur = 1
        local ret_index = 1
        local len = #entry_data_list
        while true do
            if cur > len then break end
            for j = 1, self.batch_insert_num do
                if entry_data_list[cur] then
                    insert_list[j] = table_util.deep_copy(entry_data_list[cur])   --需要拷贝一下，因为 safe_batch_insert会改动原表
                    ref_list[j] = entry_data_list[cur]
                else
                    insert_list[j] = nil
                    ref_list[j] = nil
                end
                
                cur = cur + 1
            end

            if #insert_list <= 0 then break end

            local ok, isok, err = pcall(collect_db.safe_batch_insert, collect_db, insert_list)
            if ok and isok then
                for i = 1, #insert_list do
                    res_list[ret_index] = true
                    ret_index = ret_index + 1
                end
            else
                log.error("_insert err ", self._tab_name, err, ref_list)
                for i = 1, #insert_list do
                    res_list[ret_index] = false
                    ret_index = ret_index + 1
                end
            end
        end

        return res_list
    end

    --insert_one 创建一条数据
    self._insert_one = function(entry_data)
        local ok, isok, err = pcall(collect_db.raw_safe_insert, collect_db, entry_data)
        if not ok or not isok then
            log.error("_insert_one doc err ", self._tab_name, err, entry_data)
            error("_insert_one err ")
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
        local cur = 1
        local ret_index = 1
        local len = #entry_data_list
        local updates = {}
        local min_len = self.batch_update_num
        if len < min_len then
            min_len = len
        end
        for i = 1, min_len do
            updates[i] = {
                query = table_util.deep_copy(query),
                update = {
                    ['$set'] = nil,
                }
            }
        end
        while true do
            if cur > len then break end

            for i = 1, self.batch_update_num do
                local entry_data = entry_data_list[cur]
                local change_map = change_map_list[cur]
                cur = cur + 1
                if entry_data then
                    local update = updates[i]
                    for k,_ in pairs(update.query) do
                        update.query[k] = entry_data[k]
                    end

                    local up = {}
                    for k,_ in pairs(change_map) do
                        up[k] = entry_data[k]
                    end
                    update.update['$set'] = up
                else
                    updates[i] = nil
                end
            end

            if #updates <= 0 then break end

            local ok,isok,err = pcall(collect_db.safe_batch_update, collect_db, updates)
            if ok and isok then
                for i = 1, #updates do
                    res_list[ret_index] = true
                    ret_index = ret_index + 1
                end
            else
                log.error("_update err ", self._tab_name, err, updates)
                for i = 1, #updates do
                    res_list[ret_index] = false
                    ret_index = ret_index + 1
                end
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
            log.error("_update_one doc err ",self._tab_name, err)
            error("_update_one doc err")
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
            log.error("delete doc err ", self._tab_name, err)
            error("delete doc err")
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
    local ok, ret = pcall(self._select, key_values)
    if not ok then
        log.error("_select err ", self._tab_name, key_values)
        error("_select err")
    else
        return ret
    end
end

-- 查询一条表数据
function M:get_one_entry(key_values)
    local ok, ret = pcall(self._select_one, key_values)
    if not ok then
        log.error("_select_one err ", self._tab_name, key_values)
        error("_select_one err")
    else
        return ret
    end
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