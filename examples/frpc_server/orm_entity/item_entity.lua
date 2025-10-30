local ormtable = require "skynet-fly.db.orm.ormtable"
local ormadapter_mysql = require "skynet-fly.db.ormadapter.ormadapter_mysql"
local skynet = require "skynet"
local log = require "skynet-fly.log"
local assert = assert
local g_orm_obj = nil
local M = {}
local handle = {}

function M.init()
    local adapter = ormadapter_mysql:new("admin")
    g_orm_obj = ormtable:new("examples_item")
    :int64("player_id")
    :int32("item_id")
    :int64("count")
    :set_keys("player_id", "item_id")
    :builder(adapter)

    return g_orm_obj
end

M.handle = handle

return M