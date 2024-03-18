local ormentry = require "skynet-fly.db.orm.ormentry"
local table_util = require "skynet-fly.utils.table_util"
local math_util = require "skynet-fly.utils.math_util"
local queue = require "skynet.queue"
local cache_help = require "skynet-fly.cache.cache_help"
local timer = require "skynet-fly.timer"
local skynet = require "skynet"
local log = require "skynet-fly.log"

local setmetatable = setmetatable
local assert = assert
local tinsert = table.insert
local tunpack = table.unpack
local pairs = pairs
local type = type
local ipairs = ipairs
local sformat = string.format
local next = next

local FILED_TYPE = {
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
}

local FILED_LUA_DEFAULT = {
    [FILED_TYPE.int8] = 0,
    [FILED_TYPE.int16] = 0,
    [FILED_TYPE.int32] = 0,
    [FILED_TYPE.int64] = 0,
    [FILED_TYPE.uint8] = 0,
    [FILED_TYPE.uint16] = 0,
    [FILED_TYPE.uint32] = 0,

    [FILED_TYPE.string32] = "",
    [FILED_TYPE.string64] = "",
    [FILED_TYPE.string128] = "",
    [FILED_TYPE.string256] = "",
    [FILED_TYPE.string512] = "",
    [FILED_TYPE.string1024] = "",
    [FILED_TYPE.string2048] = "",
    [FILED_TYPE.string4096] = "",
    [FILED_TYPE.string8192] = "",

    [FILED_TYPE.text] = "",
    [FILED_TYPE.blob] = "",
}

local function create_check_str(len)
    return function(str)
        if type(str) ~= 'string' then return false end
        return str:len() <= len
    end
end

local FILED_TYPE_CHECK_FUNC = {
    [FILED_TYPE.int8] = math_util.is_vaild_int8,
    [FILED_TYPE.int16] = math_util.is_vaild_int16,
    [FILED_TYPE.int32] = math_util.is_vaild_int32,
    [FILED_TYPE.int64] = math_util.is_vaild_int64,
    [FILED_TYPE.uint8] = math_util.is_vaild_uint8,
    [FILED_TYPE.uint16] = math_util.is_vaild_uint16,
    [FILED_TYPE.uint32] = math_util.is_vaild_uint32,

    [FILED_TYPE.string32] = create_check_str(32),
    [FILED_TYPE.string64] = create_check_str(64),
    [FILED_TYPE.string128] = create_check_str(128),
    [FILED_TYPE.string256] = create_check_str(256),
    [FILED_TYPE.string512] = create_check_str(512),
    [FILED_TYPE.string1024] = create_check_str(1024),
    [FILED_TYPE.string2048] = create_check_str(2048),
    [FILED_TYPE.string4096] = create_check_str(4096),
    [FILED_TYPE.string8192] = create_check_str(8192),

    [FILED_TYPE.text] = function(str) return type(str) == 'string' end,
    [FILED_TYPE.blob] = function(str) return type(str) == 'string' end,
}

local function add_filed_name_type(t,filed_name,filed_type)
    assert(filed_name, "not filed_name")
    assert(not t._filed_map[filed_name], "filed_name is exists :" .. filed_name)

    t._filed_map[filed_name] = filed_type
    tinsert(t._filed_list, filed_name)
    return t
end

-- 检查一条数据的合法性
local function check_one_filed(t, filed_name, filed_value)
    local filed_type = assert(t._filed_map[filed_name], "not exists filed_name = " .. filed_name)
    local check_func = assert(FILED_TYPE_CHECK_FUNC[filed_type], "not check func : ".. filed_type)
    local ktype = type(filed_name)
    assert(ktype == "string", sformat("tab_name[%s] set invaild filed_name type filed_name[%s] value[%s] filed_type[%s]", t._tab_name, filed_name, filed_value, filed_type))                       --字段名必须是string
    assert(check_func(filed_value),sformat("tab_name[%s] set invaild value filed_name[%s] value[%s] filed_type[%s]", t._tab_name, filed_name, filed_value, filed_type))
end

-- 检查数据表的合法性
local function check_fileds(t,entry_data)
    for _,filed_name in ipairs(t._keylist) do
        assert(entry_data[filed_name], "not set key value:" .. filed_name)                  --key字段值必须有值
    end

    for filed_name,filed_value in pairs(entry_data) do
        check_one_filed(t, filed_name, filed_value)
    end
end

-- 添加进key索引表
local function add_key_select(t, entry, is_add)
    if not t._cache_time then return entry end
    local key_select_map = t._key_select_map
    local key_cache_num_map = t._key_cache_num_map                      --缓存数量
    local key_list = t._keylist

    local res_entry = entry

    local select_list = {}
    local len = #key_list
    for i = 1,len do
        local filed_name = key_list[i]
        local filed_value = entry:get(filed_name)
        assert(filed_value, "not filed_value")
        
        if i ~= len then
            if not key_select_map[filed_value] then
                key_select_map[filed_value] = {}
                key_cache_num_map[filed_value] = {count = 0, sub_map = {}}
            end
            local one_select = {k = filed_value, pv = key_select_map, pc = key_cache_num_map}
            tinsert(select_list, one_select)
            key_cache_num_map = key_cache_num_map[filed_value].sub_map
            key_select_map = key_select_map[filed_value]
        else
            if not key_select_map[filed_value] then
                if t._cache_map then
                    assert(t._cache_map:set_cache(entry,t), "set_cache err")
                end
                key_cache_num_map[filed_value] = {count = 1, total_count = 1} --主键唯一
                key_select_map[filed_value] = entry
                for i = #select_list, 1, -1 do
                    local one_select = select_list[i]
                    one_select.pc[one_select.k].count = one_select.pc[one_select.k].count + 1

                    if is_add then
                        --是添加跟着count 一起加一就行
                        if one_select.pc[one_select.k].total_count then
                            one_select.pc[one_select.k].total_count = one_select.pc[one_select.k].total_count + 1
                        end
                    end
                end
                t._key_cache_count = t._key_cache_count + 1

                if is_add then
                    if t._key_cache_total_count then
                        t._key_cache_total_count = t._key_cache_total_count + 1
                    end
                end
            else
                res_entry = key_select_map[filed_value]
                if t._cache_map then
                    assert(t._cache_map:update_cache(res_entry,t), "update cache err")
                end
            end
        end
    end

    --log.info("add_key_select:",t._key_cache_num_map)
    return res_entry
end

-- 设置total_count
local function set_total_count(t, key_values, total_count)
    if not t._cache_time then return end
    local key_cache_num_map = t._key_cache_num_map                      --缓存数量
    local len = #key_values
    for i = 1, len do
        local filed_value = key_values[i]
        if i ~= len then
            key_cache_num_map = key_cache_num_map[filed_value].sub_map
        else
            local cache = key_cache_num_map[filed_value]
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
    local key_list = t._keylist
    local maxlen = #key_list
    local len = #key_values
    for i = 1, len do
        local filed_value = key_values[i]
        if i ~= len then
            if not key_select_map[filed_value] then
                break
            end
            key_select_map = key_select_map[filed_value]
            key_cache_num_map = key_cache_num_map[filed_value].sub_map
        else
            local cache = key_cache_num_map[filed_value]
            if not cache then return end
            if not cache.total_count then return end
            return key_select_map[filed_value], cache.count == cache.total_count
        end
    end
    
    return key_select_map, t._key_cache_count == t._key_cache_total_count
end

-- 删除掉key索引表
local function del_key_select(t, entry, is_del)
    if not t._cache_time then return end
    local key_select_map = t._key_select_map
    local key_cache_num_map = t._key_cache_num_map                      --缓存数量
    local key_list = t._keylist
    local select_list = {}

    local len = #key_list
    for i = 1,len do
        local filed_name = key_list[i]
        local filed_value = entry:get(filed_name)
        assert(filed_value, "not filed_value")

        if i ~= len then
            if not key_select_map[filed_value] then
                break
            end
            local one_select = {k = filed_value, pv = key_select_map, pc = key_cache_num_map}
            key_select_map = key_select_map[filed_value]
            key_cache_num_map = key_cache_num_map[filed_value].sub_map
            one_select.sv = key_select_map
            tinsert(select_list, one_select)
        else
            key_select_map[filed_value] = nil
            key_cache_num_map[filed_value] = nil
            t._key_cache_count = t._key_cache_count - 1
            if is_del then
                if t._key_cache_total_count then
                    t._key_cache_total_count = t._key_cache_total_count - 1
                end
            else
                t._key_cache_total_count = nil
            end
            local rm_k = nil
            for i = #select_list, 1, -1 do
                local one_select = select_list[i]

                one_select.pc[one_select.k].count = one_select.pc[one_select.k].count - 1
                if is_del then
                    --是删除跟着count 一起减一就行
                    if one_select.pc[one_select.k].total_count then
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

    --log.info("del_key_select:", t._key_cache_num_map)
end

local function init_entry_data(t,entry_data)
    local new_entry_data = {}
    local filed_list = t._filed_list
    local filed_map = t._filed_map
    for i = 1,#filed_list do
        local fn = filed_list[i]
        local ft = filed_map[fn]
        if entry_data[fn] then
            new_entry_data[fn] = entry_data[fn]
        else
            new_entry_data[fn] = FILED_LUA_DEFAULT[ft]
        end
    end
    return new_entry_data
end

local M = {
    FILED_TYPE = FILED_TYPE,
}
local mata = {__index = M, __gc = function(t)
    if t._time_obj then
        t._time_obj:cancel()
    end
end}

-- 新建表
function M:new(tab_name)
    local t = {
        _queue = queue(),                           --操作队列
        _tab_name = tab_name,                       --表名
        _filed_list = {},
        _filed_map = {},                            --所有字段
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
    for type_name,type_enum in pairs(FILED_TYPE) do
        M[type_name] = function(self, filed_name)
            add_filed_name_type(self, filed_name, type_enum)
            return self
        end
    end
end

-- 设置主键
function M:set_keys(...)
    assert(not self._is_builder, "builded can`t set_keys")
    local list = {...}
    for i = 1,#list do
        local filed_name = list[i]
        assert(self._filed_map[filed_name], "not exists: ".. filed_name)
        assert(not self._key_map[filed_name], "is exists: ".. filed_name)
        tinsert(self._keylist, filed_name)
        self._key_map[filed_name] = true
    end
    return self
end

local function excute_time_out(t, entry)
    local change_flag_map = t._change_flag_map
    if change_flag_map[entry] then
        --还没保存数据 还不能清除
        assert(t._cache_map:set_cache(entry, t), "set cache err")   --重新设置缓存
    else
        del_key_select(t, entry)
    end
end

--缓存到期
local function cache_time_out(entry, t)
    t._queue(excute_time_out, t, entry)
end

--定期保存修改
local function inval_time_out(week_t)
    local t = next(week_t)
    if not t then return end

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
        local res_list = t:save_entry(entry_list)
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
end

local week_mata = {__mode = "kv"}
-- 设置缓存时间
function M:set_cache(expire, inval)
    assert(not self._is_builder, "builded can`t set_cache")
    assert(not self._time_obj, "repeat time_obj")
    assert(expire >= 0, "err expire " .. expire)                 --缓存时间
    assert(inval > 0, "err inval")                               --自动保存间隔
    self._cache_time = expire

    if expire > 0 then                                           --0表示缓存不过期
        self._cache_map = cache_help:new(expire, cache_time_out)
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
    local filed_map = t._filed_map
    local filed_list = t._filed_list
    local key_list = t._keylist
    
    t._is_builder = true
    adapterinterface:builder(tab_name, filed_list, filed_map, key_list)
    return t
end

-- 构建表
function M:builder(adapterinterface)
    assert(#self._keylist > 0, "not set keys")
    return self._queue(builder, self, adapterinterface)
end

local function create_entry(t, list)
    assert(t._is_builder, "not builder can`t create_entry")
    local entry_data_list = {}
    for _,entry_data in ipairs(list) do
        check_fileds(t, entry_data)
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
    assert(t._is_builder, "not builder can`t create_one_entry")
    check_fileds(t, entry_data)
    entry_data = init_entry_data(t, entry_data)

    local ret = t._adapterinterface:create_one_entry(entry_data)
    if not ret then return nil end

    local new_entry = ormentry:new(t, entry_data)
    return add_key_select(t, new_entry, true)
end

-- 检查数据合法性
function M:check_one_filed(filed_name, filed_value)
    --主键 索引值不能改变
    local key_map = self._key_map
    assert(not key_map[filed_name], "can`t change key value")

    check_one_filed(self, filed_name, filed_value)
end

-- 设置变更标记
function M:set_change_entry(entry)
    if not self._time_obj then return end
    self._change_flag_map[entry] = true
end

local function get_entry(t, key_values)
    assert(t._is_builder, "not builder can`t get_entry")
    local key_list = t._keylist
    local entry_list = {}
    local depth = #key_list - #key_values
    local entry_list_map,is_cache_all = get_key_select(t, key_values)
    if not is_cache_all then
        local entry_data_list = t._adapterinterface:get_entry(key_values)
        if not entry_data_list or not next(entry_data_list) then return entry_list end

        for i = 1,#entry_data_list do
            local entry_data = init_entry_data(t, entry_data_list[i])
            local entry = ormentry:new(t, entry_data)
            tinsert(entry_list, add_key_select(t, entry))
        end
        set_total_count(t, key_values, #entry_data_list)
    else
        if depth > 0 then
            entry_list = table_util.depth_to_list(entry_list_map, depth)
        else
            entry_list = {entry_list_map}
        end
    end

    if t._cache_map then
        for _,entry in ipairs(entry_list) do
            t._cache_map:update_cache(entry, t)
        end
    end

    return entry_list,is_cache_all
end

local function get_one_entry(t, key_values)
    assert(t._is_builder, "not builder can`t get_one_entry")
    local key_list = t._keylist
    local entry, is_cache = get_key_select(t, key_values)
    if not is_cache then
        local entry_data = t._adapterinterface:get_one_entry(key_values)
        if not entry_data then return nil end

        entry = ormentry:new(t, entry_data)
        return add_key_select(t, entry)
    end

    if t._cache_map then
        t._cache_map:update_cache(entry, t)
    end
    return entry
end

local function save_entry(t, entry_list)
    assert(t._is_builder, "not builder can`t save_entry")
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
    assert(t._is_builder, "not builder can`t save_one_entry")
    local change_map = entry:get_change_map()
    --没有变化
    if not next(change_map) then
        return true
    end
    local entry_data = entry:get_entry_data()
    return t._adapterinterface:save_one_entry(entry_data, change_map)
end

local function delete_entry(t, key_values)
    assert(t._is_builder, "not builder can`t delete_entry")
    local entry_list = get_entry(t, key_values)
    if not next(entry_list) then return true end --没有数据可删

    local res = t._adapterinterface:delete_entry(key_values)
    if res then
        for i = 1,#entry_list do
            local entry = entry_list[i]
            if t._cache_map then
                t._cache_map:del_cache(entry)
            end
            del_key_select(t, entry, true)
        end
    end

    return res
end

-- 批量创建新数据
function M:create_entry(entry_data_list)
    return self._queue(create_entry, self, entry_data_list)
end

-- 创建一条数据
function M:create_one_entry(entry_data)
    return self._queue(create_one_entry, self, entry_data)
end

-- 查询多条数据
function M:get_entry(...)
    local key_values = {...}
    assert(#key_values > 0, "err key_values")
    return self._queue(get_entry, self, key_values)
end

-- 查询一条数据
function M:get_one_entry(...)
    local key_values = {...}
    local key_list = self._keylist
    assert(#key_values == #key_list, "args len err") --查询单条数据，必须提供所有主键
    return self._queue(get_one_entry, self, key_values)
end

-- 立即保存数据
function M:save_entry(entry_list)
    if not next(entry_list) then return entry_list end
    return self._queue(save_entry, self, entry_list)
end

-- 立即保存一条数据
function M:save_one_entry(entry)
    assert(entry,"not entry")
    return self._queue(save_one_entry, self, entry)
end

-- 删除数据
function M:delete_entry(...)
    local key_values = {...}
    assert(#key_values > 0, "not key_values")
    return self._queue(delete_entry, self, key_values)
end

-- 查询所有数据
function M:get_all_entry()
    return self._queue(get_entry, self, {})
end

-- 删除所有数据
function M:delete_all_entry()
    return self._queue(delete_entry, self, {})
end

-- 立即保存所有修改
function M:save_change_now()
    if not self._week_t then
        return
    end

    return inval_time_out(self._week_t)
end

-- 通过数据获得entry
function M:get_entry_by_data(entry_data)
    local key_list = self._keylist
    local key_values = {}
    for i = 1,#key_list do
        local filed_name = key_list[i]
        local v = assert(entry_data[filed_name], "not exists value filed_name:" .. filed_name)
        tinsert(key_values, v)
    end

    return self._queue(get_one_entry, self, key_values)
end

-- 是否启动了间隔保存
function M:is_inval_save()
    return self._time_obj ~= nil
end

return M