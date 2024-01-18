return {
	share_config_m = {
		launch_seq = 2,
		launch_num = 1,
		default_arg = {
			mongo = {
				admin = {
					host = '127.0.0.1',
					port = 27017,
					username = "admin",
					password = "123456",
					authdb = "admin",
				}
			}
		}
	},

    ormmongo_test_m = {
		launch_seq = 2,
		launch_num = 1,
	}
}