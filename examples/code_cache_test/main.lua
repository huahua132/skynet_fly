local skynet = require "skynet"
require "skynet.manager"
skynet.start(function()
	-- local cur_time = skynet.time()
	-- for i = 1,10000 do
	-- 	skynet.newservice('hot_container_2','test_m')
	-- end
	-- skynet.error("use time:",skynet.time() - cur_time)
	-- not cache 3.69 s

	local cur_time = skynet.time()
	for i = 1,10000 do
		skynet.newservice('test')
	end
	skynet.error("use time:",skynet.time() - cur_time)

	--cache 2.65 s

	--关闭code cache 启动服务性能下降28%
end)