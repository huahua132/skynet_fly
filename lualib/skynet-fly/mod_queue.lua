---#API
---#content ---
---#content title: mod映射队列
---#content date: 2024-06-29 22:00:00
---#content categories: ["skynet_fly API 文档","执行队列"]
---#content category_bar: true
---#content tags: [skynet_fly_api]
---#content ---
---#content [mod_queue](https://github.com/huahua132/skynet_fly/blob/master/lualib/skynet-fly/mod_queue.lua)
local queue = require "skynet.queue"

local setmetatable = setmetatable
local assert = assert

local M = {}
local mata = {__index = M}

---#desc 新建队列对象
---@param cap number 容量
---@return table
function M:new(cap)
    assert(cap > 0)
    local t = {
        cap = cap,
        queue_list = {}
    }

    for i = 1, cap do
        t.queue_list[i] = queue()
    end

    setmetatable(t, mata)
    return t
end

---#desc 执行函数
---@param mod_num number mod_num % cap + 1 决定使用队列
---@param func function 执行函数
---@param ... any 函数参数
---@return ... 函数返回值
function M:exec(mod_num, func, ...)
    local index = mod_num % self.cap + 1
    local queue = self.queue_list[index]
    return queue(func, ...)
end

return M