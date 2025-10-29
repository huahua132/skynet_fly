local log = require "skynet-fly.log"
local watch_syn_table = require "skynet-fly.watch.watch_syn_table"
local service = require "skynet.service"
local skynet = require "skynet"

local function watch_syn_table_service()
    local skynet_util = require "skynet-fly.utils.skynet_util"
    local watch_syn_table = require "skynet-fly.watch.watch_syn_table"
    local container_watch_interface = require "skynet-fly.watch.interface.container_watch_interface"
    local container_client = require "skynet-fly.client.container_client"
    local log = require "skynet-fly.log"
    local skynet = require "skynet"

    container_client:register("misc_test_m")

    local CMD = {}


    skynet.start(function()
        skynet_util.lua_dispatch(CMD)
        
        watch_syn_table.watch("test_name", container_watch_interface:new("misc_test_m"))
        skynet.fork(function()
            while true do
                skynet.sleep(300)
                local tab = watch_syn_table.get_table("test_name")
                log.info("tab >>> ", tab)
            end
        end)
    end)
end

local ws = watch_syn_table.new_server("test_name")

local M = {}

function M.start()
    service.new("watch_syn_table_service", watch_syn_table_service)
    local cmd_list = {
        {"set", "a", 3},
        {"set", "b", 4},
        {"set", "c", {1,2,3}},
        {"set", "d", {c = 1}},
        {"del", "e"},
        {"del", "a"},
    }
    local index = 1
    while true do
        skynet.sleep(300)
        local cmd = cmd_list[index]
        local c = cmd[1]
        local k = cmd[2]
        local v = cmd[3]
        if c == "set" then
            ws:set(k, v)
        else
            ws:del(k)
        end
        index = index + 1
        if index > #cmd_list then return end
    end

end

return M