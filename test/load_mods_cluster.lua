return {
    	--共享配置
	share_config_m = {
		launch_seq = 1,
		launch_num = 1,
		default_arg = {
			--cluster_server用的配置
			cluster_server = {
				host = "127.0.0.1:9689",
			}
		}
	},

    cluster_client_m = {
		launch_seq = 2,
		launch_num = 1,
		default_arg = {
			node_map = {
				['test'] = {
					[1] = "127.0.0.1:9689",
				}
			}
		}
	},

    cluster_test_m = {
        launch_seq = 3,
		launch_num = 1,
    }
}