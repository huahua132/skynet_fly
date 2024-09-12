#!/bin/bash
#构建服务设施 skynet.config 还有load_mods run.sh

skynet_fly_path=$1
load_mods_name="$2"

if [[ -z ${skynet_fly_path} ]]; then
	echo "缺少 skynet_fly_path"
	exit
fi

lua=""${skynet_fly_path}"/skynet/3rd/lua/lua"
script_path="${skynet_fly_path}/script/lua"

${lua} ${script_path}/write_config.lua ${skynet_fly_path} ${load_mods_name}
${lua} ${script_path}/write_runsh.lua ${skynet_fly_path}
${lua} ${script_path}/write_reloadsh.lua ${skynet_fly_path}
${lua} ${script_path}/write_check_reloadsh.lua ${skynet_fly_path}
${lua} ${script_path}/write_killmodsh.lua ${skynet_fly_path}
${lua} ${script_path}/write_stopsh.lua ${skynet_fly_path}
${lua} ${script_path}/write_restartsh.lua ${skynet_fly_path}
${lua} ${script_path}/write_try_again_reloadsh.lua ${skynet_fly_path}
${lua} ${script_path}/write_fasttimesh.lua ${skynet_fly_path}
${lua} ${script_path}/write_hotfixsh.lua ${skynet_fly_path}
${lua} ${script_path}/write_check_hotfixsh.lua ${skynet_fly_path}
${lua} ${script_path}/write_upsharedatash.lua ${skynet_fly_path}