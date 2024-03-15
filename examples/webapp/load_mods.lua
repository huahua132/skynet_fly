return {
	share_config_m = {
		launch_seq = 1,
		launch_num = 1,
		default_arg = {
			server_cfg = {
				thread = 8,
				debug_port = 9001,
			}
		}
	},

	web_agent_m = {
		launch_seq = 2,
		launch_num = 6,
		default_arg = {
			protocol = 'http',
			dispatch = 'apps.webapp_dispatch',
			keep_alive_time = 300,         --最长保活时间
			second_req_limit = 2000,       --1秒内请求数量限制
		}
	},

	web_master_m = {
		launch_seq = 3,
		launch_num = 1,
		default_arg = {
			protocol = 'http',
			port = 80,         --端口
			max_client = 30000, --最大连接数
			second_conn_limit = 30000, --相同ip 1秒内建立连接数限制
			keep_live_limit = 30000,  --相同ip 保持活跃数量限制
		}
	}
}