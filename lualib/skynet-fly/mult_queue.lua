---#API
---#content ---
---#content title: 并发，单发互斥的队列
---#content date: 2024-06-29 22:00:00
---#content categories: ["skynet_fly API 文档","执行队列"]
---#content category_bar: true
---#content tags: [skynet_fly_api]
---#content ---
---#content [mult_queue](https://github.com/huahua132/skynet_fly/blob/master/lualib/skynet-fly/mult_queue.lua)

---#content这是一个并发，单发互斥的队列
---#content并发: key不同不用排队，key相同排队执行，不同key不用排队，有单发执行中，需等待
---#content单发: 单发顺序执行需要排队，有并发执行中，需等待

local skynet = require "skynet"
local queue = require "skynet.queue"

local coroutine = coroutine
local setmetatable = setmetatable
local tinsert = table.insert
local tpack = table.pack
local tunpack = table.unpack
local tremove = table.remove
local assert = assert
local x_pcall = x_pcall

local MULTI_TYPE  = 1        -- 并发类型
local UNIQUE_TYPE = 2        -- 单发类型

local M = {}
local meta = {__index = M}

local function wakeup(waits)
    local wake_type = nil
    while #waits > 0 do
        local co_info = waits[1]
        if not wake_type then
            wake_type = co_info.type
        else
            if wake_type ~= co_info.type then   -- 只唤醒相同类型
                break
            end
        end
        skynet.wakeup(co_info.co)
        tremove(waits, 1)
    end
end

---#desc 新建队列对象
---@return table
function M:new()
    local t = {
        unique_queue = queue(),
        queue_map = {},
        que_len_map = {},
        waits = {},
        multi_len = 0,
        unique_len = 0,
        is_lock = false,
        wakeup_co = {},

        doing_co = {},
    }

    setmetatable(t, meta)
    return t
end

---#desc 调用并发执行
---@param key any 不同key可以并发，相同key串行
---@param func function 调用函数
---@param ... any 函数参数
---@return ... 函数返回值
function M:multi(key, func, ...)
    local co = coroutine.running()
    assert(not self.doing_co[co], "can`t loop call")   --不能嵌套调用
    if not self.is_lock then
        local queue = self.queue_map[key] or queue()
        if not self.que_len_map[key] then
            self.que_len_map[key] = 0
        end
        self.queue_map[key] = queue

        self.multi_len = self.multi_len + 1
        self.doing_co[co] = true
        self.que_len_map[key] = self.que_len_map[key] + 1
        local ret = tpack(x_pcall(queue, func, ...))
        self.doing_co[co] = nil
        self.que_len_map[key] = self.que_len_map[key] - 1
        self.multi_len = self.multi_len - 1

        assert(self.multi_len >= 0)
        if self.multi_len == 0 then
            wakeup(self.waits)
        end

        if self.que_len_map[key] == 0 then
            self.que_len_map[key] = nil
            self.queue_map[key] = nil
        end

        local isok, err = ret[1],ret[2]
        assert(isok, err)
        return tunpack(ret, 2, ret.n)
    else
        tinsert(self.waits, {
            type = MULTI_TYPE,
            co = co,
        })
        skynet.wait(co)
        return self:multi(key, func, ...)
    end
end

---#desc 调用单发执行，执行单发时，并发都暂时等待
---@param func function 调用函数
---@param ... any 函数参数
---@return ... 函数返回值
function M:unique(func, ...)
    -- 直接锁住
    self.is_lock = true
    local co = coroutine.running()
    local is_wakeup = self.wakeup_co[co]
    self.wakeup_co[co] = nil
    assert(not self.doing_co[co], "can`t loop call")                          -- 不能嵌套调用
    if not is_wakeup and (self.multi_len > 0 or #self.waits > 0) then         -- 有multi在执行 或者 waits 先等待，如果是唤醒的除外
        tinsert(self.waits, {
            type = UNIQUE_TYPE,
            co = co
        })
        skynet.wait(co)
        self.wakeup_co[co] = true
        return self:unique(func, ...)
    else
        self.doing_co[co] = true
        self.unique_len = self.unique_len + 1
        local ret = tpack(x_pcall(self.unique_queue, func, ...))
        self.doing_co[co] = nil
        self.unique_len = self.unique_len - 1
        assert(self.unique_len >= 0)
        if self.unique_len == 0 then
            self.is_lock = false
            wakeup(self.waits)
        end
        local isok, err = ret[1], ret[2]
        assert(isok, err)
        return tunpack(ret, 2, ret.n)
    end
end

return M