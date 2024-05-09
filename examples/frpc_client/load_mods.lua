return {
	--共享配置
	share_config_m = {
		launch_seq = 1,
		launch_num = 1,
		default_arg = {
			server_cfg = {
				svr_id = 1,
				debug_port = 9000,
			}
		},
	},


	frpc_client_m = {
		launch_seq = 2,
		launch_num = 1,
		default_arg = {
			node_map = {
				['frpc_server'] = {
					[1] = "127.0.0.1:9688",
				}
			}
		}
	},

	test_m = {
		launch_seq = 4,
		launch_num = 1,
	}
}