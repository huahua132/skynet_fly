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
local table_util = require "skynet-fly.utils.table_util"
local log = require "skynet-fly.log"

local setmetatable = setmetatable
local assert = assert
local pairs = pairs
local error = error
local tinsert = table.insert
local tremove = table.remove
local pcall = pcall
local ipairs = ipairs
local math = math

local M = {}
local mata = {__index = M}

---#desc 新建适配器对象
---@param db_name? string 对应share_config_m 中写的key为mongo表的名为db_name的连接配置
---@param db? table 可选自己传入连接对象
---@return table obj
function M:new(db_name, db)
    local t = {
        _db = db or mongof.new_client(db_name),
        _tab_name = nil,
        _field_list = nil,
        _field_map = nil,
        _key_list = nil,
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

function M:builder(tab_name, field_list, field_map, key_list, indexs_list)
    self._tab_name = tab_name
    self._field_map = field_map
    self._key_list = key_list
    self._field_list = field_list
    self._indexs_list = indexs_list

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
        log.error("builder unique key err ", tab_name, res)
    end
    assert(res.ok == 1, "builder unique key err")

    for index_name, list in pairs(indexs_list) do
        local args = {
            unique = false,
            name = index_name,
        }
        for _,field_name in ipairs(list) do
            tinsert(args, {[field_name] = 1})
        end
        local res = collect_db:create_index(args)
        if res.ok ~= 1 then
            log.error("builder index err ", tab_name, res)
        end
        assert(res.ok == 1, "builder index err")
    end

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
                    entry_data_list[ret_index]._id = nil
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
        entry_data._id = nil
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

        if cursor then
            if sort == 1 then   --升序
                args[end_field_name] = { ['$gt'] = cursor }
            else                --降序 
                args[end_field_name] = { ['$lt'] = cursor }
            end
        end

        local res_list = {}
        local ret = collect_db:find(args, only_keys):sort({[end_field_name] = sort}):limit(limit)
        while ret:has_next() do
            local entry_data = ret:next()
            entry_data._id = nil
            tinsert(res_list, entry_data)
        end

        local cursor = nil
        if #res_list > 0 then
            local end_ret = res_list[#res_list]
            cursor = end_ret[end_field_name]
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
            log.error("delete doc err ", self._tab_name, key_values, err)
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

    self._batch_delete = function(keys_list)
        local len = #keys_list[1]
        local res_list = {}
        local total_len = #keys_list
        local batch = math.ceil(total_len / self.batch_delete_num)

        local args_tmp_list = {}
        for i = 1, self.batch_delete_num do
            local one_args = {}
            for j = 1, len do
                one_args[key_list[j]] = 0
            end
            args_tmp_list[i] = one_args
        end

        for i = 1, batch do
            local end_index = i * self.batch_delete_num
            local start_index = end_index - self.batch_delete_num + 1

            local args = {}
            local count = 0
            for j = start_index, end_index do
                local key_values = keys_list[j]
                if key_values then
                    count = count + 1
                    local one = args_tmp_list[count]
                    for k = 1, #key_values do
                        one[key_list[k]] = key_values[k]
                    end
                    tinsert(args, one)
                else
                    break
                end
            end

            if #args <= 0 then break end

            local isok, err = collect_db:safe_batch_delete(args)
            if isok then
                for i = 1, count do
                    res_list[start_index + i - 1] = true
                end
            else
                log.error("_batch_delete err ", self._tab_name, err, args)
                for i = 1, count do
                    res_list[start_index + i - 1] = false
                end
            end
        end
        
        return res_list
    end

    self._batch_delete_by_range = function(query_list)
        local first_query = query_list[1]
        local len = #first_query.key_values
        local first_left = first_query.left
        local first_right = first_query.right
        local res_list = {}
        local total_len = #query_list
        local batch = math.ceil(total_len / self.batch_delete_num)
        local end_field_name = key_list[len + 1]
        local args_tmp_list = {}
        for i = 1, self.batch_delete_num do
            local one_args = {}
            for j = 1, len do
                one_args[key_list[j]] = 0
            end
            one_args[end_field_name] = {}
            if first_left then
                one_args[end_field_name]['$gte'] = 0
            end
            if first_right then
                one_args[end_field_name]['$lte'] = 0
            end
            args_tmp_list[i] = one_args
        end

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
                    local one = args_tmp_list[count]
                    for k = 1, #key_values do
                        one[key_list[k]] = key_values[k]
                    end
                    if query.left then
                        one[end_field_name]['$gte'] = query.left
                    end
                    if query.right then
                        one[end_field_name]['$lte'] = query.right
                    end
                    tinsert(args, one)
                else
                    break
                end
            end

            if #args <= 0 then break end

            local isok, err = collect_db:safe_batch_delete(args)
            if isok then
                for i = 1, count do
                    res_list[start_index + i - 1] = true
                end
            else
                log.error("safe_batch_delete err ", self._tab_name, err, args)
                for i = 1, count do
                    res_list[start_index + i - 1] = false
                end
            end
        end
        
        return res_list
    end

    self._idx_select = function(query)
        local res_list = {}

        local ret = collect_db:find(query)
        while ret:has_next() do
            local entry_data = ret:next()
            entry_data._id = nil
            tinsert(res_list, entry_data)
        end
    
        return res_list
    end

    self._idx_get_entry_by_limit = function(cursor, limit, sort, sort_field_name, query, next_offset)
        query = query or {}
        local end_field_name = sort_field_name

        local count = nil
        if not cursor then
            count = collect_db:find(query):count()
        end

        local use_query = table_util.copy(query)
        if cursor then
            if sort == 1 then   --升序
                use_query[end_field_name] = { ['$gte'] = cursor }
            else                --降序 
                use_query[end_field_name] = { ['$lte'] = cursor }
            end
        end

        local res_list = {}
        local ret = collect_db:find(use_query):sort({[end_field_name] = sort}):skip(next_offset or 0):limit(limit)
        while ret:has_next() do
            local entry_data = ret:next()
            entry_data._id = nil
            tinsert(res_list, entry_data)
        end

        local next_cursor = nil
        local pre_offset = next_offset
        next_offset = 0
        if #res_list > 0 then
            local end_ret = res_list[#res_list]
            next_offset = 1
            next_cursor = end_ret[end_field_name]
            for i = #res_list - 1, 1, -1 do
                local one_ret = res_list[i]
                if one_ret[end_field_name] == next_cursor then
                    next_offset = next_offset + 1
                else
                    break
                end
            end
            if cursor == next_cursor and pre_offset then
                next_offset = next_offset + pre_offset
            end
        end

        return next_cursor, res_list, count, next_offset
    end

    self._idx_delete_entry = function(query)
        local isok,err = collect_db:safe_delete(query)
        if not isok then
            log.error("_idx_delete_entry doc err ", self._tab_name, query, err)
            error("_idx_delete_entry doc err")
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