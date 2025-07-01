---#API
---#content ---
---#content title: orm表
---#content date: 2024-06-29 22:00:00
---#content categories: ["skynet_fly API 文档","数据库相关"]
---#content category_bar: true
---#content tags: [skynet_fly_api]
---#content ---
---#content [ormtable](https://github.com/huahua132/skynet_fly/blob/master/lualib/skynet-fly/db/orm/ormtable.lua)

---@diagnostic disable: need-check-nil, assign-type-mismatch, param-type-mismatch
local ormentry = require "skynet-fly.db.orm.ormentry"
local table_util = require "skynet-fly.utils.table_util"
local math_util = require "skynet-fly.utils.math_util"
local mult_queue = require "skynet-fly.mult_queue"
local tti = require "skynet-fly.cache.tti"
local timer = require "skynet-fly.timer"
local skynet = require "skynet"
local log = require "skynet-fly.log"
local unique_index = require "skynet-fly.db.orm.unique_index"

local setmetatable = setmetatable
local assert = assert
local tinsert = table.insert
local tremote = table.remove
local tsort = table.sort
local tconcat = table.concat
local pairs = pairs
local type = type
local ipairs = ipairs
local sformat = string.format
local next = next
local tostring = tostring

local FIELD_TYPE = {
    int8         = 1,
    int16        = 2,
    int32        = 3,
    int64        = 4,
   
    uint8        = 11,
    uint16       = 12,
    uint32       = 13,
   
    string32     = 31,
    string64     = 32,
    string128    = 33,
    string256    = 34,
    string512    = 35,
    string1024   = 36,
    string2048   = 37,
    string4096   = 38,
    string8192   = 39,

    text         = 51,
    blob         = 52,
    table        = 53,
}

local FIELD_LUA_DEFAULT = {
    [FIELD_TYPE.int8] = 0,
    [FIELD_TYPE.int16] = 0,
    [FIELD_TYPE.int32] = 0,
    [FIELD_TYPE.int64] = 0,
    [FIELD_TYPE.uint8] = 0,
    [FIELD_TYPE.uint16] = 0,
    [FIELD_TYPE.uint32] = 0,

    [FIELD_TYPE.string32] = "",
    [FIELD_TYPE.string64] = "",
    [FIELD_TYPE.string128] = "",
    [FIELD_TYPE.string256] = "",
    [FIELD_TYPE.string512] = "",
    [FIELD_TYPE.string1024] = "",
    [FIELD_TYPE.string2048] = "",
    [FIELD_TYPE.string4096] = "",
    [FIELD_TYPE.string8192] = "",

    [FIELD_TYPE.text] = "",
    [FIELD_TYPE.blob] = "",
    [FIELD_TYPE.table] = {},
}

--不能为index key的类型
local CANT_INDEX_TYPE_MAP = {
    [FIELD_TYPE.string1024] = true,
    [FIELD_TYPE.string2048] = true,
    [FIELD_TYPE.string4096] = true,
    [FIELD_TYPE.string8192] = true,

    [FIELD_TYPE.text] = true,
    [FIELD_TYPE.blob] = true,
    [FIELD_TYPE.table] = true,
}

--互斥的符合
local g_REPEL_SYMBOL = {
    ['$gt'] = '$gte', --  >
    ['$gte'] = '$gt', --  >=
    ['$lt'] = '$lte', --  <
    ['$lte'] = '$lt', --  <=
}

local function create_check_str(len)
    return function(str)
        if type(str) ~= 'string' then return false end
        return str:len() <= len
    end
end

local FIELD_TYPE_CHECK_FUNC = {
    [FIELD_TYPE.int8] = math_util.is_vaild_int8,
    [FIELD_TYPE.int16] = math_util.is_vaild_int16,
    [FIELD_TYPE.int32] = math_util.is_vaild_int32,
    [FIELD_TYPE.int64] = math_util.is_vaild_int64,
    [FIELD_TYPE.uint8] = math_util.is_vaild_uint8,
    [FIELD_TYPE.uint16] = math_util.is_vaild_uint16,
    [FIELD_TYPE.uint32] = math_util.is_vaild_uint32,

    [FIELD_TYPE.string32] = create_check_str(32),
    [FIELD_TYPE.string64] = create_check_str(64),
    [FIELD_TYPE.string128] = create_check_str(128),
    [FIELD_TYPE.string256] = create_check_str(256),
    [FIELD_TYPE.string512] = create_check_str(512),
    [FIELD_TYPE.string1024] = create_check_str(1024),
    [FIELD_TYPE.string2048] = create_check_str(2048),
    [FIELD_TYPE.string4096] = create_check_str(4096),
    [FIELD_TYPE.string8192] = create_check_str(8192),

    [FIELD_TYPE.text] = function(str) return type(str) == 'string' end,
    [FIELD_TYPE.blob] = function(str) return type(str) == 'string' end,
    [FIELD_TYPE.table] = function(tab) return type(tab) == 'table' end,
}

local function add_field_name_type(t,field_name,field_type)
    assert(field_name, "not field_name")
    assert(not t._field_map[field_name], "field_name is exists :" .. field_name)

    t._field_map[field_name] = field_type
    tinsert(t._field_list, field_name)
    return t
end

-- 检查一条数据的合法性
local function check_one_field(t, field_name, field_value)
    local field_type = assert(t._field_map[field_name], "not exists field_name = " .. field_name)
    local check_func = assert(FIELD_TYPE_CHECK_FUNC[field_type], "not check func : ".. field_type)
    local ktype = type(field_name)
    assert(ktype == "string", sformat("tab_name[%s] set invalid field_name type field_name[%s] value[%s] field_type[%s]", t._tab_name, field_name, field_value, field_type))                       --字段名必须是string
    assert(check_func(field_value),sformat("tab_name[%s] set invalid value field_name[%s] value[%s] field_type[%s]", t._tab_name, field_name, field_value, field_type))
end

-- 检查数据表的合法性
local function check_fields(t,entry_data)
    for _,field_name in ipairs(t._keylist) do
        assert(entry_data[field_name], "not set key value:" .. field_name)                  --key字段值必须有值
    end

    for field_name,field_value in pairs(entry_data) do
        check_one_field(t, field_name, field_value)
    end
end

local function queue_doing(t, key1value, func, ...)
    if key1value then
        return t._queue:multi(key1value, func, ...)
    else
        return t._queue:unique(func, ...)
    end
end

local get_entry = nil       --function
local save_entry = nil      --function

-- 添加进key索引表
local function add_key_select(t, entry, is_add)
    if not t._cache_time then return entry end
    local res_entry = t._main_index:add(entry, is_add)

    if t._cache_map then
        if res_entry ~= entry then
            t._cache_map:update_cache(res_entry, t)
        else
            t._cache_map:set_cache(res_entry, t)
        end
    end

    return res_entry
end

-- 设置total_count
local function set_total_count(t, key_values, total_count)
    if not t._cache_time then return end
    t._main_index:set_total_count(key_values, total_count)
end

-- 查询key索引表
local function get_key_select(t, key_values)
    if not t._cache_time then return end
    return t._main_index:get(key_values)
end

-- 删除掉key索引表
local function del_key_select(t, entry, is_del)
    if not t._cache_time then return end
    t._main_index:del(entry, is_del)

    if t._cache_map then
        t._cache_map:del_cache(entry)
    end
end

local function init_entry_data(t, entry_data, is_old)
    local new_entry_data = nil
    if is_old then
        new_entry_data = entry_data
    else
        new_entry_data = {}
    end
    
    local field_list = t._field_list
    local field_map = t._field_map
    for i = 1,#field_list do
        local fn = field_list[i]
        local ft = field_map[fn]
        if entry_data[fn] then
            new_entry_data[fn] = entry_data[fn]
        else
            if ft ~= FIELD_TYPE.table then
                new_entry_data[fn] = FIELD_LUA_DEFAULT[ft]
            else
                new_entry_data[fn] = {}
            end
        end
    end
    return new_entry_data
end

local M = {
    FIELD_TYPE = FIELD_TYPE,
    FIELD_LUA_DEFAULT = FIELD_LUA_DEFAULT,
}
local mata = {__index = M, __gc = function(t)
    if t._time_obj then
        t._time_obj:cancel()
    end
end}

---#desc 新建表对象
---@param tab_name string 作用与数据库的表名
---@return table obj
function M:new(tab_name)
    local t = {
        _queue = mult_queue:new(),                           --操作队列
        _tab_name = tab_name,                       --表名
        _field_list = {},
        _field_map = {},                            --所有字段
        _key_map = {},
        _keylist = {},                              --key列表
        _index_list_map = {},                       --普通索引表
        _indexs_list = {},                          --普通索引列表

        _is_builder = false,

        _main_index = nil,                          --主键索引

        -- 缓存时间
        _cache_time = nil,

        -- 变更的标记
        _change_flag_map = {},
    }
    setmetatable(t, mata)
    return t
end

---#desc 设置字段 FIELD_TYPE对应字段类型 有 int8|int16|int32|int64|uint8|uint16|uint32|string32|string64|string128|string256|string512|string1024|string2048|string4096|string8192|text|blob|table
---@param field_name string 字段名
---@return table obj
function M:___FIELD_TYPE(field_name)
    --这个函数只是用于写文档的
    error("call invalid func")
end

do
    for type_name,type_enum in pairs(FIELD_TYPE) do
        M[type_name] = function(self, field_name)
            add_field_name_type(self, field_name, type_enum)
            return self
        end
    end
end

---#desc 设置主键
---@param ... string 字段名列表 填入遵从最左前缀原则
---@return table obj
function M:set_keys(...)
    assert(not self._is_builder, "builded can`t set_keys")
    local list = {...}
    for i = 1,#list do
        local field_name = list[i]
        assert(self._field_map[field_name], "not exists: ".. field_name)
        assert(not self._key_map[field_name], "is exists: ".. field_name)
        local field_type = self._field_map[field_name]
        assert(not CANT_INDEX_TYPE_MAP[field_type], "can`t key type " .. field_name)
        tinsert(self._keylist, field_name)
        self._key_map[field_name] = true
    end
    return self
end

---#desc 设置普通索引
---@param index_name string 索引名称
---@param ... string[] 字段名列表 建立关联索引 填入遵从最左前缀原则
---@return table obj
function M:set_index(index_name, ...)
    assert(not self._is_builder, "builded can`t set_index")
    local list = {...}
    local repeat_check = {}
    for i = 1,#list do
        local field_name = list[i]
        assert(self._field_map[field_name], "not exists: ".. field_name)
        local field_type = self._field_map[field_name]
        assert(not CANT_INDEX_TYPE_MAP[field_type], "can`t key type " .. field_name)
        assert(not repeat_check[field_name], "repeat field_name: " .. field_name)
        repeat_check[field_name] = true
    end
    
    local indexs_list = self._indexs_list
    local index_list_map = self._index_list_map
    for i = 1,#list do
        local field_name = list[i]
        if not index_list_map[field_name] then
            index_list_map[field_name] = {}
        end
        index_list_map = index_list_map[field_name]
    end

    indexs_list[index_name] = list
    return self
end

--定期保存修改
local function inval_time_out(week_t, is_save_now)
    local t = next(week_t)
    if not t then return end
    if t._inval_saveting then return end
    t._inval_saveting = true
    local change_flag_map = t._change_flag_map
    local cur_count = 0
    local once_save = 100
    local resave_cnt_map = {}
    local last_warn_cnt_map = {}
    local init_warn_cnt = 5
    while next(change_flag_map) do
        cur_count = 0
        local entry_list = {}
        for entry in pairs(change_flag_map) do
            tinsert(entry_list, entry)
            change_flag_map[entry] = nil
            cur_count = cur_count + 1
            if cur_count >= once_save then
                break
            end
        end

        local is_have_fail = false
        local res_list = nil
        if not is_save_now then                     --避免muit锁冲突问题
            res_list = t:save_entry(entry_list)
        else
            res_list = save_entry(t, entry_list)
        end
       
        for i = 1, #entry_list do
            local res = res_list[i]
            local entry = entry_list[i]
            if not res then
                is_have_fail = true
                change_flag_map[entry] = true      --没有保存成功，下次继续尝试
                if not resave_cnt_map[entry] then
                    resave_cnt_map[entry] = 0
                    last_warn_cnt_map[entry] = init_warn_cnt
                end
                resave_cnt_map[entry] = resave_cnt_map[entry] + 1
                if resave_cnt_map[entry] > last_warn_cnt_map[entry] then
                    last_warn_cnt_map[entry] = last_warn_cnt_map[entry] * init_warn_cnt
                    log.warn("inval_time_out save entry err ", resave_cnt_map[entry], entry:get_entry_data())
                end
            end
        end
        if is_have_fail then
            skynet.sleep(100) --避免失败了请求太过频繁
        end
    end
    t._inval_saveting = false
end

local function excute_time_out(t, entry)
    local change_flag_map = t._change_flag_map
    if change_flag_map[entry] then
        --还没保存数据 还不能清除
        t._cache_map:set_cache(entry, t)   --重新设置缓存
        skynet.fork(inval_time_out, t._week_t)
    else
        if entry:is_invalid() then
            del_key_select(t, entry, true)
        else
            del_key_select(t, entry)
        end
    end
end

local function get_key1value(t, entry_data)
    local field_name = t._keylist[1]
    local key1value = nil
    if field_name then
        key1value = entry_data[field_name]
    end
    return key1value
end

--缓存到期
local function cache_time_out(entry, t)
    local key1value = get_key1value(t, entry:get_entry_data())
    queue_doing(t, key1value, excute_time_out, t, entry)
end

--检查key values 是否合法
local function check_key_values(t, key_values)
    local keylist = t._keylist
    for i = 1,#key_values do
        local field_name = keylist[i]
        local value = key_values[i]
        check_one_field(t, field_name, value)
    end
end

-- 生成无效数据
local function create_invalid_entry(t, key_values)
    --无效数据，只需要添加key的数据就行
    local keylist = t._keylist
    local field_map = t._field_map
    local data = {}
    for i = 1, #keylist do
        local field_name = keylist[i]
        local ft = field_map[field_name]
        local field_value = key_values[i] or FIELD_LUA_DEFAULT[ft]
        data[field_name] = field_value
    end

    return ormentry:new_invalid(data)
end

local week_mata = {__mode = "kv"}
---#desc 设置缓存时间
---@param expire number 过期时间 100表示1秒 get_*相关接口会重置对应被获取的entry的过期时间
---@param inval number 被修改后的保存检查间隔 调用了entry:set 
---@param cache_limit number 缓存总量限制，超出会优先释放快到期的缓存
---@return table obj
function M:set_cache(expire, inval, cache_limit)
    if cache_limit then
        assert(cache_limit > 0, "err cache_limit " .. tostring(cache_limit))
    end
    assert(not self._is_builder, "builded can`t set_cache")
    assert(not self._time_obj, "repeat time_obj")
    assert(expire >= 0, "err expire " .. expire)                 --缓存时间
    assert(inval > 0, "err inval")                               --自动保存间隔
    self._cache_time = expire

    if expire > 0 then                                           --0表示缓存不过期
        self._cache_map = tti:new(expire, cache_time_out, cache_limit)
    end
    
    local week_t = setmetatable({},week_mata)                   --挂载一个弱引用表
    week_t[self] = true
    self._time_obj = timer:new(inval, 0, inval_time_out, week_t)
    self._time_obj:after_next()
    self._week_t = week_t
    return self
end

local function builder(t, adapterinterface)
    assert(not t._is_builder, "builded can`t builder")
    t._adapterinterface = adapterinterface       --数据适配接口

    local tab_name = t._tab_name --表名
    local field_map = t._field_map
    local field_list = t._field_list
    local key_list = t._keylist
    local indexs_list = t._indexs_list

    t._main_index = unique_index:new("main_index", key_list, t._cache_time == 0)
    
    t._is_builder = true

    adapterinterface:builder(tab_name, field_list, field_map, key_list, indexs_list)
    return t
end

---#desc 构建表
---@param adapterinterface number 数据库适配接口
---@return table obj
function M:builder(adapterinterface)
    assert(#self._keylist > 0, "not set keys")      --没有设置主键
    if self._cache_time ~= 0 then
        return queue_doing(self, nil, builder, self, adapterinterface)
    else
        local ret = queue_doing(self, nil, builder, self, adapterinterface)
        local entry_list = queue_doing(self, nil, get_entry, self, {}, true)  --永久缓存，构建查询出所有数据
        if not entry_list then
            return nil
        else
            return ret
        end
    end 
end

local function create_entry(t, list)
    local entry_data_list = {}
    for _,entry_data in ipairs(list) do
        check_fields(t, entry_data)
        tinsert(entry_data_list, init_entry_data(t, entry_data))
    end
    local ret_list = t._adapterinterface:create_entry(entry_data_list)
    assert(#ret_list == #entry_data_list, "result len not same " .. #ret_list .. ':' .. #entry_data_list)
    local new_entry_list = {}
    for i,entry_data in ipairs(entry_data_list) do
        if ret_list[i] then
            local new_entry = ormentry:new(t, entry_data)
            -- 建立key关联
            tinsert(new_entry_list, add_key_select(t, new_entry, true))
        else
            tinsert(new_entry_list, false)
        end
    end

    return new_entry_list
end

local function create_one_entry(t, entry_data)
    entry_data = init_entry_data(t, entry_data)

    local ret = t._adapterinterface:create_one_entry(entry_data)
    if not ret then return nil end

    local new_entry = ormentry:new(t, entry_data)
    return add_key_select(t, new_entry, true)
end

-- 检查数据合法性
function M:check_one_field(field_name, field_value)
    --主键 索引值不能改变
    local key_map = self._key_map
    assert(not key_map[field_name], "can`t change key value")

    check_one_field(self, field_name, field_value)
end

-- 设置变更标记
function M:set_change_entry(entry)
    if not self._time_obj then return end
    self._change_flag_map[entry] = true
end

-- 是否table
function M:is_table_field(field_name)
    local field_map = self._field_map
    local ft = field_map[field_name]
    return ft == FIELD_TYPE.table
end

get_entry = function(t, key_values, is_init_get_all)
    local key_list = t._keylist
    local entry_list = {}
    local depth = #key_list - #key_values
    local entry_list_map,is_cache_all = get_key_select(t, key_values)
    if not is_cache_all then
        --永久 缓存没有就是没有
        if t._cache_time == 0 and not is_init_get_all then  --不是永久缓存初始化拉取
            return entry_list, true
        else
            local entry_data_list = t._adapterinterface:get_entry(key_values)
            if not is_init_get_all and(not entry_data_list or not next(entry_data_list)) then
                --添加无效条目站位，防止缓存穿透
                local invalid_entry = create_invalid_entry(t, key_values)
                add_key_select(t, invalid_entry)
                set_total_count(t, key_values, 0)
                return entry_list, false
            else
                for i = 1,#entry_data_list do
                    local entry_data = init_entry_data(t, entry_data_list[i], true)
                    local entry = ormentry:new(t, entry_data)
                    tinsert(entry_list, add_key_select(t, entry))
                end
                set_total_count(t, key_values, #entry_data_list)
                return entry_list, false
            end
        end
    else
        if depth > 0 then
            entry_list = table_util.depth_to_list(entry_list_map, depth)
        else
            entry_list = {entry_list_map}
        end

        if t._cache_map then
            for _,entry in ipairs(entry_list) do
                t._cache_map:update_cache(entry, t)
            end
        end

        --剔除无效条目
        for i = #entry_list, 1, -1 do
            local entry = entry_list[i]
            if entry:is_invalid() then
                tremote(entry_list, i)
            end
        end
        return entry_list, true
    end    
end

local function get_one_entry(t, key_values)
    local entry, is_cache = get_key_select(t, key_values)
    if not is_cache then
        --永久 缓存没有就是没有
        if t._cache_time == 0 then
            return nil, true
        else
            local entry_data = t._adapterinterface:get_one_entry(key_values)
            if not entry_data then
                --添加无效条目站位，防止缓存穿透
                local invalid_entry = create_invalid_entry(t, key_values)
                add_key_select(t, invalid_entry)
                return nil, false
            else
                entry = ormentry:new(t, init_entry_data(t, entry_data, true))
                return add_key_select(t, entry)
            end
        end
    end

    if entry and t._cache_map then
        t._cache_map:update_cache(entry, t)
    end

    if entry and entry:is_invalid() then
        entry = nil
    end
    return entry, true
end

local function get_entry_by_in(t, _in_values, key_values)
    local in_values = table_util.copy(_in_values)
    local key_list = t._keylist
    local res_entry_list = {}
    local kv_len = #key_values
    local in_field_name = key_list[kv_len + 1]
    local depth = #key_list - kv_len - 1
    for i = #in_values, 1, -1 do
        local v = in_values[i]
        key_values[kv_len + 1] = v
        local entry_list_map,is_cache_all = get_key_select(t, key_values)
        if is_cache_all then
            local entry_list = {}
            if depth > 0 then
                entry_list = table_util.depth_to_list(entry_list_map, depth)
            else
                entry_list = {entry_list_map}
            end
    
            if t._cache_map then
                for _,entry in ipairs(entry_list) do
                    t._cache_map:update_cache(entry, t)
                end
            end
    
            --剔除无效条目
            for i = #entry_list, 1, -1 do
                local entry = entry_list[i]
                if not entry:is_invalid() then
                   tinsert(res_entry_list, entry) 
                end
            end
            tremote(in_values, i)
        end
    end

    if #in_values > 0 then
        --永久 缓存没有就是没有
        if t._cache_time == 0 then
            return res_entry_list, true
        else
            key_values[kv_len + 1] = nil
            local entry_data_list = t._adapterinterface:get_entry_by_in(in_values, key_values)
            local in_v_count_map = {}
            local in_v_cnt = 0
            for i = 1,#entry_data_list do
                local entry_data = init_entry_data(t, entry_data_list[i], true)
                local entry = ormentry:new(t, entry_data)
                tinsert(res_entry_list, add_key_select(t, entry))
                local inv = entry_data[in_field_name]
                if not in_v_count_map[inv] then
                    in_v_count_map[inv] = 0
                    in_v_cnt = in_v_cnt + 1
                end
                in_v_count_map[inv] = in_v_count_map[inv] + 1
            end

            for inv, count in pairs(in_v_count_map) do
                key_values[kv_len + 1] = inv
                set_total_count(t, key_values, count)
            end

            --添加无效条目站位，防止缓存穿透
            if in_v_cnt ~= #in_values then
                for i = 1, #in_values do
                    local v = in_values[i]
                    if not in_v_count_map[v] then
                        key_values[kv_len + 1] = v
                        local invalid_entry = create_invalid_entry(t, key_values)
                        add_key_select(t, invalid_entry)
                        set_total_count(t, key_values, 0)
                    end
                end
            end
            return res_entry_list, false
        end
    end

    return res_entry_list, true
end

local function get_entry_by_limit(t, cursor, limit, sort, key_values)
    if t._cache_time then
        local cursor, entry_keys_value_list, count = t._adapterinterface:get_entry_by_limit(cursor, limit, sort, key_values, true)
        local in_values = {}
        local len = #key_values + 1
        local in_field_name = t._keylist[len]
        for i = 1, #entry_keys_value_list do
            tinsert(in_values, entry_keys_value_list[i][in_field_name])
        end
        
        local entry_list = get_entry_by_in(t, in_values, key_values)
        if sort == 1 then   --升序 从小到大
            tsort(entry_list, function(a,b) 
                local a_v = a:get(in_field_name)
                local b_v = b:get(in_field_name)
                return a_v < b_v
            end)
        else                --降序 从大到小
            tsort(entry_list, function(a,b) 
                local a_v = a:get(in_field_name)
                local b_v = b:get(in_field_name)
                return a_v > b_v
            end)
        end
        return cursor, entry_list, count
    else
        local cursor, entry_data_list, count = t._adapterinterface:get_entry_by_limit(cursor, limit, sort, key_values)
        for i = 1, #entry_data_list do
            local entry_data = entry_data_list[i]
            local entry = ormentry:new(t, init_entry_data(t, entry_data, true))
            entry_data_list[i] = entry
        end

        return cursor, entry_data_list, count
    end
end

save_entry = function(t, entry_list)
    local entry_data_list = {}
    local change_map_list = {}
    local result_list = {}
    local not_ret_index_list = {}
    for i = 1,#entry_list do
        local entry = entry_list[i]
        local change_map = entry:get_change_map()
        if next(change_map) then
            tinsert(entry_data_list, entry:get_entry_data())
            tinsert(change_map_list, change_map)
            tinsert(not_ret_index_list, i)
        else
            result_list[i] = true
        end
    end
    local ret_list = t._adapterinterface:save_entry(entry_data_list,change_map_list)
    assert(#ret_list == #entry_data_list, "result len not same " .. #ret_list .. ':' .. #entry_data_list)
    for i = 1,#ret_list do
        local res = ret_list[i]
        local entry = entry_list[i]
        if res then  --保存成功
            entry:clear_change()
        end
        local index = not_ret_index_list[i]
        result_list[index] = res
    end

    return result_list
end

local function save_one_entry(t, entry)
    local change_map = entry:get_change_map()
    --没有变化
    if not next(change_map) then
        return true
    end
    local entry_data = entry:get_entry_data()
    return t._adapterinterface:save_one_entry(entry_data, change_map)
end

local function clear_cache_by_keyvalue(t, key_values)
    local change_flag_map = t._change_flag_map
    local key_list = t._keylist
    local entry_list = nil
    local depth = #key_list - #key_values
    local entry_list_map = get_key_select(t, key_values)
    if depth > 0 then
        entry_list = table_util.depth_to_list(entry_list_map, depth)
    else
        entry_list = {entry_list_map}
    end

    for i = 1,#entry_list do
        local entry = entry_list[i]
        change_flag_map[entry] = nil        --都删除了，已经不需要同步到库了
        if t._cache_map then
            t._cache_map:del_cache(entry)
        end
        entry:clear_change()
        del_key_select(t, entry, true)
    end
end

local function delete_entry(t, key_values)
    local res = t._adapterinterface:delete_entry(key_values)
    if not res then return end

    clear_cache_by_keyvalue(t, key_values)

    return res
end

local function compare_range(left, right, v)
    if v >= left and v <= right then
        return true
    end
    return false
end

local function compare_left(left, right, v)
    if v >= left then
        return true
    end
    return false
end

local function compare_right(left, right, v)
    if v <= right then
        return true
    end
    return false
end

local function clear_cache_by_range(t, key_values, left, right)
    local change_flag_map = t._change_flag_map
    local key_list = t._keylist
    local entry_list = nil
    local k_len = #key_values
    local depth = #key_list - k_len
    local end_field_name = t._keylist[k_len + 1]
    local entry_list_map = get_key_select(t, key_values)
    if depth > 0 then
        entry_list = table_util.depth_to_list(entry_list_map, depth)
    else
        entry_list = {entry_list_map}
    end

    local compare_func = nil
    if left and right then
        compare_func = compare_range
    elseif left then
        compare_func = compare_left
    else
        compare_func = compare_right
    end

    for i = 1,#entry_list do
        local entry = entry_list[i]
        local v = entry:get(end_field_name)
        if compare_func(left, right, v) then
            change_flag_map[entry] = nil        --都删除了，已经不需要同步到库了
            if t._cache_map then
                t._cache_map:del_cache(entry)
            end
            entry:clear_change()
            del_key_select(t, entry, true)
        end
    end
end

local function delete_entry_by_range(t, left, right, key_values)
    local res = t._adapterinterface:delete_entry_by_range(left, right, key_values)
    if not res then return end

    clear_cache_by_range(t, key_values, left, right)

    return res
end

local function delete_entry_by_in(t, in_values, key_values)
    local res = t._adapterinterface:delete_entry_by_in(in_values, key_values)
    if not res then return end

    local change_flag_map = t._change_flag_map
    local key_list = t._keylist
    local kv_len = #key_values
    local depth = #key_list - kv_len - 1
    for i = #in_values, 1, -1 do
        local v = in_values[i]
        key_values[kv_len + 1] = v
        local entry_list_map = get_key_select(t, key_values)
        if entry_list_map then
            local entry_list = {}
            if depth > 0 then
                entry_list = table_util.depth_to_list(entry_list_map, depth)
            else
                entry_list = {entry_list_map}
            end
            for _,entry in ipairs(entry_list) do
                change_flag_map[entry] = nil        --都删除了，已经不需要同步到库了
                if t._cache_map then
                    t._cache_map:del_cache(entry)
                end
                entry:clear_change()
                del_key_select(t, entry, true)
            end
        end
    end

    return res
end

local function batch_delete_entry(t, keys_list)
    local res = t._adapterinterface:batch_delete_entry(keys_list)
    for i = 1, #res do
        local key_values = keys_list[i]
        if res[i] then
            clear_cache_by_keyvalue(t, key_values)      --删除成功了，清理缓存
        end
    end

    return res
end

local function batch_delete_entry_by_range(t, query_list)
    local res = t._adapterinterface:batch_delete_entry_by_range(query_list)
    for i = 1, #res do
        if res[i] then
            local query = query_list[i]
            local key_values = query.key_values
            local left = query.left
            local right = query.right
            clear_cache_by_range(t, key_values, left, right)
        end
    end

    return res
end

local function idx_get_entry(t, query)
    local res = t._adapterinterface:idx_get_entry(query)
    for i, entry_data in pairs(res) do
        local entry = ormentry:new(t, entry_data)
        res[i] = add_key_select(t, entry)
    end
    return res
end

local function idx_get_entry_by_limit(t, cursor, limit, sort, sort_field_name, query, next_offset)
    local cursor, res, count, next_offset = t._adapterinterface:idx_get_entry_by_limit(cursor, limit, sort, sort_field_name, query, next_offset)
    for i, entry_data in pairs(res) do
        local entry = ormentry:new(t, entry_data)
        res[i] = add_key_select(t, entry)
    end
    return cursor, res, count, next_offset
end

local function idx_delete_entry(t, query)
    if t._cache_time then
        local entry_list = idx_get_entry(t, query)
        local ret = t._adapterinterface:idx_delete_entry(query)
        if not ret then return ret end

        for i = 1, #entry_list do
            local entry = entry_list[i]
            del_key_select(t, entry, true)
        end

        return ret
    else
        return t._adapterinterface:idx_delete_entry(query)
    end
end

---#desc 批量创建新数据
---@param entry_data_list table 数据列表
---@return table obj
function M:create_entry(entry_data_list)
    assert(self._is_builder, "not builder can`t create_entry")
    return queue_doing(self, nil, create_entry, self, entry_data_list)
end

---#desc 创建一条数据
---@param entry_data table 一条数据表
---@return table obj
function M:create_one_entry(entry_data)
    assert(self._is_builder, "not builder can`t create_one_entry")
    check_fields(self, entry_data)
    local key1value = get_key1value(self, entry_data)
    return queue_doing(self, key1value, create_one_entry, self, entry_data)
end

---#desc 查询多条数据  format`[select * from tab_name where key1 = ? and key2 = ?]`
---@param ... string[] 最左前缀的 key 列表
---@return table obj[](ormentry)
function M:get_entry(...)
    assert(self._is_builder, "not builder can`t get_entry")
    local key_values = {...}
    assert(#key_values > 0, "err key_values")
    check_key_values(self, key_values)
    local key1value = key_values[1]
    return queue_doing(self, key1value, get_entry, self, key_values)
end

---#desc 查询一条数据 查询单条数据，必须提供所有主键 format`[select * from tab_name where key1 = ? and key2 = ?]`
---@param ... string[] 最左前缀的 key 列表
---@return table obj(ormentry)
function M:get_one_entry(...)
    assert(self._is_builder, "not builder can`t get_one_entry")
    local key_values = {...}
    local key_list = self._keylist
    assert(#key_values == #key_list, "args len err") --查询单条数据，必须提供所有主键
    check_key_values(self, key_values)
    local key1value = key_values[1]
    return queue_doing(self, key1value, get_one_entry, self, key_values)
end

---#desc 立即保存数据
---@param entry_list table ormentry对象列表
---@return table 保存结果索引对应值 成功true失败false
function M:save_entry(entry_list)
    assert(self._is_builder, "not builder can`t save_entry")
    if not next(entry_list) then return entry_list end

    return queue_doing(self, nil, save_entry, self, entry_list)
end

---#desc 立即保存一条数据
---@param entry table ormentry对象
---@return boolean 成功true失败false
function M:save_one_entry(entry)
    assert(self._is_builder, "not builder can`t save_one_entry")
    assert(entry,"not entry")
    local key1value = get_key1value(self, entry:get_entry_data())
    return queue_doing(self, key1value, save_one_entry, self, entry)
end

---#desc 删除数据 format[delete * from tab_name where key1 = ? and key2 = ?]
---@param ... string[] 最左前缀的 key 列表
---@return boolean 成功true失败false
function M:delete_entry(...)
    assert(self._is_builder, "not builder can`t delete_entry")
    local key_values = {...}
    assert(#key_values > 0, "not key_values")
    check_key_values(self, key_values)
    local key1value = key_values[1]
    return queue_doing(self, key1value, delete_entry, self, key_values)
end

---#desc 查询所有数据
---@return table obj[](ormentry)
function M:get_all_entry()
    assert(self._is_builder, "not builder can`t get_all_entry")
    return queue_doing(self, nil, get_entry, self, {})
end

---#desc 删除所有数据
---@return boolean 成功true失败false
function M:delete_all_entry()
    assert(self._is_builder, "not builder can`t delete_all_entry")
    return queue_doing(self, nil, delete_entry, self, {})
end

---#desc 立即保存所有修改，直到成功为止
function M:save_change_now()
    assert(self._is_builder, "not builder can`t save_change_now")
    if not self._week_t then
        return
    end

    return queue_doing(self, nil, inval_time_out, self._week_t, true)
end

---#desc 通过数据获得entry
---@param entry_data table 数据表
---@return table obj(ormentry)
function M:get_entry_by_data(entry_data)
    assert(self._is_builder, "not builder can`t get_entry_by_data")
    local key_list = self._keylist
    local key_values = {}
    for i = 1,#key_list do
        local field_name = key_list[i]
        local v = assert(entry_data[field_name], "not exists value field_name:" .. field_name)
        tinsert(key_values, v)
    end
    check_key_values(self, key_values)
    local key1value = key_values[1]

    return queue_doing(self, key1value, get_one_entry, self, key_values)
end

---#desc 是否启用了间隔保存
---@return boolean
function M:is_inval_save()
    return self._time_obj ~= nil
end

---#desc 分页查询 format`[select * from tab_name where key1 = ? and key2 > ? order by ? desc limit ?]`
---@param cursor number|string 游标
---@param limit number 数量限制
---@param sort number 1升序  -1降序
---@param ... string[] 最左前缀主键列表 key1 key2 ... 不填入的key作为游标
---@return number cursor? 游标
---@return table obj[](ormentry) 结果数组
---@return number count? 总数
function M:get_entry_by_limit(cursor, limit, sort, ...)
    assert(self._is_builder, "not builder can`t get_entry_by_limit")
    assert(type(limit) == 'number', "err limit:" .. tostring(limit))
    assert(type(sort) == 'number', "err sort:" .. tostring(sort))
    local key_list = self._keylist
    local key_values = {...}
    local len = #key_values

    assert(#key_list > 0, "not keys can`t use")            --没有索引不能使用
    assert(len == #key_list - 1, "key_values len err")     --最后一个key作为游标查询，确保使用索引分页查询

    check_key_values(self, key_values)

    local key1value = key_values[1]
    return queue_doing(self, key1value, get_entry_by_limit, self, cursor, limit, sort, key_values)
end

---#desc IN 查询  format`[select * from tab_name where key1 = ? and key2 = ? and key3 in (?,?,?)]`
---@param in_values table in对应的值列表
---@param ... string[] 最左前缀主键列表 无需填入in_values的key
---@return table obj[](ormentry)
function M:get_entry_by_in(in_values, ...)
    assert(self._is_builder, "not builder can`t get_entry_by_in")
    local key_list = self._keylist
    local key_values = {...}
    local key_len = #key_list
    local kv_len = #key_values
    local inv_len = #in_values
    assert(key_len > 0, "not keys can`t use")            --没有索引不能使用
    assert(inv_len > 0, "in_values err")                 --in_values得有值
    assert(kv_len < key_len, "kv len err")               --如果是 3个key kv最多是填2个，in_value 是第3个的值
    --in_values 是 len + 1 位置的key的值
    check_key_values(self, key_values)

    local end_field_name = self._keylist[kv_len + 1]
    for i = 1,#in_values do
        check_one_field(self, end_field_name, in_values[i])
    end
   
    local key1value = key_values[1]
    return queue_doing(self, key1value, get_entry_by_in, self, in_values, key_values)
end

---#content 范围删除 包含left right
---#content 可以有三种操作方式
---#content [left, right] 范围删除  >= left <= right
---#content [left, nil] 删除 >= left
---#content [nil, right] 删除 <= right
---#content format`[delete from player where key1=? and key2>=? and key2<=?;]`
---#desc 范围删除 包含left right 可以有三种操作方式 [left, right] 范围删除  >= left <= right  [left, nil] 删除 >= left [nil, right] 删除 <= right
---@param left string|number|nil 左值
---@param right string|number|nil 右值
---@param ... string[] 最左前缀主键列表 无需填入left right值 对应的key
---@return boolean
function M:delete_entry_by_range(left, right, ...)
    assert(self._is_builder, "not builder can`t delete_entry_by_range")
    assert(left or right, "not left or right")
    if left and right then
        assert(left <= right, "left right err")
    end
    local key_values = {...}
    local kv_len = #key_values
    local key_list = self._keylist
    assert(kv_len < #key_list, "kv len err")  --如果是 3个key kv最多是填2个  [left,right]的值是 #key_values + 1位置的key
    check_key_values(self, key_values)

    local end_field_name = self._keylist[kv_len + 1]
    if left then
        check_one_field(self, end_field_name, left)
    end

    if right then
        check_one_field(self, end_field_name, right)
    end

    local key1value = key_values[1]
    return queue_doing(self, key1value, delete_entry_by_range, self, left, right, key_values)
end

---#desc IN 删除 format`[delete from tab_name where key1 = ? and key2 = ? and key3 in (?,?,?)]`
---@param in_values table in对应的值列表 
---@param ... string[] 最左前缀主键列表 无需填入in_values的key
---@return boolean
function M:delete_entry_by_in(in_values, ...)
    assert(self._is_builder, "not builder can`t delete_entry_by_in")
    local key_list = self._keylist
    local key_values = {...}
    local key_len = #key_list
    local kv_len = #key_values
    local inv_len = #in_values
    assert(key_len > 0, "not keys can`t use")            --没有索引不能使用
    assert(inv_len > 0, "in_values err")                 --in_values得有值
    assert(kv_len < key_len, "kv len err")               --如果是 3个key kv最多是填2个，in_value 是第3个的值
    --in_values 是 len + 1 位置的key的值
    check_key_values(self, key_values)

    local end_field_name = self._keylist[kv_len + 1]
    for i = 1,#in_values do
        check_one_field(self, end_field_name, in_values[i])
    end
   
    local key1value = key_values[1]
    return queue_doing(self, key1value, delete_entry_by_in, self, in_values, key_values)
end

---#desc 批量删除 format `[delete from tab_name where (key1 = ? and key2 = ?) or (key1 = ? and key2 = ?)]`
---@param keys_list table 最左前缀主键列表 `{{key1,key2,...},{key1,key2,...}}`
---@return table boolean 执行结果
function M:batch_delete_entry(keys_list)
    assert(self._is_builder, "not builder can`t batch_delete_entry")
    assert(#keys_list > 0, "keys_list can`t be empty")
    local len = #keys_list[1]
    assert(len > 0, "key_values can`t be empty")
    for i = 1, #keys_list do
        local key_values = keys_list[i]
        assert(#key_values == len, sformat("key_values len mult same firstlen[%s] index[%s]len[%s]", len, i, #key_values))
        check_key_values(self, key_values)
    end

    return queue_doing(self, nil, batch_delete_entry, self, keys_list)
end

--#desc 批量范围删除 format `[delete from tab_name where (key1 = ? and key2 >= ? and key2 <= ?) or (key1 = ? and key2 >= ? and key2 <= ?)]`  key长度必须一致， left,right 有无必须一致
---@param query_list table `{{left = 1, right = 10, key_values = {10001, 10002}}, {left = 1, right = 10, key_values = {10001, 10002}}} key1[10001], key2[10002] key3[left, right]}}`
---@return table boolean 执行结果
function M:batch_delete_entry_by_range(query_list)
    assert(self._is_builder, "not builder can`t batch_delete_entry_by_range")
    assert(#query_list > 0, "query_list can`t be empty")
    local first_query = query_list[1]
    local first_key_values = first_query.key_values
    local first_left = first_query.left
    local first_right = first_query.right
    assert(first_left or first_right, "not left or right")
    assert(first_key_values and #first_key_values >= 1 and #first_key_values < #self._keylist, "kv len err")
    for i = 1, #query_list do
        local query = query_list[i]
        assert(#query.key_values == #first_key_values, sformat("key_values len mult same firstlen[%s] index[%s]len[%s]", #first_key_values, i, #query.key_values))
        if first_left then
            assert(query.left, "left right mult same : " .. i)
        else
            assert(not query.left, "left right mult same : " .. i)
        end
        if first_right then
            assert(query.right, "left right mult same : " .. i)
        else
            assert(not query.right, "left right mult same : " .. i)
        end
        check_key_values(self, query.key_values)
    end

    return queue_doing(self, nil, batch_delete_entry_by_range, self, query_list)
end

local function check_index_field(t, field_list)
    local len = #field_list
    local index_list_map = t._index_list_map
    local indexs_list = t._indexs_list
    local check_nook_map = {}
    for i = 1, len do
        local field_name = field_list[i]
        if not index_list_map[field_name] then
            check_nook_map[field_name] = true
        end
    end

    if not next(check_nook_map) then return end

    for f_list in table_util.permute_pairs(field_list) do
        for _, ff_list in pairs(indexs_list) do
            if #ff_list >= 1 then
                for i = 1, len do
                    local f_name = f_list[i]
                    local ff_name = ff_list[i]
                    if f_name ~= ff_name then
                        break
                    else
                        check_nook_map[f_name] = nil
                    end
                end
            end
        end

        if not next(check_nook_map) then return end
    end

    local cant_index_list = {}
    for field_name in pairs(check_nook_map) do
        tinsert(cant_index_list, field_name)
    end

    error(sformat('can`t hit index field_name_list(%s) Please follow the leftmost prefix principle', tconcat(cant_index_list, ',')))
end

local function check_query(self, query)
    local field_list = {}
    for field_name, field_value in pairs(query) do
        if type(field_value) == 'table' then
            assert(next(field_value), "can`t empty")
            for k, v in pairs(field_value) do
                local repel = assert(g_REPEL_SYMBOL[k], "query invaild k:" .. k)
                assert(not field_value[repel], "repel repel k:" .. k .. ' repel:' .. repel)
                check_one_field(self, field_name, v)
            end
        else
            check_one_field(self, field_name, field_value)
        end
        tinsert(field_list, field_name)
    end

    check_index_field(self, field_list)
end

---#desc 通过普通索引查询,设置缓存的情况下，也会先查询数据库 format `select * from tab_name where (key1 = ? and key2 = ? and key3 >= ? and key3 <= ?)`
---@param query table 索引值 [key1 = xxx, key2 = xxx, key3 = {['$gte' = xxx, '$lte' = xxx]}]
---@return table 查询结果列表
function M:idx_get_entry(query)
    assert(self._is_builder, "not builder can`t idx_get_entry")
    assert(next(query), "query can`t be empty")
    
    check_query(self, query)

    return queue_doing(self, nil, idx_get_entry, self, query)
end

---#desc 基于普通索引分页查询 format`[select * from tab_name where (key1 = ? and key2 = ? and key3 >= ? and key3 <= ?) order by ? desc limit ?]`
---@param cursor? number|string 游标
---@param limit number 数量限制
---@param sort number 1升序  -1降序
---@param sort_field_name string 排序字段名
---@param query? table 索引值 [key1 = xxx, key2 = xxx, key3 = {['$gte' = xxx, '$lte' = xxx]}]
---@param next_offset? number 下一页偏移量
---@return number|string cursor? 游标
---@return table obj[](ormentry) 结果数组
---@return number count? 总数 首页返回
---@return number next_offset 下一页偏移量
function M:idx_get_entry_by_limit(cursor, limit, sort, sort_field_name, query, next_offset)
    assert(self._is_builder, "not builder can`t idx_get_entry_by_limit")
    assert(type(limit) == 'number', "err limit:" .. tostring(limit))
    assert(type(sort) == 'number', "err sort:" .. tostring(sort))
    assert(not next_offset or type(next_offset) == 'number', "err offset:" .. tostring(next_offset))

    if query then
        check_query(self, query)
    end
    return queue_doing(self, nil, idx_get_entry_by_limit, self, cursor, limit, sort, sort_field_name, query, next_offset)
end

---#desc 通过普通索引删除数据 format `delete from tab_name where (key1 = ? and key2 = ? and key3 >= ? and key3 <= ?)`
---@param query table 索引值 [key1 = xxx, key2 = xxx, key3 = {['$gte' = xxx, '$lte' = xxx]}]
---@return boolean 删除结果
function M:idx_delete_entry(query)
    assert(self._is_builder, "not builder can`t idx_delete_entry")
    assert(next(query), "query can`t be empty")
    check_query(self, query)

    return queue_doing(self, nil, idx_delete_entry, self, query)
end

return M