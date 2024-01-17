local skynet = require "skynet"
local log = require "log"
-- require "static-paths"
-- require "rax_static_paths"
-- require "simple-variable"
-- require "rax_simple_variable"
require "simple-variable-binding"
-- require "rax_simple-variable-binding"
-- require "simple-prefix"
-- require "rax_simple-prefix"
-- require "complex-variable"
-- require "rax_complex-variable"
-- require "github-routes"
-- require "rax_github-routes"

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