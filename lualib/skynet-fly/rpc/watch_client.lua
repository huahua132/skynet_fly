---#API
---#content ---
---#content title: 远程订阅-订阅端
---#content date: 2024-06-29 22:00:00
---#content categories: ["skynet_fly API 文档","订阅发布，订阅同步"]
---#content category_bar: true
---#content tags: [skynet_fly_api]
---#content ---
---#content [watch_client](https://github.com/huahua132/skynet_fly/blob/master/lualib/skynet-fly/rpc/watch_client.lua)

local skynet = require "skynet"
local frpc_client = require "skynet-fly.client.frpc_client"
local log = require "skynet-fly.log"
local SYSCMD = require "skynet-fly.enum.SYSCMD"
local skynet_util = require "skynet-fly.utils.skynet_util"
local module_info = require "skynet-fly.etc.module_info"
local tti = require "skynet-fly.cache.tti"
local timer = require "skynet-fly.timer"
local contriner_interface = require "skynet-fly.contriner.contriner_interface"
local SERVER_STATE_TYPE = require "skynet-fly.enum.SERVER_STATE_TYPE"
local queue = require "skynet.queue"()

local x_pcall = x_pcall
local next = next
local assert = assert
local type = type
local tpack = table.pack
local tunpack = table.unpack
local tinsert = table.insert
local tremove = table.remove
local pairs = pairs

local M = {}

local g_is_watch_up_map = {}            --监听上线的svr_name 列表
local g_watch_channel_name_map = {}     --监听svr_name所有节点的channel_name处理函数 列表
local g_watch_channel_handlers_map = {}
local g_watch_channel_svr_id_map = {}   --指定svr_id的channel_name处理函数 列表
local g_watch_channel_svr_id_handlers_map = {}
local g_tti_map = {}

local function get_channel_map(svr_name, channel_name)
    if not g_watch_channel_name_map[svr_name] then
        return 
    end

    return g_watch_channel_name_map[svr_name][channel_name]
end

local function get_channel_handlers(svr_name, channel_name)
    if not g_watch_channel_handlers_map[svr_name] then
        return
    end

    return g_watch_channel_handlers_map[svr_name][channel_name]
end

local function get_channel_svr_id_map(svr_name, svr_id, channel_name)
    if not g_watch_channel_svr_id_map[svr_name] then
        return
    end

    if not g_watch_channel_svr_id_map[svr_name][svr_id] then
        return
    end

    return g_watch_channel_svr_id_map[svr_name][svr_id][channel_name]
end

local function get_channel_svr_id_handlers(svr_name, svr_id, channel_name)
    if not g_watch_channel_svr_id_handlers_map[svr_name] then
        return
    end

    if not g_watch_channel_svr_id_handlers_map[svr_name][svr_id] then
        return
    end

    return g_watch_channel_svr_id_handlers_map[svr_name][svr_id][channel_name]
end

skynet_util.extend_cmd_func(SYSCMD.frpcpubmsg, function(session, svr_name, svr_id, channel_name, msg)
    local cluster_name = svr_name .. ':' .. svr_id
    if not g_tti_map[cluster_name] then
        g_tti_map[cluster_name] = tti:new(timer.minute)
    end

    local tti_obj = g_tti_map[cluster_name]
    if tti_obj:get_cache(session) then
        return
    end

    tti_obj:set_cache(session, true)
    local handlers = get_channel_handlers(svr_name, channel_name)
    local svr_id_handlers = get_channel_svr_id_handlers(svr_name, svr_id, channel_name)
    if handlers or svr_id_handlers then
        local args = tpack(skynet.unpack(msg))
        if handlers then
            for i = 1, #handlers do
                local handle_name = handlers[i]
                local handle_func = g_watch_channel_name_map[svr_name][channel_name][handle_name]
                local isok, err = x_pcall(handle_func, cluster_name, tunpack(args, 1, args.n))
                if not isok then
                    log.error("frpc watch msg exec err ", cluster_name, channel_name, handle_name, err)
                end
            end
        end

        if svr_id_handlers then
            for i = 1, #svr_id_handlers do
                local handle_name = svr_id_handlers[i]
                local handle_func = g_watch_channel_svr_id_map[svr_name][svr_id][channel_name][handle_name]
                local isok, err = x_pcall(handle_func, cluster_name, tunpack(args, 1, args.n))
                if not isok then
                    log.error("frpc watch svr_id msg exec err ", cluster_name, channel_name, handle_name, err)
                end
            end
        end
    end
end)

local function get_unique_name()
    local base_info = module_info.get_base_info()
    local unique_name = nil
    if base_info.index then                         --是可热更服务
        unique_name = base_info.module_name .. ':' .. base_info.index
    else
        unique_name = skynet.address(skynet.self()) --普通服务
    end
    return unique_name
end

local function watch_channel_name(svr_name, svr_id, channel_name)
    local unique_name = get_unique_name()
    local isok,err = frpc_client:instance(svr_name, ""):set_svr_id(svr_id):sub(channel_name, unique_name)
    if not isok then
        log.warn("watch_channel_name faild", svr_name, svr_id, channel_name, err)
    else
        log.warn("watch_channel_name succ ", svr_name, svr_id, channel_name)
    end
end

local function unwatch_channel_name(svr_name, svr_id, channel_name)
    local unique_name = get_unique_name()
    local isok,err = frpc_client:instance(svr_name, ""):set_svr_id(svr_id):unsub(channel_name, unique_name)
    if not isok then
        log.warn("unwatch_channel_name faild", svr_name, svr_id, channel_name, err)
    else
        log.warn("unwatch_channel_name succ ", svr_name, svr_id, channel_name)
    end
end

local function check_unwatch_channel_name(svr_name, svr_id, channel_name)
    if get_channel_map(svr_name, channel_name) then
        return 
    end

    if get_channel_svr_id_map(svr_name, svr_id, channel_name) then
        return
    end

    unwatch_channel_name(svr_name, svr_id, channel_name)
end

local function queue_up_cluster_server(svr_name, svr_id)
    local watch_channel_map = g_watch_channel_name_map[svr_name]
    if watch_channel_map then
        for channel_name in pairs(watch_channel_map) do
            watch_channel_name(svr_name, svr_id, channel_name)
        end
    end

    if g_watch_channel_svr_id_map[svr_name] and g_watch_channel_svr_id_map[svr_name][svr_id] then
        local watch_svr_map = g_watch_channel_svr_id_map[svr_name][svr_id]
        for channel_name in pairs(watch_svr_map) do
            watch_channel_name(svr_name, svr_id, channel_name)
        end
    end
end

local function up_cluster_server(svr_name, svr_id)
    queue(queue_up_cluster_server, svr_name, svr_id)
end

local function watch(svr_name, channel_name, handle_name, handler)
    if not g_is_watch_up_map[svr_name] then
        g_is_watch_up_map[svr_name] = true
        frpc_client:watch_up(svr_name, up_cluster_server)
    end

    local is_new = false
    if not g_watch_channel_name_map[svr_name] then
        g_watch_channel_name_map[svr_name] = {}
        g_watch_channel_handlers_map[svr_name] = {}
    end

    if not g_watch_channel_name_map[svr_name][channel_name] then
        g_watch_channel_name_map[svr_name][channel_name] = {}
        g_watch_channel_handlers_map[svr_name][channel_name] = {}
        is_new = true
    end
    assert(not g_watch_channel_name_map[svr_name][channel_name][handle_name], "exists handle_name " .. handle_name)
    g_watch_channel_name_map[svr_name][channel_name][handle_name] = handler
    tinsert(g_watch_channel_handlers_map[svr_name][channel_name], handle_name)
    
    if is_new and (not skynet_util.is_hot_container_server() or contriner_interface.get_server_state() ~= SERVER_STATE_TYPE.loading) then
        local svr_list = frpc_client:get_active_svr_ids(svr_name)
        if #svr_list == 0 then
            log.warn("watch not node ", svr_name, channel_name, handle_name)
        else
            for i = 1,#svr_list do
                local svr_id = svr_list[i]
                watch_channel_name(svr_name, svr_id, channel_name)
            end
        end
    end
end

---#desc watch监听 svr_name 的所有结点
---@param svr_name string 远程结点名称
---@param channel_name string 通道名
---@param handle_name string 绑定的处理名
---@param handler function 回调处理函数
function M.watch(svr_name, channel_name, handle_name, handler)
    assert(svr_name, "not svr_name")
    assert(channel_name, "not channel_name")
    assert(handle_name, "not handle_name")
    assert(type(handler) == 'function', "handler not is function")
    queue(watch, svr_name, channel_name, handle_name, handler)
end

local function unwatch(svr_name, channel_name, handle_name)
    local channel_map = get_channel_map(svr_name, channel_name)
    if not channel_map then return end

    if not channel_map[handle_name] then return end
    channel_map[handle_name] = nil
    local handlers = get_channel_handlers(svr_name, channel_name)
    for i = 1, #handlers do
        if handlers[i] == handle_name then
            tremove(handlers, i)
            break
        end
    end

    if next(channel_map) then          --说明还存在监听
        return
    end
    --不存在了本服务可以取消对channel_name的监听了
    g_watch_channel_name_map[svr_name][channel_name] = nil
    g_watch_channel_handlers_map[svr_name][channel_name] = nil
    local svr_list = frpc_client:get_active_svr_ids(svr_name)
    for i = 1, #svr_list do
        local svr_id = svr_list[i]
        check_unwatch_channel_name(svr_name, svr_id, channel_name)
    end
    if next(g_watch_channel_name_map[svr_name]) then
        return
    end

    g_watch_channel_name_map[svr_name] = nil
    g_watch_channel_handlers_map[svr_name] = nil
end 

---#desc 取消监听 svr_name 的所有结点
---@param svr_name string 远程结点名称
---@param channel_name string 通道名
---@param handle_name string 绑定的处理名
function M.unwatch(svr_name, channel_name, handle_name)
    assert(svr_name, "not svr_name")
    assert(channel_name, "not channel_name")
    assert(handle_name, "not handle_name")
    queue(unwatch, svr_name, channel_name, handle_name)
end

local function watch_byid(svr_name, svr_id, channel_name, handle_name, handler)
    if not g_is_watch_up_map[svr_name] then
        g_is_watch_up_map[svr_name] = true
        frpc_client:watch_up(svr_name, up_cluster_server)
    end

    local is_new = false
    if not g_watch_channel_svr_id_map[svr_name] then
        g_watch_channel_svr_id_map[svr_name] = {}
        g_watch_channel_svr_id_handlers_map[svr_name] = {}
    end
    if not g_watch_channel_svr_id_map[svr_name][svr_id] then
        g_watch_channel_svr_id_map[svr_name][svr_id] = {}
        g_watch_channel_svr_id_handlers_map[svr_name][svr_id] = {}
    end
    if not g_watch_channel_svr_id_map[svr_name][svr_id][channel_name] then
        g_watch_channel_svr_id_map[svr_name][svr_id][channel_name] = {}
        g_watch_channel_svr_id_handlers_map[svr_name][svr_id][channel_name] = {}
        is_new = true
    end
    assert(not g_watch_channel_svr_id_map[svr_name][svr_id][channel_name][handle_name], "exists handle_name " .. handle_name)
    g_watch_channel_svr_id_map[svr_name][svr_id][channel_name][handle_name] = handler
    tinsert(g_watch_channel_svr_id_handlers_map[svr_name][svr_id][channel_name], handle_name)

    if is_new and (not skynet_util.is_hot_container_server() or contriner_interface.get_server_state() ~= SERVER_STATE_TYPE.loading) then
        watch_channel_name(svr_name, svr_id, channel_name)
    end
end

---#desc 指定svr_id监听
---@param svr_name string 远程结点名称
---@param svr_id string 远程结点名称
---@param channel_name string 通道名
---@param handle_name string 绑定的处理名
function M.watch_byid(svr_name, svr_id, channel_name, handle_name, handler)
    assert(svr_name, "not svr_name")
    assert(svr_id, "not svr_id")
    assert(channel_name, "not channel_name")
    assert(handle_name, "not handle_name")
    assert(type(handler) == 'function', "handler not is function")
    queue(watch_byid, svr_name, svr_id, channel_name, handle_name, handler)
end

local function unwatch_byid(svr_name, svr_id, channel_name, handle_name)
    local channel_map = get_channel_svr_id_map(svr_name, svr_id, channel_name)
    if not channel_map then return end
    if not channel_map[handle_name] then return end

    channel_map[handle_name] = nil

    local handlers = get_channel_svr_id_handlers(svr_name, svr_id, channel_name)
    for i = 1, #handlers do
        if handlers[i] == handle_name then
            tremove(handlers, i)
            break
        end
    end

    if next(channel_map) then          --说明还存在监听
        return
    end
    
    g_watch_channel_svr_id_map[svr_name][svr_id][channel_name] = nil
    g_watch_channel_svr_id_handlers_map[svr_name][svr_id][channel_name] = nil
    if next(g_watch_channel_svr_id_map[svr_name][svr_id]) then
        return
    end
    --不存在了本服务可以取消对channel_name的监听了
    g_watch_channel_svr_id_map[svr_name][svr_id] = nil
    g_watch_channel_svr_id_handlers_map[svr_name][svr_id] = nil
    check_unwatch_channel_name(svr_name, svr_id, channel_name)
    if next(g_watch_channel_svr_id_map[svr_name]) then
        return
    end

    g_watch_channel_svr_id_map[svr_name] = nil
    g_watch_channel_svr_id_handlers_map[svr_name] = nil
end

---#desc 指定svr_id取消监听
---@param svr_name string 远程结点名称
---@param svr_id string 远程结点名称
---@param channel_name string 通道名
function M.unwatch_byid(svr_name, svr_id, channel_name, handle_name)
    assert(svr_name, "not svr_name")
    assert(svr_id, "not svr_id")
    assert(channel_name, "not channel_name")
    assert(handle_name, "not handle_name")
    queue(unwatch_byid, svr_name, svr_id, channel_name, handle_name)
end

return M