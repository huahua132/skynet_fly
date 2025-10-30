---#API
---#content ---
---#content title: 远程订阅同步-推送端
---#content date: 2024-06-29 22:00:00
---#content categories: ["skynet_fly API 文档","订阅发布，订阅同步"]
---#content category_bar: true
---#content tags: [skynet_fly_api]
---#content ---
---#content [watch_server](https://github.com/huahua132/skynet_fly/blob/master/lualib/skynet-fly/rpc/watch_server.lua)
local skynet = require "skynet"
local log = require "skynet-fly.log"
local watch_syn_table = require "skynet-fly.watch.watch_syn_table"
local service_watch_interface = require "skynet-fly.watch.interface.service_watch_interface"

local M = {}

local g_frpc_server = nil

local function get_frpc_addr()
    if g_frpc_server then
        return g_frpc_server
    end
    log.info("waiting frpc_addr >>>>>>>>>>>>>")
    g_frpc_server = skynet.queryservice('frpc_server')
    log.info("waiting over frpc_addr >>>>>>>>>>>>>")
    return g_frpc_server
end

skynet.init(function()
    skynet.fork(function()
        local interface = service_watch_interface:new(get_frpc_addr())
        watch_syn_table.watch('frpc_server.sub_cnt_syn_table', interface)
    end)
end)

---#desc 检测是否可以推送
---@param channel_name string 通道名
function M.is_can_publish(channel_name)
    local sub_cnt_syn_table = watch_syn_table.get_table('frpc_server.sub_cnt_syn_table')
    if not sub_cnt_syn_table or not sub_cnt_syn_table[channel_name] then
        return false
    end
    return true
end

---#desc 远程推送 /sub/pub (watch)模式用
---@param channel_name string 通道名
---@param ... string|number|boolean|table|nil 推送的数据
function M.publish(channel_name, ...)
    if not M.is_can_publish(channel_name) then return end

    local msg, sz = skynet.pack(...)
    local addr = get_frpc_addr()
    skynet.send(addr, 'lua', "publish", channel_name, msg, sz)
end

---#desc 远程推送同步数据 /sub_syn/pub_syn (watch_syn)模式用
---@param channel_name string 通道名
---@param ... string|number|boolean|table|nil 需同步的数据
function M.pubsyn(channel_name, ...)
    local msg = skynet.packstring(...)
    local addr = get_frpc_addr()
    skynet.send(addr, 'lua', "pubsyn", channel_name, msg)
end

return M