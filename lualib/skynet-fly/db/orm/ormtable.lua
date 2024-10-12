local ormentry = require "skynet-fly.db.orm.ormentry"
local table_util = require "skynet-fly.utils.table_util"
local math_util = require "skynet-fly.utils.math_util"
local mult_queue = require "skynet-fly.mult_queue"
local tti = require "skynet-fly.cache.tti"
local timer = require "skynet-fly.timer"
local skynet = require "skynet"
local log = require "skynet-fly.log"

local setmetatable = setmetatable
local assert = assert
local tinsert = table.insert
local tremote = table.remove
local tunpack = table.unpack
local tsort = table.sort
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

local INVAILD_POINT = {count = 0, total_count = 0}  --无效叶点
local VAILD_POINT = {count = 1, total_count = 1}    --有效叶点

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
    assert(ktype == "string", sformat("tab_name[%s] set invaild field_name type field_name[%s] value[%s] field_type[%s]", t._tab_name, field_name, field_value, field_type))                       --字段名必须是string
    assert(check_func(field_value),sformat("tab_name[%s] set invaild value field_name[%s] value[%s] field_type[%s]", t._tab_name, field_name, field_value, field_type))
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

local del_key_select = nil  --function
local get_entry = nil       --function
local save_entry = nil      --function

-- 添加进key索引表
local function add_key_select(t, entry, is_add)
    if not t._cache_time then return entry end
    local key_select_map = t._key_select_map
    local key_cache_num_map = t._key_cache_num_map                      --缓存数量
    local key_list = t._keylist

    local res_entry = entry
    local invaild = entry:is_invaild()
    local select_list = {}
    local len = #key_list
    for i = 1,len do
        local field_name = key_list[i]
        local field_value = entry:get(field_name)
        assert(field_value, "not field_value")
        
        if i ~= len then
            if not key_select_map[field_value] then
                key_select_map[field_value] = {}
                key_cache_num_map[field_value] = {count = 0, sub_map = {}}
            end
            local one_select = {k = field_value, pv = key_select_map, pc = key_cache_num_map}
            tinsert(select_list, one_select)
            key_cache_num_map = key_cache_num_map[field_value].sub_map
            key_select_map = key_select_map[field_value]
        else
            if not key_select_map[field_value] then
                if t._cache_map then
                    t._cache_map:set_cache(entry,t)
                end
                if invaild then
                    key_cache_num_map[field_value] = INVAILD_POINT
                else
                    key_cache_num_map[field_value] = VAILD_POINT
                end
                
                key_select_map[field_value] = entry
                for i = #select_list, 1, -1 do
                    local one_select = select_list[i]
                    if not invaild then
                        one_select.pc[one_select.k].count = one_select.pc[one_select.k].count + 1
                    end

                    if is_add and not invaild then
                        --是添加跟着count 一起加一就行
                        if one_select.pc[one_select.k].total_count then
                            one_select.pc[one_select.k].total_count = one_select.pc[one_select.k].total_count + 1
                        end
                    end
                end
                if not invaild then
                    t._key_cache_count = t._key_cache_count + 1
                end

                if is_add and not invaild then
                    if t._key_cache_total_count then
                        t._key_cache_total_count = t._key_cache_total_count + 1
                    end
                end
            else
                res_entry = key_select_map[field_value]
                if is_add and not invaild and res_entry:is_invaild() then   --是添加并且是无效条目，替换掉
                    del_key_select(t, res_entry, true)
                    add_key_select(t, entry, true)
                    res_entry = entry
                else
                    if t._cache_map then
                        t._cache_map:update_cache(res_entry,t)
                    end
                end
            end
        end
    end

    --log.info("add_key_select:", invaild, is_add, t._key_cache_num_map, tostring(res_entry))
    return res_entry
end

-- 设置total_count
local function set_total_count(t, key_values, total_count)
    if not t._cache_time then return end
    local key_cache_num_map = t._key_cache_num_map                      --缓存数量
    local len = #key_values
    for i = 1, len do
        local field_value = key_values[i]
        if i ~= len then
            key_cache_num_map = key_cache_num_map[field_value].sub_map
        else
            local cache = key_cache_num_map[field_value]
            cache.total_count = total_count
            return
        end
    end

    t._key_cache_total_count = total_count
end

-- 查询key索引表
local function get_key_select(t, key_values)
    if not t._cache_time then return end
    local key_select_map = t._key_select_map
    local key_cache_num_map = t._key_cache_num_map                      --缓存数量
    local len = #key_values
    for i = 1, len do
        local field_value = key_values[i]
        if i ~= len then
            if not key_select_map[field_value] then
                return
            end
            key_select_map = key_select_map[field_value]
            key_cache_num_map = key_cache_num_map[field_value].sub_map
        else
            local cache = key_cache_num_map[field_value]
            if not cache then return end
            if t._cache_time == 0 then      --永久缓存不需要对比total_count，数据全在
                if key_select_map[field_value] then
                    return key_select_map[field_value], true
                else
                    return
                end
            end
            if not cache.total_count then return end
            return key_select_map[field_value], cache.count == cache.total_count
        end
    end
    
    return key_select_map, t._key_cache_count == t._key_cache_total_count
end

-- 删除掉key索引表
del_key_select = function(t, entry, is_del)
    if not t._cache_time then return end
    local key_select_map = t._key_select_map
    local key_cache_num_map = t._key_cache_num_map                      --缓存数量
    local key_list = t._keylist
    local select_list = {}
    local invaild = entry:is_invaild()
    local len = #key_list
    for i = 1,len do
        local field_name = key_list[i]
        local field_value = entry:get(field_name)
        assert(field_value, "not field_value")

        if i ~= len then
            if not key_select_map[field_value] then
                break
            end
            local one_select = {k = field_value, pv = key_select_map, pc = key_cache_num_map}
            key_select_map = key_select_map[field_value]
            key_cache_num_map = key_cache_num_map[field_value].sub_map
            one_select.sv = key_select_map
            tinsert(select_list, one_select)
        else
            if entry ~= key_select_map[field_value] then break end
            key_select_map[field_value] = nil
            key_cache_num_map[field_value] = nil
            if not invaild then
                t._key_cache_count = t._key_cache_count - 1
            end
            if is_del then
                if not invaild and t._key_cache_total_count then
                    t._key_cache_total_count = t._key_cache_total_count - 1
                end
            else
                --仅仅是缓存过期了
                t._key_cache_total_count = nil
            end
            local rm_k = nil
            for i = #select_list, 1, -1 do
                local one_select = select_list[i]
                if not invaild then
                    one_select.pc[one_select.k].count = one_select.pc[one_select.k].count - 1
                end
                if is_del then
                    --是删除跟着count 一起减一就行
                    if not invaild and one_select.pc[one_select.k].total_count then
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

    if t._cache_map then
        t._cache_map:del_cache(entry)
    end
    --log.info("del_key_select:", invaild, is_del, t._key_cache_num_map)
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

-- 新建表
function M:new(tab_name)
    local t = {
        _queue = mult_queue:new(),                           --操作队列
        _tab_name = tab_name,                       --表名
        _field_list = {},
        _field_map = {},                            --所有字段
        _key_map = {},
        _keylist = {},                              --key列表
        _is_builder = false,

        -- key索引表
        _key_select_map = {},
        _key_cache_num_map = {},                    --缓存数量
        _key_cache_count = 0,                       --缓存总数
        _key_cache_total_count = nil,               --实际总数

        -- 缓存时间
        _cache_time = nil,

        -- 变更的标记
        _change_flag_map = {},
    }
    setmetatable(t, mata)
    return t
end

do
    for type_name,type_enum in pairs(FIELD_TYPE) do
        M[type_name] = function(self, field_name)
            add_field_name_type(self, field_name, type_enum)
            return self
        end
    end
end

-- 设置主键
function M:set_keys(...)
    assert(not self._is_builder, "builded can`t set_keys")
    local list = {...}
    for i = 1,#list do
        local field_name = list[i]
        assert(self._field_map[field_name], "not exists: ".. field_name)
        assert(not self._key_map[field_name], "is exists: ".. field_name)
        tinsert(self._keylist, field_name)
        self._key_map[field_name] = true
    end
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
        if entry:is_invaild() then
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
local function create_invaild_entry(t, key_values)
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

    return ormentry:new_invaild(data)
end

local week_mata = {__mode = "kv"}
-- 设置缓存时间
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
    
    t._is_builder = true

    adapterinterface:builder(tab_name, field_list, field_map, key_list)
    return t
end

-- 构建表
function M:builder(adapterinterface)
    assert(#self._keylist > 0, "not set keys")
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
                local invaild_entry = create_invaild_entry(t, key_values)
                add_key_select(t, invaild_entry)
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
            if entry:is_invaild() then
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
                local invaild_entry = create_invaild_entry(t, key_values)
                add_key_select(t, invaild_entry)
                return nil, false
            else
                entry = ormentry:new(t, init_entry_data(t, entry_data), true)
                return add_key_select(t, entry)
            end
        end
    end

    if entry and t._cache_map then
        t._cache_map:update_cache(entry, t)
    end

    if entry and entry:is_invaild() then
        entry = nil
    end
    return entry, true
end

local function get_entry_by_in(t, in_values, key_values)
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
                if not entry:is_invaild() then
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
                        local invaild_entry = create_invaild_entry(t, key_values)
                        add_key_select(t, invaild_entry)
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
            local entry = ormentry:new(t, init_entry_data(t, entry_data), true)
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

local function delete_entry(t, key_values)
    local res = t._adapterinterface:delete_entry(key_values)
    if not res then return end

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

local function delete_entry_by_range(t, left, right, key_values)
    local res = t._adapterinterface:delete_entry_by_range(left, right, key_values)
    if not res then return end

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

    return res
end

-- 批量创建新数据
function M:create_entry(entry_data_list)
    assert(self._is_builder, "not builder can`t create_entry")
    return queue_doing(self, nil, create_entry, self, entry_data_list)
end

-- 创建一条数据
function M:create_one_entry(entry_data)
    assert(self._is_builder, "not builder can`t create_one_entry")
    check_fields(self, entry_data)
    local key1value = get_key1value(self, entry_data)
    return queue_doing(self, key1value, create_one_entry, self, entry_data)
end

-- 查询多条数据
function M:get_entry(...)
    assert(self._is_builder, "not builder can`t get_entry")
    local key_values = {...}
    assert(#key_values > 0, "err key_values")
    check_key_values(self, key_values)
    local key1value = key_values[1]
    return queue_doing(self, key1value, get_entry, self, key_values)
end

-- 查询一条数据
function M:get_one_entry(...)
    assert(self._is_builder, "not builder can`t get_one_entry")
    local key_values = {...}
    local key_list = self._keylist
    assert(#key_values == #key_list, "args len err") --查询单条数据，必须提供所有主键
    check_key_values(self, key_values)
    local key1value = key_values[1]
    return queue_doing(self, key1value, get_one_entry, self, key_values)
end

-- 立即保存数据
function M:save_entry(entry_list)
    assert(self._is_builder, "not builder can`t save_entry")
    if not next(entry_list) then return entry_list end

    return queue_doing(self, nil, save_entry, self, entry_list)
end

-- 立即保存一条数据
function M:save_one_entry(entry)
    assert(self._is_builder, "not builder can`t save_one_entry")
    assert(entry,"not entry")
    local key1value = get_key1value(self, entry:get_entry_data())
    return queue_doing(self, key1value, save_one_entry, self, entry)
end

-- 删除数据
function M:delete_entry(...)
    assert(self._is_builder, "not builder can`t delete_entry")
    local key_values = {...}
    assert(#key_values > 0, "not key_values")
    check_key_values(self, key_values)
    local key1value = key_values[1]
    return queue_doing(self, key1value, delete_entry, self, key_values)
end

-- 查询所有数据
function M:get_all_entry()
    assert(self._is_builder, "not builder can`t get_all_entry")
    return queue_doing(self, nil, get_entry, self, {})
end

-- 删除所有数据
function M:delete_all_entry()
    assert(self._is_builder, "not builder can`t delete_all_entry")
    return queue_doing(self, nil, delete_entry, self, {})
end

-- 立即保存所有修改
function M:save_change_now()
    assert(self._is_builder, "not builder can`t save_change_now")
    if not self._week_t then
        return
    end

    return queue_doing(self, nil, inval_time_out, self._week_t, true)
end

-- 通过数据获得entry
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

-- 是否启动了间隔保存
function M:is_inval_save()
    return self._time_obj ~= nil
end

-- 分页查询
function M:get_entry_by_limit(cursor, limit, sort, ...)
    assert(self._is_builder, "not builder can`t get_entry_by_limit")
    local key_list = self._keylist
    local key_values = {...}
    local len = #key_values

    assert(#key_list > 0, "not keys can`t use")            --没有索引不能使用
    assert(len == #key_list - 1, "key_values len err")     --最后一个key作为游标查询，确保使用索引分页查询

    check_key_values(self, key_values)

    local key1value = key_values[1]
    return queue_doing(self, key1value, get_entry_by_limit, self, cursor, limit, sort, key_values)
end

-- IN 查询
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

-- 范围删除 包含left right
-- 可以有三种操作方式
-- [left, right] 范围删除  >= left <= right
-- [left, nil] 删除 >= left
-- [nil, right] 删除 <= right
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

return M