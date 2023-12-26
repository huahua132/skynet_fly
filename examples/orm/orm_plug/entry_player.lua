local ormtable = require "ormtable"
local ormadapter_mysql = require "ormadapter_mysql"
local skynet = require "skynet"
local log = require "log"
local assert = assert
local g_orm_obj = nil
local M = {}
local handle = {}

function M.init()
    local adapter = ormadapter_mysql:new("admin")
    g_orm_obj = ormtable:new("t_player")
    :int64("player_id")
    :int64("nickname")
    :int8("sex")
    :int8("status")
    :set_keys("player_id")
    :builder(adapter)

    return g_orm_obj
end

function M.call(func_name, ...)
    log.info("call:",func_name, skynet.self())
    return handle[func_name](...)
end

-- 不存在就创建
function handle.not_exist_create(entry_data)
    local player_id = assert(entry_data.player_id)
    local entry_list = g_orm_obj:get_entry(player_id)
    if #entry_list > 0 then
        return
    end

    entry_list = g_orm_obj:create_entry(entry_data)
    local entry = entry_list[1]
    if not entry then return end

    return entry:get_entry_data()
end

-- 获取玩家信息
function handle.get(player_id)
    local entry_list = g_orm_obj:get_entry(player_id)
    if #entry_list <= 0 then return end

    local entry = entry_list[1]
    return entry:get_entry_data()
end

-- 修改状态
function handle.change_status(player_id, status)
    local entry_list = g_orm_obj:get_entry(player_id)
    if #entry_list <= 0 then return end
    local entry = entry_list[1]
    local status = entry:get("status")
    if status ~= 0 then
        return false
    end

    entry:set("status", status)
    local res_list = g_orm_obj:save_entry(entry)
    return res_list[1]
end

return M