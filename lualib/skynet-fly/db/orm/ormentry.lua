---#API
---#content ---
---#content title: orm条目
---#content date: 2024-06-29 22:00:00
---#content categories: ["skynet_fly API 文档","数据库相关"]
---#content category_bar: true
---#content tags: [skynet_fly_api]
---#content ---
---#content [ormentry](https://github.com/huahua132/skynet_fly/blob/master/lualib/skynet-fly/db/orm/ormentry.lua)

local setmetatable = setmetatable
local pairs = pairs

local M = {}
local mata = {
    __index = M,
}

-- 新建条目数据
function M:new(ormtab, entry_data)
    local t = {
        _ormtab = ormtab,
        _entry_data = entry_data,
        _change_map = {},                    --变更的条目
    }
    
    setmetatable(t, mata)
    return t
end

--新增无效条目数据 用于防止缓存穿透
function M:new_invalid(entry_data)
    local t = {
        _entry_data = entry_data,
        _invalid = true,
    }
    
    setmetatable(t, mata)
    return t
end

---#desc 获取条目数据的值
---@param field_name string 字段名
---@return any 字段值
function M:get(field_name)
    return self._entry_data[field_name]
end

---#desc 修改条目数据的值
---@param field_name string 字段名
---@param field_value any 字段值
function M:set(field_name, field_value)
    local ormtab = self._ormtab
    if field_value == self._entry_data[field_name] and not ormtab:is_table_field(field_name) then return end
 
    ormtab:check_one_field(field_name, field_value)
    self._entry_data[field_name] = field_value
    self._change_map[field_name] = true      --标记变更
    ormtab:set_change_entry(self)
end

---#desc 获取整个数据表
---@return table
function M:get_entry_data()
    return self._entry_data
end

-- 获取修改条目
function M:get_change_map()
    return self._change_map
end

-- 清除变更标记
function M:clear_change()
    local change_map = self._change_map
    if not change_map then return end
    for field_name in pairs(change_map) do
        change_map[field_name] = nil
    end
end

--是否无效条目
function M:is_invalid()
    return self._invalid
end

return M