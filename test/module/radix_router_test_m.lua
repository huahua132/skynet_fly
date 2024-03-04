local skynet = require "skynet"
local log = require "log"
-- require "benchmark.static-paths"
-- require "benchmark.simple-variable"
require "benchmark.simple-variable-binding"
-- require "benchmark.simple-prefix"
-- require "benchmark.complex-variable"
-- require "benchmark.github-routes"

local CMD = {}

local function test()

end

function CMD.start()
    skynet.fork(test)
    return true
end

function CMD.exit()
    return true
end

return CMD