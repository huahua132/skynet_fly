return {
    ormuselog_test_m = {
		launch_seq = 1,
		launch_num = 1,
	},

	logrotate_m = {
        launch_seq = 2,
        launch_num = 1,
        default_arg = {
            rename_format = "%Y%m%d-%H%M%S",
            point_type = 1,
            file_path = './logs/',     --文件路径
            filename = 'server.log',   --文件名
            limit_size = 0,            --最小分割大小
            max_age = 7,               --最大保留天数
            max_backups = 7,           --最大保留文件数
            sys_cmd = [[
                /usr/bin/pkill -HUP -f skynet.make/logrotate_config.lua\n
            ]],              --系统命令
        }
    },
	
}