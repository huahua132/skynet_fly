local skynet = require "skynet"
local timer = require "skynet-fly.timer"
local socket = require "skynet.socket"
local container_client = require "skynet-fly.client.container_client"
container_client:register("B_m")

local CMD = {}

function CMD.start()
    timer:new(timer.second, timer.loop, function()
        container_client:instance("B_m"):mod_call("ping")
    end)

    skynet.fork(function()
        skynet.sleep(200)
        local fd = socket.open('127.0.0.1', 8001)
        for i = 1, 10 do
            socket.write(fd, string.format("%d hello skynet-fly\n", i))
        end
    
        skynet.sleep(100)
        socket.close(fd)
    end)
   
    return true
end

function CMD.exit()
    return true
end

function CMD.ping()
    return "pong"
end

return CMD