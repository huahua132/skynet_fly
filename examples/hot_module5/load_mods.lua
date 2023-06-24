return {
	service_m = {
		launch_seq = 1,
		launch_num = 1,
		mod_args = nil,
		default_arg = {
			player_num = 2,
			min_num = 1,
			max_num = 100,
		}
	},

	agent_m = {
		launch_seq = 2,
		launch_num = 2,
		mod_args = {
			{
				player_id = 10001,
				nickname = "张三",
			},
			{
				player_id = 10004,
				nickname = "李四",
				hello = {a = 1,b = 2}
			},
		}
	}
}