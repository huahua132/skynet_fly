--唯一索引
local log = require "skynet-fly.log"
local setmetatable = setmetatable
local assert = assert
local tinsert = table.insert
local next = next

local M = {}
local mt = {__index = M}

local INVALID_POINT = {count = 0, total_count = 0}  --无效叶点
local VAILD_POINT = {count = 1, total_count = 1}    --有效叶点

function M:new(name, key_list, is_cache_all)
    local t = {
        _name = name,
        _is_cache_all = is_cache_all,   --是否永久缓存所有
        _key_list = key_list,           --key列表
        _select_map = {},               --索引表
        _cache_num_map = {},            --数量统计表
        _cache_count = 0,               --缓存总数
        _cache_total_count = nil,       --实际总数
    }

    setmetatable(t, mt)
    return t
end

--加入索引
function M:add(entry, is_add)
    --log.info("add >>> ", entry:get_entry_data(), is_add)
    local key_list = self._key_list
    local select_map = self._select_map
    local cache_num_map = self._cache_num_map
    local res_entry = entry
    local invalid = entry:is_invalid()
    local select_list = {}
    local len = #key_list
    for i = 1,len do
        local field_name = key_list[i]
        local field_value = entry:get(field_name)
        assert(field_value, "not field_value:" .. field_name)
        
        if i ~= len then
            if not select_map[field_value] then
                select_map[field_value] = {}
                cache_num_map[field_value] = {count = 0, sub_map = {}}
            end
            local one_select = {k = field_value, pv = select_map, pc = cache_num_map}
            tinsert(select_list, one_select)
            cache_num_map = cache_num_map[field_value].sub_map
            select_map = select_map[field_value]
        else
            if not select_map[field_value] then
                if invalid then
                    cache_num_map[field_value] = INVALID_POINT
                else
                    cache_num_map[field_value] = VAILD_POINT
                end
                
                select_map[field_value] = entry
                for i = #select_list, 1, -1 do
                    local one_select = select_list[i]
                    if not invalid then
                        one_select.pc[one_select.k].count = one_select.pc[one_select.k].count + 1
                    end

                    if is_add and not invalid then
                        --是添加跟着count 一起加一就行
                        if one_select.pc[one_select.k].total_count then
                            one_select.pc[one_select.k].total_count = one_select.pc[one_select.k].total_count + 1
                        end
                    end
                end

                if not invalid then
                    self._cache_count = self._cache_count + 1
                end

                if is_add and not invalid then
                    if self._cache_total_count then
                        self._cache_total_count = self._cache_total_count + 1
                    end
                end
            else
                res_entry = select_map[field_value]
                if is_add and not invalid and res_entry:is_invalid() then   --是添加并且是无效条目，替换掉
                    self:del(res_entry, true)
                    self:add(entry, true)
                    res_entry = entry
                end
            end
        end
    end

    return res_entry
end

--删除索引
function M:del(entry, is_del)
    --log.info("del >>> ", entry:get_entry_data(), is_del)
    local key_list = self._key_list
    local select_map = self._select_map
    local cache_num_map = self._cache_num_map

    local select_list = {}
    local invalid = entry:is_invalid()
    local len = #key_list
    for i = 1,len do
        local field_name = key_list[i]
        local field_value = entry:get(field_name)
        assert(field_value, "not field_value:" .. field_value)

        if i ~= len then
            if not select_map[field_value] then
                break
            end
            local one_select = {k = field_value, pv = select_map, pc = cache_num_map}
            select_map = select_map[field_value]
            cache_num_map = cache_num_map[field_value].sub_map
            one_select.sv = select_map
            tinsert(select_list, one_select)
        else
            if entry ~= select_map[field_value] then break end
            select_map[field_value] = nil
            cache_num_map[field_value] = nil
            if not invalid then
                self._cache_count = self._cache_count - 1
            end
            if is_del then
                if not invalid and self._cache_total_count then
                    self._cache_total_count = self._cache_total_count - 1
                end
            else
                --仅仅是缓存过期了
                self._cache_total_count = nil
            end
            local rm_k = nil
            for i = #select_list, 1, -1 do
                local one_select = select_list[i]
                if not invalid then
                    one_select.pc[one_select.k].count = one_select.pc[one_select.k].count - 1
                end
                if is_del then
                    --是删除跟着count 一起减一就行
                    if not invalid and one_select.pc[one_select.k].total_count then
                        one_select.pc[one_select.k].total_count = one_select.pc[one_select.k].total_count - 1
                    end
                else
                    one_select.pc[one_select.k].total_count = nil
                end
                
                if not next(one_select.sv) then  --表空了父级表应该删掉自己
                    rm_k = one_select.k
                end
                if rm_k then
                    one_select.pv[rm_k] = nil
                    one_select.pc[rm_k] = nil
                end
            end
        end
    end
end

--查询索引
function M:get(key_values)
    local select_map = self._select_map
    local cache_num_map = self._cache_num_map
    local len = #key_values

    for i = 1, len do
        local field_value = key_values[i]
        if i ~= len then
            if not select_map[field_value] then
                return
            end
            select_map = select_map[field_value]
            cache_num_map = cache_num_map[field_value].sub_map
        else

            local cache = cache_num_map[field_value]
            if not cache then return end
            if self._is_cache_all then      --永久缓存不需要对比total_count，数据全在
                if select_map[field_value] then
                    return select_map[field_value], true
                else
                    return
                end
            end

            if not cache.total_count then return select_map[field_value] end
            return select_map[field_value], cache.count == cache.total_count
        end
    end
    
    return select_map, self._cache_count == self._cache_total_count
end

--设置缓存总数
function M:set_total_count(key_values, total_count)
    local cache_num_map = self._cache_num_map                      --缓存数量
    local len = #key_values
    for i = 1, len do
        local field_value = key_values[i]
        if i ~= len then
            cache_num_map = cache_num_map[field_value].sub_map
        else
            local cache = cache_num_map[field_value]
            cache.total_count = total_count
            return
        end
    end

    self._cache_total_count = total_count
end

return M