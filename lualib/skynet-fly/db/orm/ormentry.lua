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

-- 获取条目数据的值
function M:get(field_name)
    return self._entry_data[field_name]
end

-- 修改条目数据的值
function M:set(field_name, field_value)
    local ormtab = self._ormtab
    if field_value == self._entry_data[field_name] and not ormtab:is_table_field(field_name) then return end
 
    ormtab:check_one_field(field_name, field_value)
    self._entry_data[field_name] = field_value
    self._change_map[field_name] = true      --标记变更
    ormtab:set_change_entry(self)
end

-- 获取数据表
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