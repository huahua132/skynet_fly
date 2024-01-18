return {
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
		launch_seq = 2,
		launch_num = 1,
	}
}