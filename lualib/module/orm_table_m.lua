local skynet = require "skynet"
local queue = require "skynet.queue"()
local assert = assert

local g_orm_plug = nil
local g_orm_obj = nil
local G_ISCLOSE = false

local CMD = {}

function CMD.start(config)
    assert(config.orm_plug)

    g_orm_plug = require(config.orm_plug)
    assert(g_orm_plug.init, "not init")    --初始化 
    assert(g_orm_plug.call, "not call")    --调用

    skynet.fork(function ()
        g_orm_obj = queue(g_orm_plug.init)
    end)
    return true
end

function CMD.call(func_name,...)
    if G_ISCLOSE then
        return true
    end

    return false, queue(g_orm_plug.call, func_name, ...)
end

function CMD.herald_exit()
    G_ISCLOSE = true

    queue(g_orm_obj.save_change_now,g_orm_obj)
end

function CMD.exit()

    queue(g_orm_obj.save_change_now,g_orm_obj)
    return true
end

function CMD.fix_exit()

end

function CMD.cancel_exit()
    G_ISCLOSE = false
end

function CMD.check_exit()
    return true
end
return CMD