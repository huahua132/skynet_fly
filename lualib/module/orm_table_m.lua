local skynet = require "skynet"
local queue = require "skynet.queue"()
local assert = assert
local pairs = pairs
local type = type

local g_orm_plug = nil
local g_orm_obj = nil
local G_ISCLOSE = false

local g_handle = {}

--------------------常用handle定义------------------
--批量创建
function g_handle.batch_create(...)
    local entry_list = g_orm_obj:create_entry(...)
    local data_list = {}
    for i = 1,#entry_list do
        local entry = entry_list[i]
        data_list[i] = entry:get_entry_data()
    end
    return data_list
end

--创建单个
function g_handle.create_one(entry_data)
    
end

local CMD = {}

function CMD.start(config)
    assert(config.orm_plug)

    g_orm_plug = require(config.orm_plug)
    assert(g_orm_plug.init, "not init")        --初始化 
    assert(g_orm_plug.handle, "not handle")    --自定义处理函数

    for k,func in pairs(g_orm_plug.handle) do
        assert(type(func) == 'function', "handle k not is function:" .. k)
        assert(g_handle[k], "handle k is exists function:" .. k)
        g_handle[k] = func
    end

    skynet.fork(function ()
        g_orm_obj = queue(g_orm_plug.init)
    end)
    return true
end

function CMD.call(func_name,...)
    if G_ISCLOSE then
        return true
    end

    local func = assert(g_handle[func_name], "func_name not exists:" .. func_name)

    return false, queue(func, ...)
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