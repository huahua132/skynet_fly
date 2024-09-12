local skynet = require "skynet"
local skynet_util = require "skynet-fly.utils.skynet_util"
local log = require "skynet-fly.log"
local contriner_interface = require "skynet-fly.contriner.contriner_interface"
local SYSCMD = require "skynet-fly.enum.SYSCMD"
local SERVER_STATE_TYPE = require "skynet-fly.enum.SERVER_STATE_TYPE"

local assert = assert
local setmetatable = setmetatable
local pairs = pairs
local coroutine = coroutine
local tinsert = table.insert
local tremove = table.remove

local watch_cmd = SYSCMD.watch_cmd
local unwatch_cmd = SYSCMD.unwatch_cmd

local M = {}

M.EVENT_TYPE = {
    update = 1,  --更新
    move   = 2,  --请转移访问
    unwatch = 3, --取消监听
}

local EVENT_TYPE = M.EVENT_TYPE

local server = {}
local server_mt = {__index = server}

------------------------------------------------------------------------------------------
--server
------------------------------------------------------------------------------------------

function M.new_server(CMD)
    assert(not skynet_util.is_hot_container_server() or contriner_interface.get_server_state() == SERVER_STATE_TYPE.loading, "not loading can`t new")
    assert(not CMD[watch_cmd], "exists _watch cmd")
    assert(not CMD[unwatch_cmd], "exists _unwatch cmd")
    local watch_map = {}         --监听者记录
    local version_map = {}       --版本
    local value_map = {}         --值
    local is_first_map = {}      --监听者是否首次拿值
    local is_exit = false
    
    local t = {
        watch_map = watch_map,
        value_map = value_map,
        version_map = version_map,
        is_first_map = is_first_map,
    }

    t._event = function(name, new_v, event_type)
        local w_map = assert(watch_map[name], "not exists watch name " .. name)
        value_map[name] = new_v
        version_map[name] = version_map[name] + 1
        local version = version_map[name]
        for src, rsp in pairs(w_map) do
            rsp(true, new_v, version, event_type)
            w_map[src] = nil
        end
    end

    CMD[watch_cmd] = function(source, name, old_version)
        local w_map = assert(watch_map[name], "not exists watch name " .. name)
        assert(not w_map[source], "exists watch " .. skynet.address(source))
        local version = version_map[name]
        local is_firsts = is_first_map[name]
        local v = value_map[name]
        if is_exit then
            return v, version, EVENT_TYPE.move
        end
        if old_version ~= version or not is_firsts[source] then
            is_firsts[source] = true
            return v, version, EVENT_TYPE.update
        end

        w_map[source] = skynet.response()
        return skynet_util.NOT_RET
    end

    CMD[unwatch_cmd] = function(source, name)
        local w_map = assert(watch_map[name], "not exists watch name " .. name)
        local rsp = w_map[source]
        local is_firsts = is_first_map[name]
        local version = version_map[name]
        local v = value_map[name]
        is_firsts[source] = nil
        w_map[source] = nil
        if rsp then
            rsp(true, v, version, EVENT_TYPE.unwatch)
        end

        return true
    end

    local old_fix_exit = CMD['fix_exit']
    CMD['fix_exit'] = function()
        is_exit = true
        for name,_ in pairs(watch_map) do
            t._event(name, value_map[name], EVENT_TYPE.move)
        end
        if old_fix_exit then
            old_fix_exit()
        end
    end

    local old_cancel_exit = CMD['cancel_exit']
    CMD['cancel_exit'] = function()
        is_exit = false
        if old_cancel_exit then
            old_cancel_exit()
        end
    end

    setmetatable(t, server_mt)
    return t
end

--注册
function server:register(name, init_v)
    local watch_map = self.watch_map
    assert(not watch_map[name], "repeat register " .. name)  --重复注册
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
    return self._event(name, new_value, EVENT_TYPE.update)
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
    local waits_map = {}
    local t = {
        value_map = value_map,
        is_watch_map = is_watch_map,
        version_map = version_map,
        waits_map = waits_map,
        is_exit = false,
    }

    local self_address = skynet.self()
    t._send = function(cmd, ...)
        rpc_interface:send(cmd, self_address, ...)
    end

    t._call = function(cmd, ...)
        return rpc_interface:call(cmd, self_address, ...)
    end

    t._add_wait = function(name)
        local waits = waits_map[name]
        local token = coroutine.running()
        tinsert(waits, token)
        skynet.wait(token)
    end

    t._wakeup = function(name)
        local waits = waits_map[name]
        for i = #waits, 1, -1 do
            local token = waits[i]
            tremove(waits, i)
            skynet.wakeup(token)
        end
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
        local not_update_cnt = 0
        while not self.is_exit and is_watch_map[name] do
            local v, version, event_type = self._call(watch_cmd, name, version_map[name])
            value_map[name] = v
            version_map[name] = version
            if event_type == EVENT_TYPE.move then
                local state = contriner_interface.get_server_state()
                if state == SERVER_STATE_TYPE.fix_exited or state == SERVER_STATE_TYPE.exited then  --说明是旧服务，就不用同步了
                    break
                end
                skynet.sleep(10)                    --避免move中发给旧服务的请求过多
                not_update_cnt = not_update_cnt + 1
                if not_update_cnt % 100 == 0 then
                    --正常不会有这么多次，出现这种情况，肯定是有bug流量没切过去
                    log.warn("watch move times abnormal ", name, not_update_cnt)
                elseif not_update_cnt > 1000 then
                    --避免出现这种情况导致死循环
                    log.error("watch move times fatal ", not_update_cnt)
                    break
                end
            else
                not_update_cnt = 0
                self._wakeup(name)
            end
        end
        is_watch_map[name] = nil
        self._wakeup(name)
    end)

    return true
end

--是否监听
function client:is_watch(name)
    return self.is_watch_map[name]
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
        self._add_wait(name)
    end

    local value_map = self.value_map
    return value_map[name]
end

--等待更新
function client:await_update(name)
    assert(self.is_watch_map[name], "not watch name " .. name)
    self._add_wait(name)
    local value_map = self.value_map
    return value_map[name]
end

return M