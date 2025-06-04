local object_pool = require "skynet-fly.pool.object_pool"
local log = require "skynet-fly.log"

local M = {}

local function table_creator(name)
    return {name = name}
end

local function function_creator(name)
    return function()
        return name
    end
end

function M.start()
    local table_pool = object_pool:new(table_creator)
    local func_pool = object_pool:new(function_creator)

    local tlist = {}
    local flist = {}
    for i = 1, 10 do
        local tobj = table_pool:get()
        local fobj = func_pool:get()
        table.insert(tlist, tobj)
        table.insert(flist, fobj)
    end

    for i = 10, 1, -1 do
        local tobj = table.remove(tlist)
        local fobj = table.remove(flist)
        table_pool:release(tobj)
        func_pool:release(fobj)
    end

    log.info("table_pool:", table_pool)
    log.info("func_pool:", func_pool)

    collectgarbage("collect")
    collectgarbage("collect")
    log.info("gc over table_pool:", table_pool)
    log.info("gc over func_pool:", func_pool)
end

return M