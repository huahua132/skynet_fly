return {
	web_agent_m = {
		launch_seq = 1,
		launch_num = 6,
		default_arg = {
			protocol = 'http',
			dispatch = 'webapp_dispatch',
		}
	},

	web_master_m = {
		launch_seq = 2,
		launch_num = 1,
		default_arg = {
			protocol = 'http',
			port = 80,
		}
	}
}