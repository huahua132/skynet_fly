#!/bin/bash
#构建服务设施 skynet.config 还有mod_config run.sh

skynet_fly_path=$1
svr_name=$2
thread=$3

if (($# != 3)); then
	echo "缺少参数 请输入3个参数 skynet_fly_path svr_name thread"
	exit
fi

if [[ -z ${skynet_fly_path} ]]; then
	echo "缺少 skynet_fly_path"
	exit
fi

if [[ -z ${svr_name} ]]; then
	echo "缺少 svr_name"
	exit
fi

if [[ -z ${thread} ]]; then
	echo "缺少 thread"
	exit
fi

shell_path="${skynet_fly_path}/script/shell"

sh ${shell_path}/make_server.sh ${skynet_fly_path} ${svr_name} ${thread}