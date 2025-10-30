---@diagnostic disable: undefined-field, need-check-nil
local skynet = require "skynet"
local log = require "skynet-fly.log"
local skynet_util = require "skynet-fly.utils.skynet_util"
local timer = require "skynet-fly.timer"
local guid_util = require "skynet-fly.utils.guid_util"
local ORM_SYN_CMD = require "skynet-fly.enum.ORM_SYN_CMD"
local watch_server = require "skynet-fly.rpc.watch_server"
local queue = require "skynet.queue"()

local assert = assert
local pairs = pairs
local type = type
local tinsert = table.insert
local next = next

local g_orm_plug = nil
local g_orm_obj = nil
local G_ISCLOSE = false
local g_config = nil

local g_handle = {}

--推送数据变更
local function push_orm_info(entry, isadd, isdel, change_value)
    local key_list = g_orm_obj:get_key_list()
    local main_key = key_list[1]
    local main_key_v = nil
    if not isdel then
        main_key_v = entry:get(main_key)
    else
        main_key_v = change_value[1]
    end
    local push_key = "_orm_" .. g_config.instance_name .. "_" .. main_key_v
    log.info("push_orm_info >>>", isadd, isdel, change_value, push_key, watch_server.is_can_publish(push_key))
    if not watch_server.is_can_publish(push_key) then return end       --没有监听者
    local cmd = ORM_SYN_CMD.CHANGE
    local data = nil

    if isadd then
        cmd = ORM_SYN_CMD.ADD
        data = entry:get_entry_data()
    elseif isdel then
        cmd = ORM_SYN_CMD.DEL
        data = change_value
    else
        data = change_value
        for i = 1, #key_list do
            local fn = key_list[i]
            data[fn] = entry:get(fn)
        end
    end

    watch_server.publish(push_key, cmd, data)
end

--------------------常用handle定义------------------
--批量创建数据
function g_handle.create_entry(entry_data_list)
    local entry_list = g_orm_obj:create_entry(entry_data_list)
    local data_list = {}
    for i = 1,#entry_list do
        local entry = entry_list[i]
        if entry then
            tinsert(data_list, entry:get_entry_data())
        else
            tinsert(data_list, false)
        end
    end
    return data_list
end

--创建单条数据
function g_handle.create_one_entry(entry_data)
    local entry = g_orm_obj:create_one_entry(entry_data)
    if not entry then
        return nil
    end
    return entry:get_entry_data()
end

--查询多条数据
function g_handle.get_entry(...)
    local entry_list = g_orm_obj:get_entry(...)
    local data_list = {}
    for i = 1,#entry_list do
        local entry = entry_list[i]
        tinsert(data_list, entry:get_entry_data())
    end
    return data_list
end

--查询一条数据
function g_handle.get_one_entry(...)
    local entry = g_orm_obj:get_one_entry(...)
    if not entry then
        return nil
    end

    return entry:get_entry_data()
end

--批量变更保存数据
function g_handle.change_save_entry(entry_data_list)
    local res_list = {}
    local entry_list = {}
    local index_map = {}
    local index = 1
    for i = 1,#entry_data_list do
        local entry_data = entry_data_list[i]
        local entry = g_orm_obj:get_entry_by_data(entry_data)
        if not entry then
            log.error("change_save_entry not exists ", entry_data)
            res_list[i] = false
        else
            for k,v in pairs(entry_data) do
                entry:set(k, v)
            end
            res_list[i] = true
            tinsert(entry_list, entry)
            index_map[index] = i
            index = index + 1

            push_orm_info(entry, false, false, entry_data)
        end
    end

    --没有启动间隔时间自动保存就立即保存
    if not g_orm_obj:is_inval_save() then
        local save_res_list = g_orm_obj:save_entry(entry_list)
        for i = 1, #save_res_list do
            local v = save_res_list[i]
            if not v then
                log.error("change_save_entry save err  ",entry_list[i]:get_entry_data())
            end
            local res_index = index_map[i]
            res_list[res_index] = v
        end
    end
    return res_list
end

-- 变更保存一条数据
function g_handle.change_save_one_entry(entry_data)
    local entry = g_orm_obj:get_entry_by_data(entry_data)
    if not entry then
        log.error("change_save_one_entry not exists ", entry_data)
        return nil
    end

    for k,v in pairs(entry_data) do
        entry:set(k, v)
    end
    --没有启动间隔时间自动保存就立即保存
    if not g_orm_obj:is_inval_save() then
        g_orm_obj:save_one_entry(entry)
    end
    push_orm_info(entry, false, false, entry_data)
    return true
end

-- 删除数据
function g_handle.delete_entry(...)
    return g_orm_obj:delete_entry(...)
end

-- 查询所有数据
function g_handle.get_all_entry()
    local entry_list = g_orm_obj:get_all_entry()
    local data_list = {}
    for i = 1,#entry_list do
        local entry = entry_list[i]
        tinsert(data_list, entry:get_entry_data())
    end
    return data_list
end

--删除所有数据
function g_handle.delete_all_entry()
    return g_orm_obj:delete_all_entry()
end

-- 立即保存所有修改
function g_handle.save_change_now()
    g_orm_obj:save_change_now()
end

-- 分页查询
function g_handle.get_entry_by_limit(cursor, limit, sort, ...)
    local cursor, entry_list, count = g_orm_obj:get_entry_by_limit(cursor, limit, sort, ...)
    local data_list = {}
    for i = 1,#entry_list do
        local entry = entry_list[i]
        tinsert(data_list, entry:get_entry_data())
    end
    return cursor, data_list, count
end

-- IN 查询
function g_handle.get_entry_by_in(in_values, ...)
    local entry_list = g_orm_obj:get_entry_by_in(in_values, ...)
    local data_list = {}
    for i = 1,#entry_list do
        local entry = entry_list[i]
        tinsert(data_list, entry:get_entry_data())
    end
    return data_list
end

-- 范围删除 包含left right
-- 可以有三种操作方式
-- [left, right] 范围删除  >= left <= right
-- [left, nil] 删除 >= left
-- [nil, right] 删除 <= right
function g_handle.delete_entry_by_range(left, right, ...)
    return g_orm_obj:delete_entry_by_range(left, right, ...)
end

-- IN 删除
function g_handle.delete_entry_by_in(in_values, ...)
    return g_orm_obj:delete_entry_by_in(in_values, ...)
end

-- 批量删除
function g_handle.batch_delete_entry(keys_list)
    return g_orm_obj:batch_delete_entry(keys_list)
end

-- 批量范围删除
function g_handle.batch_delete_entry_by_range(query_list)
    return g_orm_obj:batch_delete_entry_by_range(query_list)
end

--普通索引查询
function g_handle.idx_get_entry(query)
    local entry_list = g_orm_obj:idx_get_entry(query)
    local data_list = {}
    for i = 1,#entry_list do
        local entry = entry_list[i]
        tinsert(data_list, entry:get_entry_data())
    end
    return data_list
end

--普通索引分页查询
function g_handle.idx_get_entry_by_limit(cursor, limit, sort, sort_field_name, query, next_offset)
    local cursor, entry_list, count, next_offset = g_orm_obj:idx_get_entry_by_limit(cursor, limit, sort, sort_field_name, query, next_offset)
    local data_list = {}
    for i = 1,#entry_list do
        local entry = entry_list[i]
        tinsert(data_list, entry:get_entry_data())
    end
    return cursor, data_list, count, next_offset
end

--普通索引删除
function g_handle.idx_delete_entry(query)
    return g_orm_obj:idx_delete_entry(query)
end

local CMD = {}

local function add_entry_call_back(entry)
    push_orm_info(entry, true)
end

local function del_entry_call_back(keyvalues)
    push_orm_info(nil, false, true, keyvalues)
end

local function change_entry_call_back(entry, change_data)
    push_orm_info(entry, false, false, change_data)
end

function CMD.start(config)
    assert(config.orm_plug)
    g_config = config
    g_orm_plug = require(config.orm_plug)
    assert(g_orm_plug.init, "not init")        --初始化 
    assert(g_orm_plug.handle, "not handle")    --自定义处理函数

    for k,func in pairs(g_orm_plug.handle) do
        assert(type(func) == 'function', "handle k not is function:" .. k)
        assert(not g_handle[k], "handle k is exists function:" .. k)
        g_handle[k] = func
    end

    skynet.fork(function ()
        skynet.newservice("orm_table_agent", g_config.instance_name)
        g_orm_obj = queue(g_orm_plug.init)
        g_orm_obj:set_add_call_back(add_entry_call_back)
        g_orm_obj:set_del_call_back(del_entry_call_back)
        g_orm_obj:set_change_call_back(change_entry_call_back)
    end)
    return true
end

function CMD.call(func_name,...)
    if G_ISCLOSE then
        return true
    end

    local func = assert(g_handle[func_name], "func_name not exists:" .. func_name)

    return false, queue(func, ...)
end

--获取keylist
function CMD.get_key_list()
    return g_orm_obj:get_key_list()
end

function CMD.herald_exit()
    G_ISCLOSE = true
    if g_orm_obj then
        queue(g_orm_obj.save_change_now,g_orm_obj)
    end
end

function CMD.exit()
    if g_orm_obj then
        queue(g_orm_obj.save_change_now,g_orm_obj)
    end
    return true
end

function CMD.fix_exit()

end

function CMD.cancel_exit()
    G_ISCLOSE = false
end

function CMD.check_exit()
    return true
end

skynet_util.reg_shutdown_func(function()
    log.warn("-------------shutdown save begin---------------",g_config.instance_name)
    G_ISCLOSE = true
    queue(g_orm_obj.save_change_now,g_orm_obj)
    log.warn("-------------shutdown save end---------------",g_config.instance_name)
end)

return CMD