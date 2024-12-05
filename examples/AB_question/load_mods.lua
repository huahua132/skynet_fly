return {
	A_m = {
		launch_seq = 1,
		launch_num = 1,
	},
    B_m = {
        launch_seq = 2,
		launch_num = 4,

		--自动定时热更 skynet-fly.time_extend.time_point.lua 的配置项
		auto_reload = {
			type = 1,    --每分钟
			sec = 30,    --第30秒
		},

		mod_args = {
			{instance_name = "test_one"},
			{instance_name = "test_one"},
			{instance_name = "test_two"},
			{instance_name = "test_two"},
		}
    }
}