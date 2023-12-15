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
        _entry_data = {},
        _change_map = {},                    --变更的条目
    }

    for k,v in pairs(entry_data) do
        t._entry_data[k] = v
    end
    
    setmetatable(t, mata)
    return t
end

-- 获取条目数据的值
function M:get(filed_name)
    return self._entry_data[filed_name]
end

-- 修改条目数据的值
function M:set(filed_name, filed_value)
    if filed_value == self._entry_data[filed_name] then return end
    local ormtab = self._ormtab
    ormtab:check_one_filed(filed_name, filed_value)
    self._entry_data[filed_name] = filed_value
    self._change_map[filed_name] = true      --标记变更
end

-- 数据迭代器
function M:get_entry_data()
    return self._entry_data
end

-- 修改条目迭代器
function M:get_change_map()
    return self._change_map
end

-- 清除变更标记
function M:clear_change()
    local change_map = self._change_map
    for filed_name in pairs(change_map) do
        change_map[filed_name] = nil
    end
end

return M