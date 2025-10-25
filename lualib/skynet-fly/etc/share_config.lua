local contriner_client = require "skynet-fly.client.contriner_client"

contriner_client:register("share_config_m")

local M = {}

local cache = {}

--share_config_m 热更后清空缓存
contriner_client:add_updated_cb("share_config_m", function()
    cache = {}
end)

function M.get(cfg_name)
    if cache[cfg_name] then
        return cache[cfg_name]
    end
    local cfg = contriner_client:instance("share_config_m"):query(cfg_name)
    cache[cfg_name] = cfg
    return cfg
end

return M