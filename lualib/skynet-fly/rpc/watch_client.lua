local skynet = require "skynet"
local frpc_client = require "skynet-fly.client.frpc_client"
local log = require "skynet-fly.log"

local table = table
local pairs = pairs

local M = {}

local g_is_watch_up_map = {}
local g_watch_channel_name_map = {}

local function watch_channel_name(svr_name, svr_id, channel_name)
    log.info("watch_channel_name >>> ", svr_name, svr_id, channel_name)
    
end

local function up_cluster_server(svr_name, svr_id)
    local watch_channel_map = g_watch_channel_name_map[svr_name]
    if not watch_channel_map then
        return
    end

    for channel_name in pairs(watch_channel_map) do
        skynet.fork(watch_channel_name, svr_name, svr_id, channel_name)
    end
end

function M.watch(svr_name, channel_name, handler)
    if not g_is_watch_up_map[svr_name] then
        g_is_watch_up_map[svr_name] = true

        skynet.fork(function()
            frpc_client:watch_up(svr_name, up_cluster_server)
        end)
    end

    if not g_watch_channel_name_map[svr_name] then
        g_watch_channel_name_map[svr_name] = {}
    end

    if not g_watch_channel_name_map[svr_name][channel_name] then
        g_watch_channel_name_map[svr_name][channel_name] = {}
    end

    table.insert(g_watch_channel_name_map[svr_name][channel_name], handler)
end

return M