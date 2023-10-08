return {
	--共享配置
	share_config_m = {
		launch_seq = 1,
		launch_num = 1,
		default_arg = {
			--room_game_login用的配置
			room_game_login = {
				gateservice = "gate", --gate 或者 ws_gate
				--gate连接配置
				gateconf = {
					address = '127.0.0.1',
					port = 8001,
					maxclient = 2048,
				},
				login_plug = "login_check_pb",
			}
		}
	},

	--大厅服
	room_game_hall_m = {
		launch_seq = 2,
		launch_num = 6,
		default_arg = {
			hall_plug = "hall_plug_pb",
		}
	},

	--桌子分配服
	room_game_alloc_m = {
		launch_seq = 3,
		launch_num = 1,
		default_arg = {
			match_plug = "alloc_plug_pb",
			MAX_TABLES = 10000,
		}
	},

	--桌子服
	room_game_table_m = {
		launch_seq = 4,
		launch_num = 6,
		default_arg = {
			instance_name = "default",
			table_plug = "table_plug_pb",
			table_conf = {
				player_num = 2,
			}
		}
	},

	--测试客户端
	client_m = {
		launch_seq = 5,
		launch_num = 2,
		mod_args = {
			{account = "skynet",password = '123456',player_id = 10000,net_util = "pbnet_util",protocol = "socket"},
			{account = "skynet_fly",password = '123456',player_id = 10001,net_util = "pbnet_util",protocol = "socket"},
		}
	}
}