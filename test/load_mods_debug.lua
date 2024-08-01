return {
	 --共享配置
	share_config_m = {
		launch_seq = 1,
		launch_num = 1,
		default_arg = {
			server_cfg = {
				breakpoint_debug_module_name = "debug_test_m",
				breakpoint_debug_module_index = 2,
				breakpoint_debug_host = "127.0.0.1",
				breakpoint_debug_port = 8818,
			}
		},
	},

    debug_test_m = {
		launch_seq = 1,
		launch_num = 2,
	}
}