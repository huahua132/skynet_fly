return {
    --共享配置
	share_config_m = {
		launch_seq = 1,
		launch_num = 1,
		default_arg = {
			server_cfg = {
				recordfile = "./records/00000010.record"        --指定播放录像文件
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
    }
}