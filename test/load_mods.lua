return {
	timer_test_m = {
		launch_seq = 1,
		launch_num = 1,
	},

	share_config_m = {
		launch_seq = 2,
		launch_num = 1,
		default_arg = {
			redis = {
				game = {
					host = '127.0.0.1',
					port = 6379,
					auth = '123456',
					db = 0,
				},
				hall = {
					host = '127.0.0.1',
					port = 16379,
					auth = '123456',
					db = 0,
				},
			},
		}
	},

	redis_test_m = {
		launch_seq = 3,
		launch_num = 1,
	},

	mysql_m = {
		launch_seq = 4,
		launch_num = 4,
		mod_args = {
			{
				instance_name = "game",
				db_conf = {
					host = '127.0.0.1',
					port = '3306',
					max_packet_size = 1048576,
					user = 'root',
					password = '123456',
					database = 'gamedb',
				}
			},
			{
				instance_name = "game",
				db_conf = {
					host = '127.0.0.1',
					port = '3306',
					max_packet_size = 1048576,
					user = 'root',
					password = '123456',
					database = 'gamedb',
				}
			},
			{
				instance_name = "hall",
				db_conf = {
					host = '127.0.0.1',
					port = '3306',
					max_packet_size = 1048576,
					user = 'root',
					password = '123456',
					database = 'halldb',
				}
			},
			{
				instance_name = "hall",
				db_conf = {
					host = '127.0.0.1',
					port = '3306',
					max_packet_size = 1048576,
					user = 'root',
					password = '123456',
					database = 'halldb',
				}
			},
		}
	},

	mysql_test_m = {
		launch_seq = 5,
		launch_num = 1,
	},

	proto_test_m = {
		launch_seq = 6,
		launch_num = 1,
	},
}