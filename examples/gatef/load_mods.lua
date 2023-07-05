return {
	gate_m = {
		launch_seq = 1,
		launch_num = 1,
		default_arg = {
			address = '127.0.0.1',
			port = 8001,
			maxclient = 2048,
			login = "login",
		}
	},

	client_m = {
		launch_seq = 2,
		launch_num = 1,
		mod_args = {
			{player_id = 10001,nickname = "skynet_fly",account = "skynet_fly", password = "123456"},
		}
	},
}