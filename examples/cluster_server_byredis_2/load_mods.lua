return {
	--共享配置
	share_config_m = {
		launch_seq = 1,
		launch_num = 1,
		default_arg = {
			--cluster_server用的配置
			cluster_server = {
				host = "127.0.0.1:9689",
				register = "redis",        --连接信息注册到redis
			},

			redis = {
				--rpc连接配置
				rpc = {
					host = '127.0.0.1',
					port = 6379,
					auth = '123456',
					db = 0,
				},
			},
		}
	},

	test_m = {
		launch_seq = 2,
		launch_num = 6,
		mod_args = {
			{instance_name = "test_one"},
			{instance_name = "test_one"},
			{instance_name = "test_one"},
			{instance_name = "test_two"},
			{instance_name = "test_two"},
			{instance_name = "test_two"},
		}
	}
}