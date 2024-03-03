#!/bin/bash.sh
#安装编译skynet依赖的一些库

yum install -y git gcc zlib-devel openssl openssl-devel autoconf automake make libtool curl centos-release-scl devtoolset-9-gcc*

# 切换gcc
scl enable devtoolset-9 bash