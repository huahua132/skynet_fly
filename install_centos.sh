#!/bin/bash

# 安装编译skynet依赖的一些库
install_dependencies() {
	yum install -y git gcc zlib-devel openssl openssl-devel autoconf automake make libtool curl centos-release-scl devtoolset-9-gcc*

	# centos8以上 dnf -y group install "Development Tools"
}

# 切换gcc
switch_gcc() {
	# scl enable devtoolset-9 bash
	source /opt/rh/devtoolset-9/enable
}

# 安装Perl
install_perl() {
	local perl_version="5.40.0"
	wget "https://www.cpan.org/src/5.0/perl-$perl_version.tar.gz"
	tar -xzf "perl-$perl_version.tar.gz"
	cd "perl-$perl_version" || exit

	./Configure -des -Dprefix=$HOME/localperl
	make
	make test
	make install

	sudo mv /usr/bin/perl /usr/bin/perl.old
	sudo cp -f $HOME/localperl/bin/perl /usr/local/bin/perl
	sudo ln -s /usr/local/bin/perl /usr/bin/perl

	echo "Perl $perl_version has been installed and linked successfully."
	cd ..
}

# 安装OpenSSL
install_openssl() {
	local openssl_version="3.3.2"
	wget "https://github.com/openssl/openssl/releases/download/openssl-$openssl_version/openssl-$openssl_version.tar.gz"
	tar -xzvf "openssl-$openssl_version.tar.gz"
	cd "openssl-$openssl_version" || exit

	./config --prefix=/usr/local/openssl-$openssl_version/openssl --openssldir=/usr/local/openssl-$openssl_version/openssl
	make
	make install

	cd ..
}

# 编译
compile() {
	make linux
}

# 主程序
main() {
	install_dependencies
	switch_gcc
	install_perl
	install_openssl
	compile
}

main
