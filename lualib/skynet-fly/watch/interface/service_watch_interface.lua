
---#API
---#content ---
---#content title: 进程内的订阅同步-可热更服务的接口
---#content date: 2024-06-29 22:00:00
---#content categories: ["skynet_fly API 文档","订阅发布，订阅同步"]
---#content category_bar: true
---#content tags: [skynet_fly_api]
---#content ---
---#content [service_watch_interface](https://github.com/huahua132/skynet_fly/blob/master/lualib/skynet-fly/watch/service_watch_interface.lua)

local skynet = require "skynet"

local setmetatable = setmetatable

local M = {}
local mt = {__index = M}
---#desc 普通skynet服务接口
---@param name_or_handle string|number 别名或者handle_id
---@return table obj
function M:new(name_or_handle)
    local t = {
        server = name_or_handle
    }

    setmetatable(t, mt)
    return t
end

function M:send(...)
    skynet.send(self.server, 'lua', ...)
end

function M:call(...)
    return skynet.call(self.server, 'lua', ...)
end

return M