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
		launch_seq = 1,
		launch_num = 1,
		default_arg = {
			node_map = {
				['frpc_server'] = {
					[1] = {
						svr_id = 1,
						host = "127.0.0.1:9688",
						secret_key = 'sdfdsoifhkjguihre234wedfoih24',
						is_encrypt = true,
					},
					-- [2] = {
					-- 	svr_id = 2,
					-- 	host = "127.0.0.1:9689",
					-- 	secret_key = 'safdsifuhiu34yjfindskj43hqfo32yosd',
					-- 	is_encrypt = true,
					-- }
				}
			}
		}
	},

	test_m = {
		launch_seq = 4,
		launch_num = 1,
	}
}