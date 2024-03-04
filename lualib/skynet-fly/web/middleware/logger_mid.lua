local skynet = require "skynet"
local log = require "skynet-fly.log"
local math = math
local string = string
local os = os

local function default_log_formatter(param)
    return string.format("[http ACCESS] %s | %3d | %.3f | %15s | %-7s %s",
        os.date("%Y/%m/%d - %H:%M:%S", param.timestamp),
        param.status,
        param.latency,
        param.addr,
        param.method,
        param.path)
end


return function (conf)
    conf = conf or {}
    local formatter = conf.formatter
    if formatter == nil then
        formatter = default_log_formatter
    end

    return function(c)
        -- Start timer
        local start_time = skynet.time()
        local path = c.req.path
        local uri = c.req.origin_uri

        -- Process request
        c:next()

        -- Stop timer
        local stop_time = skynet.time()
        local param = {
            timestamp = math.floor(stop_time),
            latency = stop_time - start_time,
            addr = c.addr,
            method = c.req.method,
            status = c.res.status,
            path = path,
            uri = uri,
        }

        log.info(formatter(param))
    end
end

