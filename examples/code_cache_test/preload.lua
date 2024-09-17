local skynet = require "skynet"

if SERVICE_NAME == "cachetest" then
    skynet.cache.mode "ON"                --启用代码缓存
end