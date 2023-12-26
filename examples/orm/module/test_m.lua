local log = require "log"
local skynet = require "skynet"
local orm_table_client = require "orm_table_client"

local CMD = {}

local function test()
    orm_table_client:instance("player"):not_exist_create({player_id = 10001})

    local client = orm_table_client:new("player")
    while true do
        client:get(10001)
        skynet.sleep(100)
    end
end

function CMD.start()
    skynet.fork(test)
    return true
end

function CMD.exit()
    return true
end

return CMD