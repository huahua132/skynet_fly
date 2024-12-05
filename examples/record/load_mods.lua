return {
    --共享配置
	share_config_m = {
		launch_seq = 1,
		launch_num = 1,
		default_arg = {
			server_cfg = {
                recordlimit = 1024 * 1024,
			},

            redis = {
                test = {
                    host = '127.0.0.1',
                    port = 6379,
                    auth = '123456',
                    db = 0,
                }
            }
		},
	},
    A_m = {
        launch_seq = 2,
        launch_num = 1,
    },
    B_m = {
        launch_seq = 3,
        launch_num = 1,
        is_record_on = 1, --录像

        --自动定时热更 skynet-fly.time_extend.time_point.lua 的配置项
		auto_reload = {
			type = 1,    --每分钟
			sec = 30,    --第30秒
		},

		--录像文件自动整理
		--需要启动logrotate_m
		record_backup = {
			max_age = 3,    --最大保留天数
			max_backups = 8,--最大保留文件数
			point_type = 1, --每分钟整理一次
			sec = 20,       --第20秒整理	
		},
    },
    logrotate_m = {
		launch_seq = 4,
		launch_num = 1,
	}
}