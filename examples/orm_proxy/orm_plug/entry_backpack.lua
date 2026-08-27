local ormtable = require "skynet-fly.db.orm.ormtable"
local ormadapter_mysql = require "skynet-fly.db.ormadapter.ormadapter_mysql"

local g_orm_obj = nil
local M = {}
local handle = {}

function M.init()
    local adapter = ormadapter_mysql:new("admin")
    g_orm_obj = ormtable:new("t_backpack")
    :int64("player_id")
    :int64("item_id")
    :int64("slot_id")
    :int32("count")
    :string256("prop")
    :set_keys("player_id", "item_id", "slot_id")
    :builder(adapter)

    return g_orm_obj
end

-- 供 orm_table_proxy 对照
function handle.get_all(player_id)
    local list = g_orm_obj:get_entry(player_id)
    local res = {}
    for i = 1, #list do
        res[i] = list[i]:get_entry_data()
    end
    return res
end

M.handle = handle

return M
