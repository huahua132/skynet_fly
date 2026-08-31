---#API
---#content ---
---#content title: 远程订阅同步-订阅端
---#content date: 2024-06-29 22:00:00
---#content categories: ["skynet_fly API 文档","订阅发布，订阅同步"]
---#content category_bar: true
---#content tags: [skynet_fly_api]
---#content ---
---#content [watch_syn_client](https://github.com/huahua132/skynet_fly/blob/master/lualib/skynet-fly/rpc/watch_syn_client.lua)

local skynet = require "skynet"
local frpc_client = require "skynet-fly.client.frpc_client"
local log = require "skynet-fly.log"
local skynet_util = require "skynet-fly.utils.skynet_util"
local container_interface = require "skynet-fly.container.container_interface"
local SERVER_STATE_TYPE = require "skynet-fly.enum.SERVER_STATE_TYPE"
local WATCH_SYN_RET = require "skynet-fly.enum.WATCH_SYN_RET"

local next = next
local assert = assert
local type = type
local tinsert = table.insert
local tpack = table.pack
local tunpack = table.unpack
local tremove = table.remove
local x_pcall = x_pcall
local pairs = pairs

local M = {}

local g_is_watch_up_map = {}            --监听上线的svr_name 列表
local g_watch_channel_name_map = {}     --监听svr_name所有节点的channel_name处理函数 列表
local g_pwatch_channel_name_map = {}
local g_watch_channel_handlers_map = {}
local g_pwatch_channel_handlers_map = {}
local g_watch_channel_svr_id_map = {}   --指定svr_id的channel_name处理函数 列表
local g_pwatch_channel_svr_id_map = {}
local g_watch_channel_svr_id_handlers_map = {}
local g_pwatch_channel_svr_id_handlers_map = {}
local g_watch_cancel_channel_name_map = {}        --取消同步时的独立处理函数 列表
local g_watch_cancel_channel_handlers_map = {}
local g_watch_cancel_channel_svr_id_map = {}      --指定svr_id的取消同步处理函数 列表
local g_watch_cancel_channel_svr_id_handlers_map = {}
local g_pwatch_cancel_channel_name_map = {}       --pwatch取消同步时的独立处理函数 列表
local g_pwatch_cancel_channel_handlers_map = {}
local g_pwatch_cancel_channel_svr_id_map = {}     --指定svr_id的pwatch取消同步处理函数 列表
local g_pwatch_cancel_channel_svr_id_handlers_map = {}
local g_cluster_reqing_map = {}         --是否请求中
local g_cluster_reqfunc_map = {}        --下发已有值用
local g_pcluster_reqing_map = {}        --是否请求中
local g_pcluster_name_map = {}          --记录已有值

local function get_channel_map(svr_name, channel_name)
    if not g_watch_channel_name_map[svr_name] then
        return 
    end

    return g_watch_channel_name_map[svr_name][channel_name]
end

local function get_pchannel_map(svr_name, channel_name)
    if not g_pwatch_channel_name_map[svr_name] then
        return 
    end

    return g_pwatch_channel_name_map[svr_name][channel_name]
end

local function is_exists_handler(svr_name, channel_name, handle_name)
    local handle_map = get_channel_map(svr_name, channel_name)
    if not handle_map or not handle_map[handle_name] then
        return false
    end

    return true
end

local function get_channel_handlers(svr_name, channel_name)
    if not g_watch_channel_handlers_map[svr_name] then
        return
    end

    return g_watch_channel_handlers_map[svr_name][channel_name]
end

local function get_pchannel_handlers(svr_name, channel_name)
    if not g_pwatch_channel_handlers_map[svr_name] then
        return
    end

    return g_pwatch_channel_handlers_map[svr_name][channel_name]
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

local function get_pchannel_svr_id_map(svr_name, svr_id, channel_name)
    if not g_pwatch_channel_svr_id_map[svr_name] then
        return
    end

    if not g_pwatch_channel_svr_id_map[svr_name][svr_id] then
        return
    end

    return g_pwatch_channel_svr_id_map[svr_name][svr_id][channel_name]
end

local function is_exists_handler_svr_id(svr_name, svr_id, channel_name, handle_name)
    local handle_map = get_channel_svr_id_map(svr_name, svr_id, channel_name)
    if not handle_map or not handle_map[handle_name] then
        return false
    end

    return true
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

local function get_pchannel_svr_id_handlers(svr_name, svr_id, channel_name)
    if not g_pwatch_channel_svr_id_handlers_map[svr_name] then
        return
    end

    if not g_pwatch_channel_svr_id_handlers_map[svr_name][svr_id] then
        return
    end

    return g_pwatch_channel_svr_id_handlers_map[svr_name][svr_id][channel_name]
end

local function get_cancel_channel_map(svr_name, channel_name)
    if not g_watch_cancel_channel_name_map[svr_name] then
        return
    end

    return g_watch_cancel_channel_name_map[svr_name][channel_name]
end

local function get_cancel_channel_handlers(svr_name, channel_name)
    if not g_watch_cancel_channel_handlers_map[svr_name] then
        return
    end

    return g_watch_cancel_channel_handlers_map[svr_name][channel_name]
end

local function get_cancel_channel_svr_id_map(svr_name, svr_id, channel_name)
    if not g_watch_cancel_channel_svr_id_map[svr_name] then
        return
    end

    if not g_watch_cancel_channel_svr_id_map[svr_name][svr_id] then
        return
    end

    return g_watch_cancel_channel_svr_id_map[svr_name][svr_id][channel_name]
end

local function get_cancel_channel_svr_id_handlers(svr_name, svr_id, channel_name)
    if not g_watch_cancel_channel_svr_id_handlers_map[svr_name] then
        return
    end

    if not g_watch_cancel_channel_svr_id_handlers_map[svr_name][svr_id] then
        return
    end

    return g_watch_cancel_channel_svr_id_handlers_map[svr_name][svr_id][channel_name]
end

local function get_pcancel_channel_map(svr_name, pchannel_name)
    if not g_pwatch_cancel_channel_name_map[svr_name] then
        return
    end

    return g_pwatch_cancel_channel_name_map[svr_name][pchannel_name]
end

local function get_pcancel_channel_handlers(svr_name, pchannel_name)
    if not g_pwatch_cancel_channel_handlers_map[svr_name] then
        return
    end

    return g_pwatch_cancel_channel_handlers_map[svr_name][pchannel_name]
end

local function get_pcancel_channel_svr_id_map(svr_name, svr_id, pchannel_name)
    if not g_pwatch_cancel_channel_svr_id_map[svr_name] then
        return
    end

    if not g_pwatch_cancel_channel_svr_id_map[svr_name][svr_id] then
        return
    end

    return g_pwatch_cancel_channel_svr_id_map[svr_name][svr_id][pchannel_name]
end

local function get_pcancel_channel_svr_id_handlers(svr_name, svr_id, pchannel_name)
    if not g_pwatch_cancel_channel_svr_id_handlers_map[svr_name] then
        return
    end

    if not g_pwatch_cancel_channel_svr_id_handlers_map[svr_name][svr_id] then
        return
    end

    return g_pwatch_cancel_channel_svr_id_handlers_map[svr_name][svr_id][pchannel_name]
end

local function watch_channel_name(svr_name, svr_id, channel_name, handler)
    local cluster_name = svr_name .. ':' .. svr_id

    if handler and g_cluster_reqfunc_map[cluster_name] then
        --监听同步时，已经存在值了，需要触发一次回调
        local reqfunc = g_cluster_reqfunc_map[cluster_name][channel_name]
        if reqfunc then
            local msg = reqfunc()
            if msg then
                skynet.fork(handler, cluster_name, skynet.unpack(msg))
            end
        end
    end

    if not g_cluster_reqing_map[cluster_name] then
        g_cluster_reqing_map[cluster_name] = {}
    end
    if g_cluster_reqing_map[cluster_name][channel_name] then
        return
    end

    g_cluster_reqing_map[cluster_name][channel_name] = true
    local version, luamsg
    if not g_cluster_reqfunc_map[cluster_name] then
        g_cluster_reqfunc_map[cluster_name] = {}
    end
    g_cluster_reqfunc_map[cluster_name][channel_name] = function()
        return luamsg
    end

    local watch_switch_name = cluster_name .. ':' .. channel_name
    frpc_client:watch_frpc_client_switch(watch_switch_name, function()
        version = nil
    end)
    skynet.fork(function()
        log.info_fmt("watch_channel_name syn start svr_name[%s] svr_id[%s] channel_name[%s]", svr_name, svr_id, channel_name)
        while true do
            local ret, cv, cl = frpc_client:instance(frpc_client.FRPC_MODE.byid, svr_name, ""):set_svr_id(svr_id):subsyn(channel_name, version)
            if not ret then
                log.warn_fmt("watch_channel_name err %s ",version)
                break                                               --退出 有watch_up重新拉起
            elseif ret == WATCH_SYN_RET.disconnect or ret == WATCH_SYN_RET.unsyn then
                break                                               --退出 有watch_up重新拉起
            elseif ret == WATCH_SYN_RET.cancel then
                --推送端取消了同步数据，通知独立的cancel handler
                version = nil
                luamsg = nil
                local cancel_handlers = get_cancel_channel_handlers(svr_name, channel_name)
                local cancel_svr_id_handlers = get_cancel_channel_svr_id_handlers(svr_name, svr_id, channel_name)
                if cancel_handlers then
                    for i = 1, #cancel_handlers do
                        local handle_name = cancel_handlers[i]
                        local handle_func = g_watch_cancel_channel_name_map[svr_name][channel_name][handle_name]
                        local isok, err = x_pcall(handle_func, cluster_name, channel_name)
                        if not isok then
                            log.error("frpc watch_syn cancel msg exec err ", cluster_name, channel_name, handle_name, err)
                        end
                    end
                end
                if cancel_svr_id_handlers then
                    for i = 1, #cancel_svr_id_handlers do
                        local handle_name = cancel_svr_id_handlers[i]
                        local handle_func = g_watch_cancel_channel_svr_id_map[svr_name][svr_id][channel_name][handle_name]
                        local isok, err = x_pcall(handle_func, cluster_name, channel_name)
                        if not isok then
                            log.error("frpc watch_syn cancel svr_id msg exec err ", cluster_name, channel_name, handle_name, err)
                        end
                    end
                end
            elseif ret == WATCH_SYN_RET.move then
                
                if skynet_util.is_hot_container_server() then
                    local state = container_interface.get_server_state()
                    if state == SERVER_STATE_TYPE.fix_exited or state == SERVER_STATE_TYPE.exited then  --说明是旧服务，就不用同步了
                        break
                    end
                end
                skynet.sleep(10)
                log.debug("watch_channel_name move ", cluster_name, channel_name)
            else
                version = cv
                luamsg = cl

                local handlers = get_channel_handlers(svr_name, channel_name)
                local svr_id_handlers = get_channel_svr_id_handlers(svr_name, svr_id, channel_name)
                if handlers or svr_id_handlers then
                    local args = tpack(skynet.unpack(luamsg))
                    if handlers then
                        for i = 1, #handlers do
                            local handle_name = handlers[i]
                            local handle_func = g_watch_channel_name_map[svr_name][channel_name][handle_name]
                            local isok, err = x_pcall(handle_func, cluster_name, tunpack(args, 1, args.n))
                            if not isok then
                                log.error("frpc watch_syn msg exec err ", cluster_name, channel_name, handle_name, err)
                            end
                        end
                    end
            
                    if svr_id_handlers then
                        for i = 1, #svr_id_handlers do
                            local handle_name = svr_id_handlers[i]
                            local handle_func = g_watch_channel_svr_id_map[svr_name][svr_id][channel_name][handle_name]
                            local isok, err = x_pcall(handle_func, cluster_name, tunpack(args, 1, args.n))
                            if not isok then
                                log.error("frpc watch_syn svr_id msg exec err ", cluster_name, channel_name, handle_name, err)
                            end
                        end
                    end
                end
            end
        end
        log.info_fmt("watch_channel_name syn over svr_name[%s] svr_id[%s] channel_name[%s]", svr_name, svr_id, channel_name)
        if g_cluster_reqing_map[cluster_name] then
            g_cluster_reqing_map[cluster_name][channel_name] = nil
            if not next(g_cluster_reqing_map[cluster_name]) then
                g_cluster_reqing_map[cluster_name] = nil
            end
        end
        if g_cluster_reqfunc_map[cluster_name] then
            g_cluster_reqfunc_map[cluster_name][channel_name] = nil
            if not next(g_cluster_reqfunc_map[cluster_name]) then
                g_cluster_reqfunc_map[cluster_name] = nil
            end
        end

        frpc_client:unwatch_frpc_client_switch(watch_switch_name)
    end)
end

local function phandle_name_map_svr_name(svr_name, pchannel_name, name_map, is_watch, handler, handlers)
    handlers = handlers or get_pchannel_handlers(svr_name, pchannel_name)
    if not handlers or not name_map then return end

    for i = 1, #handlers do
        for cname in pairs(name_map) do
            local handle_name = handlers[i]
            local handle_func = handler or g_pwatch_channel_name_map[svr_name][pchannel_name][handle_name]

            if is_exists_handler(svr_name, cname, handle_name) then
                if not is_watch then
                    M.unwatch(svr_name, cname, handle_name)
                end
            else
                if is_watch then
                    M.watch(svr_name, cname, handle_name, handle_func)
                end
            end
        end
    end
end

local function phandle_name_map_svr_id(svr_name, svr_id, pchannel_name, name_map, is_watch, handler, handlers)
    handlers = handlers or get_pchannel_svr_id_handlers(svr_name, svr_id, pchannel_name)
    if not handlers or not name_map then return end
    for i = 1, #handlers do
        for cname in pairs(name_map) do
            local handle_name = handlers[i]
            local handle_func = handler or g_pwatch_channel_svr_id_map[svr_name][svr_id][pchannel_name][handle_name]
            if is_exists_handler_svr_id(svr_name, svr_id, cname, handle_name) then
                if not is_watch then
                    M.unwatch_byid(svr_name, svr_id, cname, handle_name)
                end
            else
                if is_watch then
                    M.watch_byid(svr_name, svr_id, cname, handle_name, handle_func)
                end
            end
        end
    end
end

local function phandle_name_map(svr_name, svr_id, pchannel_name, name_map, is_watch, handler)
    phandle_name_map_svr_name(svr_name, pchannel_name, name_map, is_watch, handler)
    phandle_name_map_svr_id(svr_name, svr_id, pchannel_name, name_map, is_watch, handler)
end

local function pwatch_channel_name(svr_name, svr_id, pchannel_name, handler)
    local cluster_name = svr_name .. ':' .. svr_id

    if handler and g_pcluster_name_map[svr_name] and g_pcluster_name_map[svr_name][svr_id] then
        --监听同步时，已经存在值了，需要触发一次回调
        local name_map = g_pcluster_name_map[svr_name][svr_id][pchannel_name]
        if name_map then
            phandle_name_map(svr_name, svr_id, pchannel_name, name_map, true, handler)
        end
    end

    if not g_pcluster_reqing_map[cluster_name] then
        g_pcluster_reqing_map[cluster_name] = {}
    end

    if g_pcluster_reqing_map[cluster_name][pchannel_name] then
        return
    end
    
    g_pcluster_reqing_map[cluster_name][pchannel_name] = true
    local version, name_map
    if not g_pcluster_name_map[svr_name] then
        g_pcluster_name_map[svr_name] = {}
    end
    if not g_pcluster_name_map[svr_name][svr_id] then
        g_pcluster_name_map[svr_name][svr_id] = {}
    end
    g_pcluster_name_map[svr_name][svr_id][pchannel_name] = name_map

    local watch_switch_name = cluster_name .. ':' .. pchannel_name
    frpc_client:watch_frpc_client_switch(watch_switch_name, function()
        version = nil
    end)
    skynet.fork(function()
        log.info_fmt("pwatch_channel_name psyn start svr_name[%s] svr_id[%s] pchannel_name[%s]", svr_name, svr_id, pchannel_name)
        while true do
            local ret, cv, cl = frpc_client:instance(frpc_client.FRPC_MODE.byid, svr_name, ""):set_svr_id(svr_id):psubsyn(pchannel_name, version)
            if not ret then
                log.warn_fmt("pwatch_channel_name err %s ",version)
                break                                               --退出 有watch_up重新拉起
            elseif ret == WATCH_SYN_RET.disconnect or ret == WATCH_SYN_RET.unsyn then
                break                                               --退出 有watch_up重新拉起
            elseif ret == WATCH_SYN_RET.cancel then
                --推送端取消了同步数据，先取消已有的watch映射
                phandle_name_map(svr_name, svr_id, pchannel_name, name_map, false)
                version = nil
                name_map = nil
                g_pcluster_name_map[svr_name][svr_id][pchannel_name] = name_map
                --通知独立的pwatch cancel handler（整个psubsyn被取消，channel_name传nil）
                local pcancel_handlers = get_pcancel_channel_handlers(svr_name, pchannel_name)
                local pcancel_svr_id_handlers = get_pcancel_channel_svr_id_handlers(svr_name, svr_id, pchannel_name)
                if pcancel_handlers then
                    for i = 1, #pcancel_handlers do
                        local handle_name = pcancel_handlers[i]
                        local handle_func = g_pwatch_cancel_channel_name_map[svr_name][pchannel_name][handle_name]
                        local isok, err = x_pcall(handle_func, cluster_name, pchannel_name, nil)
                        if not isok then
                            log.error("frpc pwatch_syn cancel msg exec err ", cluster_name, pchannel_name, handle_name, err)
                        end
                    end
                end
                if pcancel_svr_id_handlers then
                    for i = 1, #pcancel_svr_id_handlers do
                        local handle_name = pcancel_svr_id_handlers[i]
                        local handle_func = g_pwatch_cancel_channel_svr_id_map[svr_name][svr_id][pchannel_name][handle_name]
                        local isok, err = x_pcall(handle_func, cluster_name, pchannel_name, nil)
                        if not isok then
                            log.error("frpc pwatch_syn cancel svr_id msg exec err ", cluster_name, pchannel_name, handle_name, err)
                        end
                    end
                end
            elseif ret == WATCH_SYN_RET.move then
                if skynet_util.is_hot_container_server() then
                    local state = container_interface.get_server_state()
                    if state == SERVER_STATE_TYPE.fix_exited or state == SERVER_STATE_TYPE.exited then  --说明是旧服务，就不用同步了
                        break
                    end
                end
                skynet.sleep(10)
                log.debug("pwatch_channel_name move ", cluster_name, pchannel_name)
            else
                version = cv
                --对比旧name_map与新name_map，取消消失的channel
                local old_name_map = name_map
                name_map = cl
                if old_name_map then
                    local removed_map = nil
                    for cname in pairs(old_name_map) do
                        if not name_map or not name_map[cname] then
                            if not removed_map then
                                removed_map = {}
                            end
                            removed_map[cname] = true
                        end
                    end
                    if removed_map then
                        phandle_name_map(svr_name, svr_id, pchannel_name, removed_map, false)
                        --通知pwatch cancel handler，传递被移除的具体channel_name
                        local pcancel_handlers = get_pcancel_channel_handlers(svr_name, pchannel_name)
                        local pcancel_svr_id_handlers = get_pcancel_channel_svr_id_handlers(svr_name, svr_id, pchannel_name)
                        for removed_cname in pairs(removed_map) do
                            if pcancel_handlers then
                                for i = 1, #pcancel_handlers do
                                    local handle_name = pcancel_handlers[i]
                                    local handle_func = g_pwatch_cancel_channel_name_map[svr_name][pchannel_name][handle_name]
                                    local isok, err = x_pcall(handle_func, cluster_name, pchannel_name, removed_cname)
                                    if not isok then
                                        log.error("frpc pwatch_syn cancel removed msg exec err ", cluster_name, pchannel_name, removed_cname, handle_name, err)
                                    end
                                end
                            end
                            if pcancel_svr_id_handlers then
                                for i = 1, #pcancel_svr_id_handlers do
                                    local handle_name = pcancel_svr_id_handlers[i]
                                    local handle_func = g_pwatch_cancel_channel_svr_id_map[svr_name][svr_id][pchannel_name][handle_name]
                                    local isok, err = x_pcall(handle_func, cluster_name, pchannel_name, removed_cname)
                                    if not isok then
                                        log.error("frpc pwatch_syn cancel removed svr_id msg exec err ", cluster_name, pchannel_name, removed_cname, handle_name, err)
                                    end
                                end
                            end
                        end
                    end
                end
                g_pcluster_name_map[svr_name][svr_id][pchannel_name] = name_map
                phandle_name_map(svr_name, svr_id, pchannel_name, name_map, true)
            end
        end

        phandle_name_map(svr_name, svr_id, pchannel_name, name_map, false)

        log.info_fmt("pwatch_channel_name syn over svr_name[%s] svr_id[%s] pchannel_name[%s]", svr_name, svr_id, pchannel_name)
        if g_pcluster_reqing_map[cluster_name] then
            g_pcluster_reqing_map[cluster_name][pchannel_name] = nil
            if not next(g_pcluster_reqing_map[cluster_name]) then
                g_pcluster_reqing_map[cluster_name] = nil
            end
        end
        frpc_client:unwatch_frpc_client_switch(watch_switch_name)
    end)
end

local function unwatch_channel_name(svr_name, svr_id, channel_name)
    frpc_client:instance(frpc_client.FRPC_MODE.byid, svr_name, ""):set_svr_id(svr_id):unsubsyn(channel_name)
end

local function unpwatch_channel_name(svr_name, svr_id, channel_name)
    frpc_client:instance(frpc_client.FRPC_MODE.byid, svr_name, ""):set_svr_id(svr_id):unpsubsyn(channel_name)
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

local function check_unpwatch_channel_name(svr_name, svr_id, channel_name)
    if get_pchannel_map(svr_name, channel_name) then
        return 
    end

    if get_pchannel_svr_id_map(svr_name, svr_id, channel_name) then
        return
    end

    unpwatch_channel_name(svr_name, svr_id, channel_name)
end

local function up_cluster_server(svr_name, svr_id)
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

    local pwatch_channel_map = g_pwatch_channel_name_map[svr_name]
    if pwatch_channel_map then
        for channel_name in pairs(pwatch_channel_map) do
            pwatch_channel_name(svr_name, svr_id, channel_name)
        end
    end

    if g_pwatch_channel_svr_id_map[svr_name] and g_pwatch_channel_svr_id_map[svr_name][svr_id] then
        local watch_svr_map = g_pwatch_channel_svr_id_map[svr_name][svr_id]
        for channel_name in pairs(watch_svr_map) do
            pwatch_channel_name(svr_name, svr_id, channel_name)
        end
    end
end

---#desc watch监听 svr_name 的所有结点
---@param svr_name string 远程结点名称
---@param channel_name string 通道名
---@param handle_name string 绑定的处理名(注意：pwatch包含watch的channel_name时，不要使用相同的handle_name，这会导致watch出错，或者回调只进过pwatch或者watch注册的回调)
---@param handler function 回调处理函数
function M.watch(svr_name, channel_name, handle_name, handler)
    assert(svr_name, "not svr_name")
    assert(channel_name, "not channel_name")
    assert(handle_name, "not handle_name")
    assert(type(handler) == 'function', "handler not is function")

    if not g_is_watch_up_map[svr_name] then
        g_is_watch_up_map[svr_name] = true
        frpc_client:watch_up(svr_name, up_cluster_server)
    end

    if not g_watch_channel_name_map[svr_name] then
        g_watch_channel_name_map[svr_name] = {}
        g_watch_channel_handlers_map[svr_name] = {}
    end

    if not g_watch_channel_name_map[svr_name][channel_name] then
        g_watch_channel_name_map[svr_name][channel_name] = {}
        g_watch_channel_handlers_map[svr_name][channel_name] = {}
    end

    assert(not g_watch_channel_name_map[svr_name][channel_name][handle_name], "exists handle_name " .. handle_name)
    g_watch_channel_name_map[svr_name][channel_name][handle_name] = handler
    tinsert(g_watch_channel_handlers_map[svr_name][channel_name], handle_name)
    
    if not skynet_util.is_hot_container_server() or container_interface.get_server_state() ~= SERVER_STATE_TYPE.loading then
        local svr_list = frpc_client:get_active_svr_ids(svr_name)
        if #svr_list == 0 then
            log.warn("watch not node ", svr_name, channel_name, handle_name)
        else
            for i = 1,#svr_list do
                local svr_id = svr_list[i]
                watch_channel_name(svr_name, svr_id, channel_name, handler)
            end
        end
    end
end

---#desc 取消监听 svr_name 的所有结点
---@param svr_name string 远程结点名称
---@param channel_name string 通道名
---@param handle_name string 绑定的处理名(注意：pwatch包含watch的channel_name时，不要使用相同的handle_name，这会导致watch出错，或者回调只进过pwatch或者watch注册的回调)
function M.unwatch(svr_name, channel_name, handle_name)
    assert(svr_name, "not svr_name")
    assert(channel_name, "not channel_name")
    assert(handle_name, "not handle_name")

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

---#desc 指定svr_id监听
---@param svr_name string 远程结点名称
---@param svr_id string 远程结点名称
---@param channel_name string 通道名
---@param handle_name string 绑定的处理名(注意：pwatch包含watch的channel_name时，不要使用相同的handle_name，这会导致watch出错，或者回调只进过pwatch或者watch注册的回调)
---@param handler function 回调处理函数
function M.watch_byid(svr_name, svr_id, channel_name, handle_name, handler)
    assert(svr_name, "not svr_name")
    assert(svr_id, "not svr_id")
    assert(channel_name, "not channel_name")
    assert(handle_name, "not handle_name")
    assert(type(handler) == 'function', "handler not is function")

    if not g_is_watch_up_map[svr_name] then
        g_is_watch_up_map[svr_name] = true
        frpc_client:watch_up(svr_name, up_cluster_server)
    end

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
    end
    assert(not g_watch_channel_svr_id_map[svr_name][svr_id][channel_name][handle_name], "exists handle_name " .. handle_name)
    g_watch_channel_svr_id_map[svr_name][svr_id][channel_name][handle_name] = handler
    tinsert(g_watch_channel_svr_id_handlers_map[svr_name][svr_id][channel_name], handle_name)

    if not skynet_util.is_hot_container_server() or container_interface.get_server_state() ~= SERVER_STATE_TYPE.loading then
        watch_channel_name(svr_name, svr_id, channel_name, handler)
    end
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

---#desc pwatch监听 svr_name 的所有结点
---@param svr_name string 远程结点名称
---@param pchannel_name string 通道名匹配式  name:*:address 冒号分隔，*通配
---@param handle_name string 绑定的处理名(注意：pwatch包含watch的channel_name时，不要使用相同的handle_name，这会导致watch出错，或者回调只进过pwatch或者watch注册的回调)
---@param handler function 回调处理函数
function M.pwatch(svr_name, pchannel_name, handle_name, handler)
    assert(svr_name, "not svr_name")
    assert(pchannel_name, "not pchannel_name")
    assert(handle_name, "not handle_name")
    assert(type(handler) == 'function', "handler not is function")

    if not g_is_watch_up_map[svr_name] then
        g_is_watch_up_map[svr_name] = true
        frpc_client:watch_up(svr_name, up_cluster_server)
    end

    if not g_pwatch_channel_name_map[svr_name] then
        g_pwatch_channel_name_map[svr_name] = {}
        g_pwatch_channel_handlers_map[svr_name] = {}
    end

    if not g_pwatch_channel_name_map[svr_name][pchannel_name] then
        g_pwatch_channel_name_map[svr_name][pchannel_name] = {}
        g_pwatch_channel_handlers_map[svr_name][pchannel_name] = {}
    end
    assert(not g_pwatch_channel_name_map[svr_name][pchannel_name][handle_name], "exists handle_name " .. handle_name)
    g_pwatch_channel_name_map[svr_name][pchannel_name][handle_name] = handler
    tinsert(g_pwatch_channel_handlers_map[svr_name][pchannel_name], handle_name)
    
    if not skynet_util.is_hot_container_server() or container_interface.get_server_state() ~= SERVER_STATE_TYPE.loading then
        local svr_list = frpc_client:get_active_svr_ids(svr_name)
        if #svr_list == 0 then
            log.warn("pwatch not node ", svr_name, pchannel_name, handle_name)
        else
            for i = 1,#svr_list do
                local svr_id = svr_list[i]
                pwatch_channel_name(svr_name, svr_id, pchannel_name, handler)
            end
        end
    end
end

---#desc 取消监听 svr_name 的所有结点
---@param svr_name string 远程结点名称
---@param pchannel_name string 通道名匹配式
---@param handle_name string 绑定的处理名(注意：pwatch包含watch的channel_name时，不要使用相同的handle_name，这会导致watch出错，或者回调只进过pwatch或者watch注册的回调)
function M.unpwatch(svr_name, pchannel_name, handle_name)
    assert(svr_name, "not svr_name")
    assert(pchannel_name, "not pchannel_name")
    assert(handle_name, "not handle_name")

    local pchannel_map = get_pchannel_map(svr_name, pchannel_name)
    if not pchannel_map then return end

    if not pchannel_map[handle_name] then return end
    pchannel_map[handle_name] = nil

    local handlers = get_pchannel_handlers(svr_name, pchannel_name)
    if g_pcluster_name_map[svr_name] then
        local svr_id_map = g_pcluster_name_map[svr_name]
        for svr_id, map in pairs(svr_id_map) do
            local name_map = map[pchannel_name]
            if name_map then
                phandle_name_map_svr_name(svr_name, pchannel_name, name_map, false, nil, handlers)
            end
        end
    end
    for i = 1, #handlers do
        if handlers[i] == handle_name then
            tremove(handlers, i)
            break
        end
    end

    if next(pchannel_map) then          --说明还存在监听
        return
    end
    --不存在了本服务可以取消对pchannel_name的监听了
    g_pwatch_channel_name_map[svr_name][pchannel_name] = nil
    g_pwatch_channel_handlers_map[svr_name][pchannel_name] = nil
    local svr_list = frpc_client:get_active_svr_ids(svr_name)
    for i = 1, #svr_list do
        local svr_id = svr_list[i]
        check_unpwatch_channel_name(svr_name, svr_id, pchannel_name)
    end
    if next(g_pwatch_channel_name_map[svr_name]) then
        return
    end

    g_pwatch_channel_name_map[svr_name] = nil
    g_pwatch_channel_handlers_map[svr_name] = nil
end

---#desc 指定svr_id监听
---@param svr_name string 远程结点名称
---@param svr_id string 远程结点名称
---@param pchannel_name string 通道名匹配式
---@param handle_name string 绑定的处理名(注意：pwatch包含watch的channel_name时，不要使用相同的handle_name，这会导致watch出错，或者回调只进过pwatch或者watch注册的回调)
---@param handler function 回调处理函数
function M.pwatch_byid(svr_name, svr_id, pchannel_name, handle_name, handler)
    assert(svr_name, "not svr_name")
    assert(svr_id, "not svr_id")
    assert(pchannel_name, "not pchannel_name")
    assert(handle_name, "not handle_name")
    assert(type(handler) == 'function', "handler not is function")

    if not g_is_watch_up_map[svr_name] then
        g_is_watch_up_map[svr_name] = true
        frpc_client:watch_up(svr_name, up_cluster_server)
    end

    if not g_pwatch_channel_svr_id_map[svr_name] then
        g_pwatch_channel_svr_id_map[svr_name] = {}
        g_pwatch_channel_svr_id_handlers_map[svr_name] = {}
    end
    if not g_pwatch_channel_svr_id_map[svr_name][svr_id] then
        g_pwatch_channel_svr_id_map[svr_name][svr_id] = {}
        g_pwatch_channel_svr_id_handlers_map[svr_name][svr_id] = {}
    end
    if not g_pwatch_channel_svr_id_map[svr_name][svr_id][pchannel_name] then
        g_pwatch_channel_svr_id_map[svr_name][svr_id][pchannel_name] = {}
        g_pwatch_channel_svr_id_handlers_map[svr_name][svr_id][pchannel_name] = {}
    end
    assert(not g_pwatch_channel_svr_id_map[svr_name][svr_id][pchannel_name][handle_name], "exists handle_name " .. handle_name)
    g_pwatch_channel_svr_id_map[svr_name][svr_id][pchannel_name][handle_name] = handler
    tinsert(g_pwatch_channel_svr_id_handlers_map[svr_name][svr_id][pchannel_name], handle_name)

    if not skynet_util.is_hot_container_server() or container_interface.get_server_state() ~= SERVER_STATE_TYPE.loading then
        pwatch_channel_name(svr_name, svr_id, pchannel_name, handler)
    end
end

---#desc 指定svr_id取消监听
---@param svr_name string 远程结点名称
---@param svr_id string 远程结点名称
---@param pchannel_name string 通道名
---@param handle_name string 绑定的处理名(注意：pwatch包含watch的channel_name时，不要使用相同的handle_name，这会导致watch出错，或者回调只进过pwatch或者watch注册的回调)
function M.unpwatch_byid(svr_name, svr_id, pchannel_name, handle_name)
    assert(svr_name, "not svr_name")
    assert(svr_id, "not svr_id")
    assert(pchannel_name, "not pchannel_name")
    assert(handle_name, "not handle_name")

    local pchannel_map = get_pchannel_svr_id_map(svr_name, svr_id, pchannel_name)
    if not pchannel_map then return end
    if not pchannel_map[handle_name] then return end

    pchannel_map[handle_name] = nil
    local handlers = get_pchannel_svr_id_handlers(svr_name, svr_id, pchannel_name)
    if g_pcluster_name_map[svr_name] and g_pcluster_name_map[svr_name][svr_id] then
        local name_map = g_pcluster_name_map[svr_name][svr_id][pchannel_name]
        if name_map then
            phandle_name_map_svr_id(svr_name, svr_id, pchannel_name, name_map, false, nil, handlers)
        end
    end
    for i = 1, #handlers do
        if handlers[i] == handle_name then
            tremove(handlers, i)
            break
        end
    end

    if next(pchannel_map) then          --说明还存在监听
        return
    end
    
    g_pwatch_channel_svr_id_map[svr_name][svr_id][pchannel_name] = nil
    g_pwatch_channel_svr_id_handlers_map[svr_name][svr_id][pchannel_name] = nil
    if next(g_pwatch_channel_svr_id_map[svr_name][svr_id]) then
        return
    end
    --不存在了本服务可以取消对channel_name的监听了
    g_pwatch_channel_svr_id_map[svr_name][svr_id] = nil
    g_pwatch_channel_svr_id_handlers_map[svr_name][svr_id] = nil
    check_unpwatch_channel_name(svr_name, svr_id, pchannel_name)
    if next(g_pwatch_channel_svr_id_map[svr_name]) then
        return
    end

    g_pwatch_channel_svr_id_map[svr_name] = nil
    g_pwatch_channel_svr_id_handlers_map[svr_name] = nil
end

---#desc 注册取消同步的独立处理函数（监听 svr_name 的所有结点）
---@param svr_name string 远程结点名称
---@param channel_name string 通道名
---@param handle_name string 绑定的处理名
---@param handler function 回调处理函数 handler(cluster_name, channel_name)
function M.watch_cancel(svr_name, channel_name, handle_name, handler)
    assert(svr_name, "not svr_name")
    assert(channel_name, "not channel_name")
    assert(handle_name, "not handle_name")
    assert(type(handler) == 'function', "handler not is function")

    if not g_watch_cancel_channel_name_map[svr_name] then
        g_watch_cancel_channel_name_map[svr_name] = {}
        g_watch_cancel_channel_handlers_map[svr_name] = {}
    end

    if not g_watch_cancel_channel_name_map[svr_name][channel_name] then
        g_watch_cancel_channel_name_map[svr_name][channel_name] = {}
        g_watch_cancel_channel_handlers_map[svr_name][channel_name] = {}
    end

    assert(not g_watch_cancel_channel_name_map[svr_name][channel_name][handle_name], "exists cancel handle_name " .. handle_name)
    g_watch_cancel_channel_name_map[svr_name][channel_name][handle_name] = handler
    tinsert(g_watch_cancel_channel_handlers_map[svr_name][channel_name], handle_name)
end

---#desc 取消注册取消同步的独立处理函数（监听 svr_name 的所有结点）
---@param svr_name string 远程结点名称
---@param channel_name string 通道名
---@param handle_name string 绑定的处理名
function M.unwatch_cancel(svr_name, channel_name, handle_name)
    assert(svr_name, "not svr_name")
    assert(channel_name, "not channel_name")
    assert(handle_name, "not handle_name")

    local cancel_map = get_cancel_channel_map(svr_name, channel_name)
    if not cancel_map then return end

    if not cancel_map[handle_name] then return end
    cancel_map[handle_name] = nil

    local handlers = get_cancel_channel_handlers(svr_name, channel_name)
    for i = 1, #handlers do
        if handlers[i] == handle_name then
            tremove(handlers, i)
            break
        end
    end

    if next(cancel_map) then
        return
    end

    g_watch_cancel_channel_name_map[svr_name][channel_name] = nil
    g_watch_cancel_channel_handlers_map[svr_name][channel_name] = nil
    if not next(g_watch_cancel_channel_name_map[svr_name]) then
        g_watch_cancel_channel_name_map[svr_name] = nil
        g_watch_cancel_channel_handlers_map[svr_name] = nil
    end
end

---#desc 注册取消同步的独立处理函数（指定svr_id）
---@param svr_name string 远程结点名称
---@param svr_id string 远程结点id
---@param channel_name string 通道名
---@param handle_name string 绑定的处理名
---@param handler function 回调处理函数 handler(cluster_name, channel_name)
function M.watch_cancel_byid(svr_name, svr_id, channel_name, handle_name, handler)
    assert(svr_name, "not svr_name")
    assert(svr_id, "not svr_id")
    assert(channel_name, "not channel_name")
    assert(handle_name, "not handle_name")
    assert(type(handler) == 'function', "handler not is function")

    if not g_watch_cancel_channel_svr_id_map[svr_name] then
        g_watch_cancel_channel_svr_id_map[svr_name] = {}
        g_watch_cancel_channel_svr_id_handlers_map[svr_name] = {}
    end
    if not g_watch_cancel_channel_svr_id_map[svr_name][svr_id] then
        g_watch_cancel_channel_svr_id_map[svr_name][svr_id] = {}
        g_watch_cancel_channel_svr_id_handlers_map[svr_name][svr_id] = {}
    end
    if not g_watch_cancel_channel_svr_id_map[svr_name][svr_id][channel_name] then
        g_watch_cancel_channel_svr_id_map[svr_name][svr_id][channel_name] = {}
        g_watch_cancel_channel_svr_id_handlers_map[svr_name][svr_id][channel_name] = {}
    end

    assert(not g_watch_cancel_channel_svr_id_map[svr_name][svr_id][channel_name][handle_name], "exists cancel handle_name " .. handle_name)
    g_watch_cancel_channel_svr_id_map[svr_name][svr_id][channel_name][handle_name] = handler
    tinsert(g_watch_cancel_channel_svr_id_handlers_map[svr_name][svr_id][channel_name], handle_name)
end

---#desc 取消注册取消同步的独立处理函数（指定svr_id）
---@param svr_name string 远程结点名称
---@param svr_id string 远程结点id
---@param channel_name string 通道名
---@param handle_name string 绑定的处理名
function M.unwatch_cancel_byid(svr_name, svr_id, channel_name, handle_name)
    assert(svr_name, "not svr_name")
    assert(svr_id, "not svr_id")
    assert(channel_name, "not channel_name")
    assert(handle_name, "not handle_name")

    local cancel_map = get_cancel_channel_svr_id_map(svr_name, svr_id, channel_name)
    if not cancel_map then return end
    if not cancel_map[handle_name] then return end

    cancel_map[handle_name] = nil
    local handlers = get_cancel_channel_svr_id_handlers(svr_name, svr_id, channel_name)
    for i = 1, #handlers do
        if handlers[i] == handle_name then
            tremove(handlers, i)
            break
        end
    end

    if next(cancel_map) then
        return
    end

    g_watch_cancel_channel_svr_id_map[svr_name][svr_id][channel_name] = nil
    g_watch_cancel_channel_svr_id_handlers_map[svr_name][svr_id][channel_name] = nil
    if not next(g_watch_cancel_channel_svr_id_map[svr_name][svr_id]) then
        g_watch_cancel_channel_svr_id_map[svr_name][svr_id] = nil
        g_watch_cancel_channel_svr_id_handlers_map[svr_name][svr_id] = nil
    end
    if not next(g_watch_cancel_channel_svr_id_map[svr_name]) then
        g_watch_cancel_channel_svr_id_map[svr_name] = nil
        g_watch_cancel_channel_svr_id_handlers_map[svr_name] = nil
    end
end

---#desc 注册pwatch取消同步的独立处理函数（监听 svr_name 的所有结点）
---@param svr_name string 远程结点名称
---@param pchannel_name string 通道名匹配式
---@param handle_name string 绑定的处理名
---@param handler function 回调处理函数 handler(cluster_name, pchannel_name)
function M.pwatch_cancel(svr_name, pchannel_name, handle_name, handler)
    assert(svr_name, "not svr_name")
    assert(pchannel_name, "not pchannel_name")
    assert(handle_name, "not handle_name")
    assert(type(handler) == 'function', "handler not is function")

    if not g_pwatch_cancel_channel_name_map[svr_name] then
        g_pwatch_cancel_channel_name_map[svr_name] = {}
        g_pwatch_cancel_channel_handlers_map[svr_name] = {}
    end

    if not g_pwatch_cancel_channel_name_map[svr_name][pchannel_name] then
        g_pwatch_cancel_channel_name_map[svr_name][pchannel_name] = {}
        g_pwatch_cancel_channel_handlers_map[svr_name][pchannel_name] = {}
    end

    assert(not g_pwatch_cancel_channel_name_map[svr_name][pchannel_name][handle_name], "exists pcancel handle_name " .. handle_name)
    g_pwatch_cancel_channel_name_map[svr_name][pchannel_name][handle_name] = handler
    tinsert(g_pwatch_cancel_channel_handlers_map[svr_name][pchannel_name], handle_name)
end

---#desc 取消注册pwatch取消同步的独立处理函数（监听 svr_name 的所有结点）
---@param svr_name string 远程结点名称
---@param pchannel_name string 通道名匹配式
---@param handle_name string 绑定的处理名
function M.unpwatch_cancel(svr_name, pchannel_name, handle_name)
    assert(svr_name, "not svr_name")
    assert(pchannel_name, "not pchannel_name")
    assert(handle_name, "not handle_name")

    local cancel_map = get_pcancel_channel_map(svr_name, pchannel_name)
    if not cancel_map then return end

    if not cancel_map[handle_name] then return end
    cancel_map[handle_name] = nil

    local handlers = get_pcancel_channel_handlers(svr_name, pchannel_name)
    for i = 1, #handlers do
        if handlers[i] == handle_name then
            tremove(handlers, i)
            break
        end
    end

    if next(cancel_map) then
        return
    end

    g_pwatch_cancel_channel_name_map[svr_name][pchannel_name] = nil
    g_pwatch_cancel_channel_handlers_map[svr_name][pchannel_name] = nil
    if not next(g_pwatch_cancel_channel_name_map[svr_name]) then
        g_pwatch_cancel_channel_name_map[svr_name] = nil
        g_pwatch_cancel_channel_handlers_map[svr_name] = nil
    end
end

---#desc 注册pwatch取消同步的独立处理函数（指定svr_id）
---@param svr_name string 远程结点名称
---@param svr_id string 远程结点id
---@param pchannel_name string 通道名匹配式
---@param handle_name string 绑定的处理名
---@param handler function 回调处理函数 handler(cluster_name, pchannel_name)
function M.pwatch_cancel_byid(svr_name, svr_id, pchannel_name, handle_name, handler)
    assert(svr_name, "not svr_name")
    assert(svr_id, "not svr_id")
    assert(pchannel_name, "not pchannel_name")
    assert(handle_name, "not handle_name")
    assert(type(handler) == 'function', "handler not is function")

    if not g_pwatch_cancel_channel_svr_id_map[svr_name] then
        g_pwatch_cancel_channel_svr_id_map[svr_name] = {}
        g_pwatch_cancel_channel_svr_id_handlers_map[svr_name] = {}
    end
    if not g_pwatch_cancel_channel_svr_id_map[svr_name][svr_id] then
        g_pwatch_cancel_channel_svr_id_map[svr_name][svr_id] = {}
        g_pwatch_cancel_channel_svr_id_handlers_map[svr_name][svr_id] = {}
    end
    if not g_pwatch_cancel_channel_svr_id_map[svr_name][svr_id][pchannel_name] then
        g_pwatch_cancel_channel_svr_id_map[svr_name][svr_id][pchannel_name] = {}
        g_pwatch_cancel_channel_svr_id_handlers_map[svr_name][svr_id][pchannel_name] = {}
    end

    assert(not g_pwatch_cancel_channel_svr_id_map[svr_name][svr_id][pchannel_name][handle_name], "exists pcancel handle_name " .. handle_name)
    g_pwatch_cancel_channel_svr_id_map[svr_name][svr_id][pchannel_name][handle_name] = handler
    tinsert(g_pwatch_cancel_channel_svr_id_handlers_map[svr_name][svr_id][pchannel_name], handle_name)
end

---#desc 取消注册pwatch取消同步的独立处理函数（指定svr_id）
---@param svr_name string 远程结点名称
---@param svr_id string 远程结点id
---@param pchannel_name string 通道名匹配式
---@param handle_name string 绑定的处理名
function M.unpwatch_cancel_byid(svr_name, svr_id, pchannel_name, handle_name)
    assert(svr_name, "not svr_name")
    assert(svr_id, "not svr_id")
    assert(pchannel_name, "not pchannel_name")
    assert(handle_name, "not handle_name")

    local cancel_map = get_pcancel_channel_svr_id_map(svr_name, svr_id, pchannel_name)
    if not cancel_map then return end
    if not cancel_map[handle_name] then return end

    cancel_map[handle_name] = nil
    local handlers = get_pcancel_channel_svr_id_handlers(svr_name, svr_id, pchannel_name)
    for i = 1, #handlers do
        if handlers[i] == handle_name then
            tremove(handlers, i)
            break
        end
    end

    if next(cancel_map) then
        return
    end

    g_pwatch_cancel_channel_svr_id_map[svr_name][svr_id][pchannel_name] = nil
    g_pwatch_cancel_channel_svr_id_handlers_map[svr_name][svr_id][pchannel_name] = nil
    if not next(g_pwatch_cancel_channel_svr_id_map[svr_name][svr_id]) then
        g_pwatch_cancel_channel_svr_id_map[svr_name][svr_id] = nil
        g_pwatch_cancel_channel_svr_id_handlers_map[svr_name][svr_id] = nil
    end
    if not next(g_pwatch_cancel_channel_svr_id_map[svr_name]) then
        g_pwatch_cancel_channel_svr_id_map[svr_name] = nil
        g_pwatch_cancel_channel_svr_id_handlers_map[svr_name] = nil
    end
end

return M