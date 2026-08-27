---#API
---#content ---
---#content title: orm本地代理访问对象
---#content date: 2026-08-27 00:00:00
---#content categories: ["skynet_fly API 文档","数据库相关"]
---#content category_bar: true
---#content tags: [skynet_fly_api]
---#content ---
---#content [orm_table_proxy](https://github.com/huahua132/skynet_fly/blob/master/lualib/skynet-fly/client/orm_table_proxy.lua)

---#content 本地代理访问orm：一个proxy对象代理某张表的某个首个主键(main_key)下的所有数据
---#content 读走本地快照缓存(惰性同步拉取一次，之后零call)，写缓冲后由定时器异步flush到orm_table_m(零call)
---#content 不依赖frpc，纯本节点访问。适用于本服务独占读写某块数据、且需要规避同步call阻塞的场景

local skynet = require "skynet"
local log = require "skynet-fly.log"
local timer = require "skynet-fly.timer"
local table_util = require "skynet-fly.utils.table_util"
local container_client = require "skynet-fly.client.container_client"
local orm_table_client = require "skynet-fly.client.orm_table_client"

local next = next
local type = type
local pairs = pairs
local assert = assert
local tostring = tostring
local tunpack = table.unpack
local tinsert = table.insert

container_client:register("orm_table_m")

--前置声明(供 M:new 在构造时同步拉取快照使用)
local get_key_list = nil
local build_snapshot_entry = nil

local M = {}
local mt = {
    __index = M,
    __gc = function(self)
        if self._flush_timer then
            self._flush_timer:cancel()
            self._flush_timer:release()
            self._flush_timer = nil
        end
    end
}

--写操作缓冲条目：{op=op, data=data}
local FLUSH_INTERVAL = timer.second / 10   --默认100ms flush一次

--快照叶子包裹层（多主键嵌套表中区分中间key节点和叶子entry_data，内部用，不污染用户entry_data）
local LEAF_KEY = "__proxy_leaf__"

-- 叶子包裹：{__proxy_leaf=true, data=entry_data}
local function new_leaf(entry_data)
    return { [LEAF_KEY] = true, data = entry_data }
end

local function is_leaf(node)
    return type(node) == "table" and rawget(node, LEAF_KEY) ~= nil
end

--收集某个子树下所有叶子（返回entry_data列表）
local function collect_leaves(node, res)
    if is_leaf(node) then
        tinsert(res, node.data)
        return
    end
    for _, v in pairs(node) do
        if type(v) == "table" then
            collect_leaves(v, res)
        end
    end
end

--拷贝entry_data返回给用户（独立表，修改不影响快照，需通过save_*写回）
local function copy_entry_data(data)
    return table_util.copy(data)
end

---#desc 创建本地代理对象(构造时同步拉取该main_key下所有数据到本地快照)
---@param orm_name string orm_table_m 中的instance_name
---@param main_key any 首个主键的值(该proxy代理此主键下的所有数据)
---@param flush_interval number|nil flush间隔(单位skynet tick,100=1秒),默认100ms
---@return table obj
function M:new(orm_name, main_key, flush_interval)
    assert(orm_name, "not orm_name")
    assert(main_key ~= nil, "not main_key")
    local t = {
        _orm_name = orm_name,
        _main_key = main_key,     --首个主键的值
        _key_list = nil,          --主键字段列表(构造时获取并缓存)
        _snapshot = nil,          --快照根节点：单主键=叶子包裹；多主键=key2嵌套树
        _wait_list = {},          --待flush的写操作 {op=, data=}
        _flush_interval = flush_interval or FLUSH_INTERVAL,
        _flush_timer = nil,
    }
    setmetatable(t, mt)
    --构造时同步拉取该main_key下所有数据，建立本地快照(一次同步call)
    get_key_list(t)   --获取并缓存主键字段列表
    local data_list = orm_table_client:new(orm_name):get_entry(main_key)
    for i = 1, #data_list do
        build_snapshot_entry(t, data_list[i])
    end
    return t
end

--快照已同步拉取(构造时已建立，always true)
--保留此函数：API内多处调用，作为后续可能热更/重建快照的扩展点
local function ensure_snapshot(self)
    return true
end

--获取key_list(首次同步call一次，之后缓存)
--orm_table_m的g_orm_obj是在fork中异步初始化的，刚启动时可能未就绪，需要重试等待
get_key_list = function(self)
    if self._key_list then
        return self._key_list
    end
    local client = container_client:instance("orm_table_m", self._orm_name)
    for i = 1, 100 do
        local isok, key_list = pcall(function()
            return client:mod_call_by_name("get_key_list")
        end)
        if isok and key_list then
            self._key_list = key_list
            return key_list
        end
        skynet.sleep(10)
    end
    error("get_key_list err " .. tostring(self._orm_name))
end

--从entry_data提取完整主键值列表
local function get_keyvalues_from_data(self, entry_data)
    local key_list = get_key_list(self)
    local kv = {}
    for i = 1, #key_list do
        local v = assert(entry_data[key_list[i]], "not key value field_name:" .. key_list[i])
        tinsert(kv, v)
    end
    return kv
end

--校验entry_data的首个主键是否匹配本proxy的main_key
local function check_main_key(self, entry_data)
    local key_list = get_key_list(self)
    local v = assert(entry_data[key_list[1]], "not key value field_name:" .. key_list[1])
    assert(v == self._main_key, "entry_data main_key not match proxy main_key:" .. tostring(self._main_key))
end

--把一条entry_data写入快照树(本地可见)
--调用方负责传入独立拷贝(API层统一copy，wire数据天然独立)
--结构：self._snapshot = { key2值 = { key3值 = {...} = 叶子包裹 } }
build_snapshot_entry = function(self, entry_data)
    local key_list = get_key_list(self)
    local kv = get_keyvalues_from_data(self, entry_data)
    local keylen = #key_list
    if keylen == 1 then
        self._snapshot = new_leaf(entry_data)
        return
    end

    if not self._snapshot then
        self._snapshot = {}
    end
    local node = self._snapshot
    --遍历 key2 到 key(keylen-1)，建中间层
    for j = 2, keylen - 1 do
        local k = kv[j]
        if not node[k] then
            node[k] = {}
        end
        node = node[k]
    end
    --最后一层 key(keylen) 放叶子
    node[kv[keylen]] = new_leaf(entry_data)
end

--从完整主键值定位快照中的叶子（返回 叶子包裹, 父节点, 最后key）
local function locate_leaf(self, key_values)
    if #key_values == 1 then
        return self._snapshot, self, nil
    end
    local node = self._snapshot
    if not node then return nil end
    for j = 2, #key_values - 1 do
        local v = key_values[j]
        node = node[v]
        if not node then return nil end
    end
    local last_key = key_values[#key_values]
    return node[last_key], node, last_key
end

--删除快照中的叶子并清理空父级
local function del_leaf_from_snapshot(self, key_values)
    local len = #key_values
    if len == 1 then
        self._snapshot = nil
        return
    end
    local path = {}
    local node = self._snapshot
    if not node then return end
    for j = 2, len - 1 do
        local v = key_values[j]
        if not node[v] then return end
        tinsert(path, {node = node, key = v})
        node = node[v]
    end
    node[key_values[len]] = nil
    for i = #path, 1, -1 do
        local parent = path[i].node
        local key = path[i].key
        if not next(parent[key]) then
            parent[key] = nil
        else
            break
        end
    end
end

--入队写操作
local function enqueue(self, op, data)
    tinsert(self._wait_list, {op = op, data = data})
end

--定时器flush：批量把待写操作异步send到orm_table_m(零call)
local function do_flush(self)
    if #self._wait_list <= 0 then return end
    local wait_list = self._wait_list
    self._wait_list = {}
    local client = container_client:instance("orm_table_m", self._orm_name)

    local creates = {}   --批量create
    local saves = {}     --批量save(change_save_entry)
    local dels = {}      --批量delete(完整主键值列表)
    local del_all = false

    for i = 1, #wait_list do
        local item = wait_list[i]
        local op = item.op
        if op == "create" then
            tinsert(creates, item.data)
        elseif op == "save" then
            tinsert(saves, item.data)
        elseif op == "del" then
            tinsert(dels, item.data)
        elseif op == "del_all" then
            del_all = true
        end
    end

    --按顺序发送，保证 create 先于 save/delete
    --save逐条change_save_one_entry：批量change_save_entry在无缓存模式下
    --同一entry连续set会因change_map合并导致只落库第一条，逐条发送可避免
    if #creates > 0 then
        client:mod_send_by_name("call", "create_entry", creates)
    end
    for i = 1, #saves do
        client:mod_send_by_name("call", "change_save_one_entry", saves[i])
    end
    for i = 1, #dels do
        client:mod_send_by_name("call", "delete_entry", tunpack(dels[i]))
    end
    if del_all then
        --本proxy只代理main_key下的数据，删除该main_key下所有数据
        client:mod_send_by_name("call", "delete_entry", self._main_key)
    end
end

--确保flush定时器已启动(首次写时启动)
local function ensure_flush_timer(self)
    if self._flush_timer then
        return
    end
    self._flush_timer = timer:new_loop(self._flush_interval, function()
        local isok, err = x_pcall(do_flush, self)
        if not isok then
            log.error("orm_table_proxy flush err ", self._orm_name, self._main_key, err)
        end
    end)
end

---#desc 创建一条数据(异步落库，本地立即可读)
---@param entry_data table 完整entry_data(含主键，首个主键必须等于本proxy的main_key)
function M:create_one_entry(entry_data)
    assert(entry_data, "not entry_data")
    check_main_key(self, entry_data)
    local data_copy = table_util.copy(entry_data)
    build_snapshot_entry(self, data_copy)
    ensure_flush_timer(self)
    enqueue(self, "create", data_copy)
end

---#desc 批量创建数据(异步落库，本地立即可读)
---@param entry_data_list table[] 完整entry_data列表(首个主键必须等于本proxy的main_key)
function M:create_entry(entry_data_list)
    assert(entry_data_list, "not entry_data_list")
    for i = 1, #entry_data_list do
        local entry_data = entry_data_list[i]
        check_main_key(self, entry_data)
        local data_copy = table_util.copy(entry_data)
        build_snapshot_entry(self, data_copy)
        enqueue(self, "create", data_copy)
    end
    ensure_flush_timer(self)
end

---#desc 查询该main_key下所有数据(读本地快照，首次同步拉取后零call)
---@return table[] 数据列表(独立拷贝，修改需通过save_*写回)
function M:get_all_entry()
    ensure_snapshot(self)
    if not self._snapshot then return {} end

    local leaves = {}
    collect_leaves(self._snapshot, leaves)
    local res = {}
    for i = 1, #leaves do
        tinsert(res, copy_entry_data(leaves[i]))
    end
    return res
end

---#desc 查询多条数据(读本地快照，首次同步拉取后零call)
---@param ... any[] 最左前缀key值列表，首个必须等于本proxy的main_key
---@return table[] 数据列表(独立拷贝，修改需通过save_*写回)
function M:get_entry(...)
    local key_values = {...}
    assert(#key_values > 0, "err key_values")
    assert(key_values[1] == self._main_key, "key_values[1] not match main_key:" .. tostring(self._main_key))
    ensure_snapshot(self)
    if not self._snapshot then return {} end

    local node = self._snapshot
    if is_leaf(node) then
        --单主键表
        return { copy_entry_data(node.data) }
    end
    for j = 2, #key_values do
        node = node[key_values[j]]
        if not node then return {} end
    end

    local leaves = {}
    collect_leaves(node, leaves)
    local res = {}
    for i = 1, #leaves do
        tinsert(res, copy_entry_data(leaves[i]))
    end
    return res
end

---#desc 查询一条数据(读本地快照，首次同步拉取后零call)
---@param ... any[] 完整主键值列表，首个必须等于本proxy的main_key
---@return table|nil 数据(独立拷贝，修改需通过save_*写回)
function M:get_one_entry(...)
    local key_values = {...}
    local key_list = get_key_list(self)
    assert(#key_values == #key_list, "args len err")
    assert(key_values[1] == self._main_key, "key_values[1] not match main_key:" .. tostring(self._main_key))
    ensure_snapshot(self)
    local wrapper = locate_leaf(self, key_values)
    if not wrapper then return nil end
    return copy_entry_data(wrapper.data)
end

---#desc 变更保存一条数据(异步落库，本地立即可读)
---@param entry_data table 完整entry_data(含主键+所有要保留的字段，首个主键必须等于本proxy的main_key)
function M:save_one_entry(entry_data)
    assert(entry_data, "not entry_data")
    check_main_key(self, entry_data)
    ensure_snapshot(self)
    local data_copy = table_util.copy(entry_data)
    local kv = get_keyvalues_from_data(self, data_copy)
    local wrapper = locate_leaf(self, kv)
    if wrapper then
        table_util.merge(wrapper.data, data_copy)
    else
        build_snapshot_entry(self, data_copy)
    end
    ensure_flush_timer(self)
    enqueue(self, "save", data_copy)
end

---#desc 批量变更保存(异步落库，本地立即可读)
---@param entry_data_list table[] 完整entry_data列表(首个主键必须等于本proxy的main_key)
function M:save_entry(entry_data_list)
    assert(entry_data_list, "not entry_data_list")
    ensure_snapshot(self)
    for i = 1, #entry_data_list do
        local entry_data = entry_data_list[i]
        check_main_key(self, entry_data)
        local data_copy = table_util.copy(entry_data)
        local kv = get_keyvalues_from_data(self, data_copy)
        local wrapper = locate_leaf(self, kv)
        if wrapper then
            table_util.merge(wrapper.data, data_copy)
        else
            build_snapshot_entry(self, data_copy)
        end
        enqueue(self, "save", data_copy)
    end
    ensure_flush_timer(self)
end

---#desc 删除数据(异步落库，本地立即可见) 最左前缀key，首个必须等于本proxy的main_key
function M:delete_entry(...)
    local key_values = {...}
    assert(#key_values > 0, "err key_values")
    assert(key_values[1] == self._main_key, "key_values[1] not match main_key:" .. tostring(self._main_key))
    ensure_snapshot(self)

    --本地快照删除所有匹配叶子
    local list = self:get_entry(...)
    for i = 1, #list do
        local one = list[i]
        local kv = get_keyvalues_from_data(self, one)
        del_leaf_from_snapshot(self, kv)
    end

    ensure_flush_timer(self)
    enqueue(self, "del", key_values)
end

---#desc 删除该main_key下所有数据(异步落库，本地立即可见)
function M:delete_all_entry()
    ensure_snapshot(self)
    self._snapshot = nil
    ensure_flush_timer(self)
    enqueue(self, "del_all", true)
end

---#desc 强制立即flush待写队列
function M:flush_now()
    do_flush(self)
end

return M
