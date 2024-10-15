#!/bin/bash

skynet_fly_path=$1
key=$2
targetpath=$3

lua=""${skynet_fly_path}"/skynet/3rd/lua/lua"
script_path="${skynet_fly_path}/script/lua"

${lua} ${script_path}/encrycode.lua ${skynet_fly_path} ${key} ${targetpath}