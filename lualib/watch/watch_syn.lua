local skynet = require "skynet"
local log = require "log"

local assert = assert
local setmetatable = setmetatable
local pairs = pairs
local coroutine = coroutine
local tinsert = table.insert
local tremove = table.remove

local watch_cmd = "_watch"
local unwatch_cmd = "_unwatch"

local M = {}
local server = {}
local server_mt = {__index = server}

------------------------------------------------------------------------------------------
--server
------------------------------------------------------------------------------------------

function M.new_server(CMD, NOT_RET)
    assert(CMD[watch_cmd], "exists _watch cmd")
    assert(CMD[unwatch_cmd], "exists _unwatch cmd")
    assert(NOT_RET, "not NOT_RET")
    local watch_map = {}         --监听者记录
    local version_map = {}       --版本
    local value_map = {}         --值
    local is_first_map = {}      --监听者是否首次拿值
    local t = {
        watch_map = watch_map,
        value_map = value_map,
        version_map = version_map,
    }

    t._update = function(name, new_v)
        local w_map = assert(watch_map[name], "not exists watch name " .. name)
        value_map[name] = new_v
        version_map[name] = version_map[name] + 1
        local version = version_map[name]

        for src, rsp in pairs(w_map) do
            rsp(true, new_v, version)
            w_map[src] = nil
        end
    end

    CMD[watch_cmd] = function(source, name, old_version)
        local w_map = assert(watch_map[name], "not exists watch name " .. name)
        assert(not w_map[source], "exists watch " .. source)
        local version = version_map[name]
        local is_firsts = is_first_map[name]
        local v = value_map[name]
        if old_version ~= version or not is_firsts[source] then
            is_firsts[source] = true
            return v, version
        end

        w_map[source] = skynet.response()
        return NOT_RET
    end

    CMD[unwatch_cmd] = function(source, name)
        local w_map = assert(watch_map[name], "not exists watch name " .. name)
        local rsp = assert(w_map[source], "not exists watch " .. source)
        local is_firsts = is_first_map[name]
        local version = version_map[name]
        local v = value_map[name]
        rsp(true, v, version)

        is_firsts[source] = nil
        w_map[source] = nil
        return true
    end
    setmetatable(t, server_mt)
    return t
end

--注册
function server:register(name, init_v)
    local watch_map = self.watch_map
    assert(watch_map[name], "repeat register " .. name)  --重复注册
    local version_map = self.version_map
    local value_map = self.value_map
    local is_first_map = self.is_first_map

    watch_map[name] = {}
    is_first_map[name] = {}
    value_map[name] = init_v
    version_map[name] = 1
    return self
end

--发布新值
function server:publish(name, new_value)
    return self._update(name, new_value)
end

------------------------------------------------------------------------------------------
--client
------------------------------------------------------------------------------------------
local client = {}
local client_mt = {__index = client}
function M.new_client(rpc_interface)
    assert(rpc_interface, "not rpc_interface")
    assert(rpc_interface.send, "rpc_interface not send func")
    assert(rpc_interface.call, "rpc_interface not call func")
    local value_map = {}
    local is_watch_map = {}
    local version_map = {}
    local t = {
        value_map = value_map,
        is_watch_map = is_watch_map,
        waits_map = {},
        is_exit = false,
    }

    local self_address = skynet.self()
    t._send = function(cmd, name)
        rpc_interface:send(cmd, self_address, name)
    end

    t._call = function(cmd, name)
        return rpc_interface:call(cmd, self_address, name)
    end
    
    local old_skyent_exit = skynet.exit
    skynet.exit = function()
        t.is_exit = true
        for name,_ in pairs(is_watch_map) do
            t._send(unwatch_cmd, name)
        end
        old_skyent_exit()
    end

    setmetatable(t, client_mt)
    return t
end

--监听
function client:watch(name)
    local is_watch_map = self.is_watch_map
    assert(not is_watch_map[name], "repeat watch name " .. name)
    is_watch_map[name] = true

    local value_map = self.value_map
    local version_map = self.version_map
    local waits_map = self.waits_map
    waits_map[name] = {}

    skynet.fork(function()
        while not self.is_exit and is_watch_map[name] do
            local v, version = self._call(watch_cmd, name, version_map[name])
            value_map[name] = v
            version_map[name] = version

            local waits = waits_map[name]
            for i = #waits, 1, -1 do
                local token = waits[i]
                skynet.wakeup(token)
                tremove(waits, i)
            end
        end
        is_watch_map[name] = nil
    end)

    return true
end

--取消监听
function client:unwatch(name)
    local is_watch_map = self.is_watch_map
    assert(is_watch_map[name], "not watch name " .. name)
    is_watch_map[name] = nil
    self._send(unwatch_cmd, name)
end

--直接获取
function client:get(name)
    assert(self.is_watch_map[name], "not watch name " .. name)
    local value_map = self.value_map
    return value_map[name]
end

--获取(至少第一次结果已经返回)
function client:await_get(name)
    assert(self.is_watch_map[name], "not watch name " .. name)
    local version = self.version_map[name]
    if not version then
        local waits = self.waits_map[name]
        local token = coroutine.running()
        tinsert(waits, token)
        skynet.wait(token)
    end

    local value_map = self.value_map
    return value_map[name]
end

--等待更新
function client:await_update(name)
    assert(self.is_watch_map[name], "not watch name " .. name)
    local waits = self.waits_map[name]
    local token = coroutine.running()
    tinsert(waits, token)
    skynet.wait(token)

    local value_map = self.value_map
    return value_map[name]
end
