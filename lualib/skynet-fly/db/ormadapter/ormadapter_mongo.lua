---#API
---#content ---
---#content title: orm mongo适配器
---#content date: 2024-06-29 22:00:00
---#content categories: ["skynet_fly API 文档","数据库相关"]
---#content category_bar: true
---#content tags: [skynet_fly_api]
---#content ---
---#content [ormadapter_mongo](https://github.com/huahua132/skynet_fly/blob/master/lualib/skynet-fly/db/ormadapter/ormadapter_mongo.lua)

local mongof = require "skynet-fly.db.mongof"
local log = require "skynet-fly.log"

local setmetatable = setmetatable
local assert = assert
local pairs = pairs
local error = error
local tinsert = table.insert
local tremove = table.remove
local pcall = pcall
local ipairs = ipairs

local M = {}
local mata = {__index = M}

---#desc 新建适配器对象
---@param db_name string 对应share_config_m 中写的key为mongo表的名为db_name的连接配置
---@return table obj
function M:new(db_name)
    local t = {
        _db = mongof.new_client(db_name),
        _tab_name = nil,
        _field_list = nil,
        _field_map = nil,
        _key_list = nil,
        batch_insert_num = 10,
        batch_update_num = 10,
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

function M:builder(tab_name, field_list, field_map, key_list)
    self._tab_name = tab_name
    self._field_map = field_map
    self._key_list = key_list
    self._field_list = field_list

    local args = {}
    local index_name = "index"
    for i = 1,#key_list do
        local field_name = key_list[i]
        tinsert(args, {[field_name] = 1})
        index_name = index_name .. "_" .. field_name
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
                    insert_list[j] = entry_data_list[cur]
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
        local isok, err = collect_db:safe_insert(entry_data)
        if not isok then
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

    -- _select_in IN查询
    self._select_in = function(in_values, key_values)
        local args = {}
        local len = #key_values
        for i = 1, len do
            args[key_list[i]] = key_values[i]
        end

        local end_field_name = key_list[len + 1]
        args[end_field_name] = {["$in"] = in_values}

        local res_list = {}
        local ret = collect_db:find(args)
        while ret:has_next() do
            local entry_data = ret:next()
            entry_data._id = nil
            tinsert(res_list, entry_data)
        end

        return res_list
    end

    -- 分页查询
    local only_keys_map = {}
    for _,key_name in ipairs(key_list) do
        only_keys_map[key_name] = 1
    end
    self._select_limit = function(cursor, limit, sort, key_values, is_only_key)
        local args = {}
        local len = #key_values
        for i = 1, len do
            args[key_list[i]] = key_values[i]
        end
        local end_field_name = key_list[len + 1]

        local only_keys = nil
        if is_only_key then
            only_keys = only_keys_map
        end

        local count = nil
        if not cursor then
            count = collect_db:find(args):count()
        end

        local res_list = {}
        local ret = collect_db:find(args, only_keys):sort({[end_field_name] = sort}):skip(cursor or 0):limit(limit)
        while ret:has_next() do
            local entry_data = ret:next()
            entry_data._id = nil
            tinsert(res_list, entry_data)
        end

        if #res_list > 0 then
            cursor = (cursor or 0) + limit
        else
            cursor = nil
        end
        
        return cursor, res_list, count
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
                query = {},
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
                    for k,_ in pairs(query) do
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
        
        local isok,err = collect_db:safe_update(query, {['$set'] = update})
        if not isok then
            log.error("_update_one doc err ",self._tab_name, err, update)
            error("_update_one doc err")
        end

        return true
    end

    self._delete = function(key_values)
        local delete_query = {}
        for i = 1,#key_values do
            local field_name = key_list[i]
            delete_query[field_name] = key_values[i]
        end

        local isok,err = collect_db:safe_delete(delete_query)
        if not isok then
            log.error("delete doc err ", self._tab_name, err)
            error("delete doc err")
        end
        return true
    end

    self._delete_by_range = function(left, right, key_values)
        local delete_query = {}

        local len = #key_values
        for i = 1,len do
            local field_name = key_list[i]
            delete_query[field_name] = key_values[i]
        end
        
        local end_field_name = key_list[len + 1]
        delete_query[end_field_name] = {['$gte'] = left, ['$lte'] = right}
        local isok,err = collect_db:safe_delete(delete_query)
        if not isok then
            log.error("_delete_by_range doc err ", self._tab_name, err)
            error("_delete_by_range doc err")
        end
        return true
    end

    self._delete_in = function(in_values, key_values)
        local args = {}
        local len = #key_values
        for i = 1, len do
            args[key_list[i]] = key_values[i]
        end

        local end_field_name = key_list[len + 1]
        args[end_field_name] = {["$in"] = in_values}

        local isok,err = collect_db:safe_delete(args)
        if not isok then
            log.error("_delete_in doc err ", self._tab_name, err)
            error("_delete_in doc err")
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
        log.error("_select err ", ret, self._tab_name, key_values)
        error("_select err", ret)
    else
        return ret
    end
end

-- 查询一条表数据
function M:get_one_entry(key_values)
    local ok, ret = pcall(self._select_one, key_values)
    if not ok then
        log.error("_select_one err ", ret, self._tab_name, key_values)
        error("_select_one err", ret)
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

-- IN 查询
function M:get_entry_by_in(in_values, key_values)
    local ok, ret = pcall(self._select_in, in_values, key_values)
    if not ok then
        log.error("_select_in err ", ret, self._tab_name, in_values, key_values)
        error("_select_in err", ret)
    else
        return ret
    end
end

-- 分页查询
function M:get_entry_by_limit(cursor, limit, sort, key_values, is_only_key)
    local ok, cursor, res_list, count = pcall(self._select_limit, cursor, limit, sort, key_values, is_only_key)
    if not ok then
        log.error("_select_limit err ", cursor, self._tab_name, cursor, limit, sort, key_values, is_only_key)
        error("_select_limit err", cursor)
    else
        return cursor, res_list, count
    end
end

-- 范围删除
function M:delete_entry_by_range(left, right, key_values)
    return self._delete_by_range(left, right, key_values)
end

-- IN 删除
function M:delete_entry_by_in(in_values, key_values)
    return self._delete_in(in_values, key_values)
end

return M