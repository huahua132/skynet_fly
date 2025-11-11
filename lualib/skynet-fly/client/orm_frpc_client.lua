---#API
---#content ---
---#content title: orm远程访问对象
---#content date: 2025-10-30 22:00:00
---#content categories: ["skynet_fly API 文档","数据库相关"]
---#content category_bar: true
---#content tags: [skynet_fly_api]
---#content ---
---#content [orm_table_client](https://github.com/huahua132/skynet_fly/blob/master/lualib/skynet-fly/client/orm_frpc_client.lua)

---#content 用于同步和调用远程的orm

local watch_client = require "skynet-fly.rpc.watch_client"
local frpc_client = require "skynet-fly.client.frpc_client"
local ORM_SYN_CMD = require "skynet-fly.enum.ORM_SYN_CMD"
local table_util = require "skynet-fly.utils.table_util"
local log = require "skynet-fly.log"

local setmetatable = setmetatable
local table = table
local next = next
local pairs = pairs
local type = type
local xx_pcall = xx_pcall
local assert = assert
local tostring = tostring
local tunpack = table.unpack

local g_instance_map = {}
local g_watch_up_map = {}
local g_weak_map = {}

local M = {}
local mt = {
    __index = M,
    __gc = function(self)
        -- GC时自动取消所有监听, 注意还是尽量手动unwatch，避免因watch中的回调函数的upvalue引用自身，形成环引用
        if not self._watched then return end
        for main_key in pairs(self._watched) do
            local push_key = "_orm_" .. self._orm_entity_instance_name .. "_" .. main_key
            watch_client.unwatch_byid(self._svr_name, self._svr_id, push_key, "orm_frpc_client")
        end
        self._watched = {}
        self._data_map = {}
    end
}

---#desc 创建远程orm访问对象
---@param svr_name string 结点名称
---@param svr_id string 结点ID
---@param orm_entity_instance_name string orm instacne_name
function M:new(svr_name, svr_id, orm_entity_instance_name)
    assert(type(svr_name) == 'string', "err svr_name = " .. tostring(svr_name))
    assert(type(svr_id) == 'number', "err svr_id = " .. tostring(svr_id))
    assert(type(orm_entity_instance_name) == 'string', "err orm_entity_instance_name = " .. tostring(orm_entity_instance_name))
    local t = {
        _cli = frpc_client:new(frpc_client.FRPC_MODE.byid, svr_name, '._ormagent_' .. orm_entity_instance_name),
        _orm_entity_instance_name = orm_entity_instance_name,
        _svr_name = svr_name,
        _svr_id = svr_id,
        _data_map = {},
        _watched = {},
    }

    if not g_weak_map[svr_name] then
        g_weak_map[svr_name] = {}
    end
    if not g_weak_map[svr_name][svr_id] then
        g_weak_map[svr_name][svr_id] = table_util.new_weak_table()
    end

    table.insert(g_weak_map[svr_name][svr_id], t)

    t._cli:set_svr_id(svr_id)

    setmetatable(t, mt)
    return t
end

---#desc 获取单例远程orm访问对象
---@param svr_name string 结点名称
---@param svr_id string 结点ID
---@param orm_entity_instance_name string orm instacne_name
function M:instance(svr_name, svr_id, orm_entity_instance_name)
    if not g_instance_map[svr_name] then
        g_instance_map[svr_name] = {} 
    end

    if not g_instance_map[svr_name][svr_id] then
        g_instance_map[svr_name][svr_id] = {}
    end
    
    if not g_instance_map[svr_name][svr_id][orm_entity_instance_name] then
        g_instance_map[svr_name][svr_id][orm_entity_instance_name] = M:new(svr_name, svr_id, orm_entity_instance_name)
    end
    return g_instance_map[svr_name][svr_id][orm_entity_instance_name]
end

--新增
local function add_map_value(main_map, one_data, keylen, data_map, main_key, keylist, add_cb)
    if keylen == 1 then
        data_map[main_key] = one_data
        if add_cb then
            xx_pcall(add_cb, one_data)
        end
    else
        local map = main_map
        -- 遍历到倒数第二层
        for j = 2, keylen - 1 do
            local fieldname = keylist[j]
            local fieldvalue = one_data[fieldname]
            if not map[fieldvalue] then
                map[fieldvalue] = {}
            end
            map = map[fieldvalue]
        end
        
        -- 处理最后一层
        local fieldname = keylist[keylen]
        local fieldvalue = one_data[fieldname]
        map[fieldvalue] = one_data
        if add_cb then
            xx_pcall(add_cb, one_data)
        end
    end
end


--改变
local function change_ma_value(main_map, data, keylen, keylist, change_cb)
    if keylen == 1 then
        -- 单key情况，直接merge到主数据
        if not main_map then
            log.warn("watch change not exists data ", data)
            return
        end
        table_util.merge(main_map, data)
        xx_pcall(change_cb, main_map, data)
    else
        -- 多key情况，找到叶子节点后merge
        local map = main_map
        for j = 2, keylen do
            local fieldname = keylist[j]
            local fieldvalue = data[fieldname]
            if not map[fieldvalue] then
                log.warn("watch change not exists data ", data)
                return
            end
            map = map[fieldvalue]
        end
        
        if not map then
            log.warn("watch change not exists data ", data)
            return
        end
        
        table_util.merge(map, data)
        xx_pcall(change_cb, map, data)
    end
end

--删除
local function del_map_value(main_map, keyvalues, data_map, main_key, del_cb)
    local len = #keyvalues
    if len == 1 then
        local one_data = data_map[main_key]
        data_map[main_key] = nil
        if one_data then
            xx_pcall(del_cb, one_data)
        end
    else
        -- 记录遍历路径，用于后续清理空table
        local path = {}
        local map = main_map
        
        -- 从第2个开始遍历（排除main_key），到倒数第二层
        for j = 2, len - 1 do
            local fieldvalue = keyvalues[j]
            if not map[fieldvalue] then
                break
            end
            -- 记录路径，用于回溯清理
            table.insert(path, {map = map, key = fieldvalue})
            map = map[fieldvalue]
        end
        
        -- 删除最后一层的数据
        local last_fieldvalue = keyvalues[len]
        local one_data = map[last_fieldvalue]
        if one_data then
            map[last_fieldvalue] = nil
            xx_pcall(del_cb, one_data)
            -- 从下往上检查并清理空的父级table
            for i = #path, 1, -1 do
                local parent_map = path[i].map
                local parent_key = path[i].key
                -- 检查当前层是否为空
                if not next(parent_map[parent_key]) then
                    parent_map[parent_key] = nil
                else
                    break  -- 如果不为空，停止向上清理
                end
            end
        end
    end
end

local function init_main_data(keylist, data_map, data, main_key)
    local main_day = nil
    local keylen = #keylist
    if keylen == 1 then
        main_day = data[1]
    else
        main_day = {}
        for i = 1, #data do
            local one_data = data[i]
            add_map_value(main_day, one_data, keylen, data_map, main_key, keylist)
        end
    end

    data_map[main_key] = main_day
end


--对应结点重连需要重连全量同步一下
local function cluster_up(svr_name, svr_id)
    if not g_weak_map[svr_name] or not g_weak_map[svr_name][svr_id] then return end 
    local weak_list = g_weak_map[svr_name][svr_id]
    for i = 1, #weak_list do
        local t = weak_list[i]
        local pre_watched = t._watched
        local data_map = t._data_map
        local watched = table_util.copy(t._watched)
        for main_key in pairs(watched) do
            if pre_watched[main_key] then
                local ret, errno, errmsg = t._cli:call_by_alias("watch_first_syn", main_key)
                if not ret then
                    log.error("re syn err ", t._svr_name, t._svr_id, main_key, errno, errmsg)
                else
                    if pre_watched[main_key] then
                        local keylist, data = tunpack(ret.result)
                        init_main_data(keylist, data_map, data, main_key)
                    end
                end
            end
        end
    end
end

---#desc 监听第一个key下所有数据
---@param main_key string orm的第一个key
---@param add_cb function(one_data) 新增回调
---@param change_cb function(one_data, change_value) 修改回调
---@param del_cb function(one_data) 删除回调 
function M:watch(main_key, add_cb, change_cb, del_cb)
    assert(main_key, "err main_key = " .. tostring(main_key))
    assert(type(add_cb) == 'function', "err add_cb = " .. tostring(add_cb))
    assert(type(change_cb) == 'function', "err add_cb = " .. tostring(change_cb))
    assert(type(del_cb) == 'function', "err add_cb = " .. tostring(del_cb))
    local watched = self._watched
    if watched[main_key] then return true end
    watched[main_key] = true
    local ret, errno, errmsg = self._cli:call_by_alias("watch_first_syn", main_key)
    if not ret then
        watched[main_key] = false
        log.error("watch err ", self._svr_name, self._svr_id, main_key, errno, errmsg)
        return false
    end

    if not g_watch_up_map[self._svr_name] then
        frpc_client:watch_up(self._svr_name, cluster_up)
        g_watch_up_map[self._svr_name] = true
    end

    local keylist, data = tunpack(ret.result)
    local data_map = self._data_map
    local keylen = #keylist
    init_main_data(keylist, data_map, data, main_key)
    local push_key = "_orm_" .. self._orm_entity_instance_name .. "_" .. main_key
    watch_client.watch_byid(self._svr_name, self._svr_id, push_key, "orm_frpc_client", function(cluster_name, syn_cmd, data)
        local main_map = data_map[main_key]
        if syn_cmd == ORM_SYN_CMD.ADD then
            add_map_value(main_map, data, keylen, data_map, main_key, keylist, add_cb)
        elseif syn_cmd == ORM_SYN_CMD.DEL then
            del_map_value(main_map, data, data_map, main_key, del_cb)
        else
            change_ma_value(main_map, data, keylen, keylist, change_cb)
        end
    end)

    return true
end

---#desc 取消监听第一个key下所有数据
---@param main_key string orm的第一个key
function M:unwatch(main_key)
    assert(main_key, "err main_key = " .. tostring(main_key))
    local data_map = self._data_map
    local watched = self._watched
    local data = data_map[main_key]
    if not data then
        return
    end

    data_map[main_key] = nil
    watched[main_key] = nil
    local push_key = "_orm_" .. self._orm_entity_instance_name .. "_" .. main_key
    watch_client.unwatch_byid(self._svr_name, self._svr_id, push_key, "orm_frpc_client")
end

---#desc 获取监听同步到的第一个key下所有数据
---@param main_key string orm的第一个key
function M:get_data(main_key)
    assert(main_key, "err main_key = " .. tostring(main_key))
    local data_map = self._data_map
    return data_map[main_key]
end

---#desc 远程调用orm的方法
---@param main_key string orm的第一个key
function M:call_orm(cmd, ...)
    local ret, errno, errmsg = self._cli:call_by_alias('call_orm', cmd, ...)
    if not ret then
        log.error("call_orm err ", self._svr_name, self._svr_id, self.orm_entity_instance_name, errno, errmsg)
        return
    end

    return tunpack(ret.result)    
end

return M