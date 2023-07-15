return {
	share_config_m = {
		launch_seq = 1,
		launch_num = 1,
		default_arg = {
			--login_service用的配置
			loginconf = {
				--gate连接配置
				gateconf = {
					address = '127.0.0.1',
					port = 8001,
					maxclient = 2048,
				},
				check_plug = "login_check",
			}
		}
	},
	hall_m = {
		launch_seq = 2,
		launch_num = 6,
		default_arg = {
			hall_plug = "hall_plug",
		}
	},
	match_m = {
		launch_seq = 3,
		launch_num = 1,
		default_arg = {
			match_plug = "match_plug",
			MAX_TABLES = 10000,
		}
	},

	room_m = {
		launch_seq = 4,
		launch_num = 6,
	},

	client_m = {
		launch_seq = 5,
		launch_num = 2,
		mod_args = {
			{account = "skynet",password = '123456',player_id = 10000},
			{account = "skynet_fly",password = '123456',player_id = 10001},
		}
	}
}