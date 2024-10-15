#!/bin/bash
#lua代码加密

skynet_fly_path=$1
key=$2
targetpath=$3

if [ "$#" -lt 2 ]; then
    echo "请输入2个参数 skynet_fly_path and key"
    exit 1
fi

shell_path="${skynet_fly_path}/script/shell"

bash ${shell_path}/make_encrycode.sh ${skynet_fly_path} ${key} ${targetpath}