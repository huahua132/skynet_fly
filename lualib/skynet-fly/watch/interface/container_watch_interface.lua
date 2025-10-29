---#API
---#content ---
---#content title: 进程内的订阅同步-可热更服务的接口
---#content date: 2024-06-29 22:00:00
---#content categories: ["skynet_fly API 文档","订阅发布，订阅同步"]
---#content category_bar: true
---#content tags: [skynet_fly_api]
---#content ---
---#content [container_watch_interface](https://github.com/huahua132/skynet_fly/blob/master/lualib/skynet-fly/watch/container_watch_interface.lua)

local container_client = require "skynet-fly.client.container_client"
local table_util = require "skynet-fly.utils.table_util"
local setmetatable = setmetatable
local table = table
local pairs = pairs

local g_update_cb_map = {}
local g_mod_interface_list_map = {}

local M = {}
local mt = {__index = M}
---#desc 可热更模块接口
---@param mod_name string 可热更服务模块名
---@param instance_name string 可热更服务模块实例名
---@return table obj
function M:new(mod_name, instance_name)
    local t = {
        cli = container_client:new(mod_name, instance_name),
        update_cb = nil,
    }
    if not g_update_cb_map[mod_name] then
        local weak_list = table_util.new_weak_table()
        g_mod_interface_list_map[mod_name] = weak_list
        container_client:add_updated_cb(mod_name, function()
            for k, v in pairs(weak_list) do
                if v.update_cb then
                    v.update_cb()
                end
            end
        end)
    end
    setmetatable(t, mt)
    table.insert(g_mod_interface_list_map[mod_name], t)
    return t
end

function M:send(...)
    return self.cli:mod_send(...)
end

function M:call(...)
    return self.cli:mod_call(...)
end

function M:set_update_cb(update_cb)
    self.update_cb = update_cb
end

return M