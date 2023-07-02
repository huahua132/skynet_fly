return {
	-- timer_test_m = {
	-- 	launch_seq = 1,
	-- 	launch_num = 1,
	-- },
	redis_m = {
		launch_seq = 2,
		launch_num = 1,
		default_arg = {
			host = "127.0.0.1",
			port = "6379",
			auth = "123456",
			db = 0,
		},
	},
	redis_test_m = {
		launch_seq = 3,
		launch_num = 1,
	},
}