#!/bin/bash
#构建配置文件 skynet.config 还有mod_config

skynet_fly_path=$1
svr_name=$2
thread=$3

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

lua=""${skynet_fly_path}"/skynet/3rd/lua/lua"
script_path="${skynet_fly_path}/script/lua"

${lua} ${script_path}/write_config.lua ${skynet_fly_path} ${svr_name} ${thread}
${lua} ${script_path}/write_mod_config.lua ${skynet_fly_path}