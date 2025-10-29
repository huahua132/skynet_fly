local log = require "skynet-fly.log"
local skynet_util = require "skynet-fly.utils.skynet_util"
local skynet = require "skynet"
local SYSCMD = require "skynet-fly.enum.SYSCMD"
local container_interface = require "skynet-fly.container.container_interface"
local SERVER_STATE_TYPE = require "skynet-fly.enum.SERVER_STATE_TYPE"

local setmetatable = setmetatable
local next = next
local assert = assert
local pairs = pairs

local M = {}

local g_tab_watch_map = {}
local g_tab_value_map = {}

skynet_util.extend_cmd_func(SYSCMD.watch_syn_table, function(tab_name, source)
    if not g_tab_watch_map[tab_name] then
        g_tab_watch_map[tab_name] = {}
    end
    g_tab_watch_map[tab_name][source] = true
    return g_tab_value_map[tab_name]
end)

skynet_util.extend_cmd_func(SYSCMD.unwatch_syn_table, function(tab_name, source)
    if g_tab_watch_map[tab_name] then
        g_tab_watch_map[tab_name][source] = nil
    end
    if not next(g_tab_watch_map[tab_name]) then
        g_tab_watch_map[tab_name] = nil
    end
end)

local function pub_table_change(tab_name, is_del, k, v)
    if skynet_util.is_hot_container_server() and container_interface.get_server_state() ~= SERVER_STATE_TYPE.starting then return end
    local watch_map = g_tab_watch_map[tab_name]
    if not watch_map then return end

    for source, _ in pairs(watch_map) do
        skynet.send(source, 'lua', SYSCMD.watch_syn_table_cmd, tab_name, is_del, k, v)
    end
end

local server = {}
local smt = {__index = server}

function M.new_server(tab_name)
    local t = {
        _tab_name = tab_name
    }
    setmetatable(t, smt)
    return t
end

function server:set(k, v)
    local tab_name = self._tab_name
    if not g_tab_value_map[tab_name] then
        g_tab_value_map[tab_name] = {}
    end
    g_tab_value_map[tab_name][k] = v
    pub_table_change(tab_name, false, k, v)
end

function server:del(k)
    local tab_name = self._tab_name
    if g_tab_value_map[tab_name] and g_tab_value_map[tab_name][k] then
        g_tab_value_map[tab_name][k] = nil
        pub_table_change(tab_name, true, k)
    end
end

function server:get(k)
    local tab_name = self._tab_name
    if g_tab_value_map[tab_name] and g_tab_value_map[tab_name][k] then
        return g_tab_value_map[tab_name][k]
    end
end

local g_client_tab_value_map = {}
skynet_util.extend_cmd_func(SYSCMD.watch_syn_table_cmd, function(tab_name, is_del, k, v)
    local tab_map = g_client_tab_value_map[tab_name]
    if not tab_map then return end
    if is_del then 
        tab_map[k] = nil
    else
        tab_map[k] = v
    end
end)

function M.watch(tab_name, rpc_interface)
    assert(rpc_interface, "not rpc_interface")
    assert(rpc_interface.send, "rpc_interface not send func")
    assert(rpc_interface.call, "rpc_interface not call func")

    if g_client_tab_value_map[tab_name] then return end
    g_client_tab_value_map[tab_name] = {}
    rpc_interface:set_update_cb(function()
        local tv = rpc_interface:call(SYSCMD.watch_syn_table, tab_name, skynet.self()) or {}
        g_client_tab_value_map[tab_name] = tv
    end)

    local tv = rpc_interface:call(SYSCMD.watch_syn_table, tab_name, skynet.self()) or {}
    g_client_tab_value_map[tab_name] = tv
end

function M.unwatch(tab_name, rpc_interface)
    assert(rpc_interface, "not rpc_interface")
    assert(rpc_interface.send, "rpc_interface not send func")
    assert(rpc_interface.call, "rpc_interface not call func")

    if not g_client_tab_value_map[tab_name] then return end
    rpc_interface:send(SYSCMD.unwatch_syn_table, tab_name, skynet.self())
    g_client_tab_value_map[tab_name] = nil
end

function M.get_table(tab_name)
    return g_client_tab_value_map[tab_name]
end

return M