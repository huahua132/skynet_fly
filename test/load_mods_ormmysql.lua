return {
	share_config_m = {
		launch_seq = 2,
		launch_num = 1,
		default_arg = {
			mysql = {
				admin = {
					host = '127.0.0.1',
					port = '3306',
					max_packet_size = 1048576,
					user = 'root',
					password = '123456',
					database = 'admin',
				}
			}
		}
	},

	mysql_m = {
		launch_seq = 2,
		launch_num = 1,
		default_arg = {
			instance_name = "admin",
			db_conf = {
				host = '127.0.0.1',
				port = '3306',
				max_packet_size = 1048576,
				user = 'root',
				password = '123456',
				database = 'admin',
			},
			is_create = true,  --不存在数据库就创建
		}
	},

    ormmysql_test_m = {
		launch_seq = 3,
		launch_num = 1,
	}
}