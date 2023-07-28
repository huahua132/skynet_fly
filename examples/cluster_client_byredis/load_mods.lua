return {
	share_config_m = {
		launch_seq = 1,
		launch_num = 1,
		default_arg = {
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

	cluster_client_m = {
		launch_seq = 2,
		launch_num = 1,
		default_arg = {
			node_map = {
				['cluster_server_byredis'] = true,   --连接cluster_server_byredis服务
			},
			watch = 'redis',  --监听redis的方式做服务发现
		}
	},

	test_m = {
		launch_seq = 3,
		launch_num = 1,
	}
}