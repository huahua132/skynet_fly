local skynet = require "skynet.manager"
local orm_table_client = require "skynet-fly.client.orm_table_client"
local container_client = require "skynet-fly.client.container_client"
local skynet_util = require "skynet-fly.utils.skynet_util"
local log = require "skynet-fly.log"

local next = next
--跨服访问orm的agent

local name = ...
local cli = orm_table_client:new(name)

local CMD = {}

function CMD.watch_first_syn(main_key)
    local key_list = container_client:instance("orm_table_m", name):mod_call_by_name("get_key_list")
    local data = cli:get_entry(main_key)
    return key_list, data
end

function CMD.call_orm(cmd, ...)
    return cli[cmd](cli, ...)
end

skynet.start(function()
    skynet.register("._ormagent_" .. name)
    skynet_util.lua_dispatch(CMD)
end)