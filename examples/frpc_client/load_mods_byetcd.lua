return {
	share_config_m = {
		launch_seq = 1,
		launch_num = 1,
		default_arg = {
			server_cfg = {
				--trace = 1,
				svr_type = 2,
				svr_id = 1,
				debug_port = 9000,
				logpath = './logs/',
			},

			etcd = {
				--rpc连接配置
				rpc = {
					http_host = {
					"http://127.0.0.1:2379",   --etcd1
					"http://127.0.0.1:2384",   --etcd3
				},
					--user = "root",        --可选鉴权
					--password = "123456",
					prefix = "skynet_fly:rpc",   --key前缀
					ttl = 10,                   --lease存活秒数
					poll_time = 100,            --watch轮询间隔(skynet tick，100=1秒)
				},
			},
		}
	},

	frpc_client_m = {
		launch_seq = 2,
		launch_num = 1,
		default_arg = {
			node_map = {
				['frpc_s'] = true,        --连接frpc_server服务
				['frpc_server'] = true,   --连接frpc_server服务
			},
			watch = 'etcd',  --监听etcd的方式做服务发现
		}
	},

	test_m = {
		launch_seq = 3,
		launch_num = 1,
	}
}