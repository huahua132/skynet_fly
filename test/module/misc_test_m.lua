local skynet = require "skynet"
local misc = require "misc_test.misc"

local CMD = {}

function CMD.start()
    skynet.fork(function()
        for _, m in ipairs(misc) do
            if m.start then
                skynet.fork(m.start)
            end
        end
    end)
    return true
end

function CMD.exit()
    return true
end

return CMD