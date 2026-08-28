--测试 log_service fatal 日志自动强制关服
--切换 SHUTDOWN_MODE 测试不同场景:
--  on      开启 fatal 自动关服, 打 fatal 触发强制关服
--  on_off  开启后又关闭, 打 fatal 不触发
--  off     不开启(默认), 打 fatal 不触发
local SHUTDOWN_MODE = 'on'   --改这里切换测试场景

return {
	test_m = {
		launch_seq = 1,
		launch_num = 1,
		mod_args = {
			[1] = { shutdown_mode = SHUTDOWN_MODE },
		},
	},
}
