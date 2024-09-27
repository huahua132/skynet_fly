#!/bin/bash

# 定义目标路径
targetpath=./skynet-fly-release

# 删除已有目标路径并新建目录
rm -rf ${targetpath}
mkdir -p ${targetpath}/skynet/3rd

# 复制 skynet_fly 相关文件和目录

# 复制 lua 相关的文件和目录
[ -d "binshell" ] && cp -r binshell ${targetpath}/binshell
[ -d "lualib" ] && cp -r lualib ${targetpath}/lualib
[ -d "module" ] && cp -r module ${targetpath}/module
[ -d "service" ] && cp -r service ${targetpath}/service
[ -d "script" ] && cp -r script ${targetpath}/script

# 复制 c 相关的文件和目录
[ -d "luaclib" ] && cp -r luaclib ${targetpath}/luaclib

# 复制 skynet 相关文件和目录

# 复制 lua 相关的文件和目录
mkdir -p ${targetpath}/skynet # 确保 skynet 目录存在
[ -d "skynet/lualib" ] && cp -r skynet/lualib ${targetpath}/skynet/lualib
[ -d "skynet/service" ] && cp -r skynet/service ${targetpath}/skynet/service

# 复制 c 相关的文件和目录
[ -f "skynet/skynet" ] && cp skynet/skynet ${targetpath}/skynet/skynet
[ -d "skynet/luaclib" ] && cp -r skynet/luaclib ${targetpath}/skynet/luaclib
[ -d "skynet/3rd/lua" ] && cp -r skynet/3rd/lua ${targetpath}/skynet/3rd/lua
[ -d "skynet/cservice" ] && cp -r skynet/cservice ${targetpath}/skynet/cservice