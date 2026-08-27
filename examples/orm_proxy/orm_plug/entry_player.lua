local ormtable = require "skynet-fly.db.orm.ormtable"
local ormadapter_mysql = require "skynet-fly.db.ormadapter.ormadapter_mysql"

local g_orm_obj = nil
local M = {}
local handle = {}

function M.init()
    local adapter = ormadapter_mysql:new("admin")
    g_orm_obj = ormtable:new("t_player")
    :int64("player_id")
    :string64("nickname")
    :int8("sex")
    :int8("status")
    :set_index("sex_index", "sex")
    :set_keys("player_id")
    :builder(adapter)

    return g_orm_obj
end

-- 供 orm_table_proxy 的 get_all_entry 首次同步拉取对照
function handle.get_all(player_id)
    local list = g_orm_obj:get_all_entry()
    local res = {}
    for i = 1, #list do
        res[i] = list[i]:get_entry_data()
    end
    return res
end

M.handle = handle

return M
