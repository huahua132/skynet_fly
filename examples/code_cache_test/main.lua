local skynet = require "skynet.manager"
local env_util = require "skynet-fly.utils.env_util"
local log = require "skynet-fly.log"

skynet.start(function()
	env_util.add_pre_load("./preload.lua")                --增加服务main.lua加载之前调用

	local cache_pre_time = skynet.time()
	for i = 1,10000 do
		skynet.newservice('cachetest')
	end
	local cache_over_time = skynet.time()
	--cache 11 s

	local nocache_pre_time = skynet.time()
	for i = 1,10000 do
		skynet.newservice('ncachetest')
	end
	local nocache_over_time = skynet.time()

	log.info("cachetest use time:",cache_over_time - cache_pre_time)
	log.info("ncachetest use time:",nocache_over_time - nocache_pre_time)

	--no cache 33 s

	--关闭code cache 启动服务性能下降200% 下降比例会随着加载代码量增加而增加
	--但是skynet_fly 并不推崇启动成千上万的服务数量
end)