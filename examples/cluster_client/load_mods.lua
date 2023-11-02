return {
	share_config_m = {
		launch_seq = 1,
		launch_num = 1,
	},

	cluster_client_m = {
		launch_seq = 2,
		launch_num = 1,
		default_arg = {
			node_map = {
				['cluster_server'] = {
					[1] = "127.0.0.1:9688",
					[2] = "127.0.0.1:9689",
				}
			}
		}
	},

	debug_console_m = {
		launch_seq = 3,
		launch_num = 1,
	},

	test_m = {
		launch_seq = 4,
		launch_num = 1,
	}
}