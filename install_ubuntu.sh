#!/bin/bash

# 安装编译skynet依赖的一些库
install_dependencies() {
    apt-get update
	apt-get install -y git gcc autoconf automake make libtool curl libgdbm-dev libdb-dev libgdbm-compat-dev
}

# 安装Perl
install_perl() {
	chmod -R 744 "3rd/perl"
	cd "3rd/perl" || exit
	(
		./Configure -des -Dprefix=$HOME/localperl
		make -j4
		make install
	)
	if [ -f /usr/bin/perl ]; then
    sudo mv /usr/bin/perl /usr/bin/perl.old && echo "Moved perl successfully" || {
        echo "Failed to move perl"
        exit 1
    }
	fi
	sudo cp -f $HOME/localperl/bin/perl /usr/local/bin/perl && echo "Copied perl successfully" || {
		echo "Failed to copy perl"
		exit 1
	}
	sudo ln -s /usr/local/bin/perl /usr/bin/perl && echo "Created symlink successfully" || {
		echo "Failed to create symlink"
		exit 1
	}

	echo "Perl $perl_version has been installed and linked successfully."
	cd ../../
}

# 编译openssl-3.3.2
install_openssl() {
	# 获取脚本当前目录
	CURRENT_DIR="$(dirname "$BASH_SOURCE")"
	ABSOLUTE_PATH="$(realpath "$CURRENT_DIR/3rd/openssl")"
	chmod -R 744 "3rd/openssl"
	cd "3rd/openssl" || exit
	(
		rm -f *.a
		echo "ABSOLUTE_PATH:$ABSOLUTE_PATH"
		
		# 配置 OpenSSL
		./config --prefix="$ABSOLUTE_PATH" -fPIC no-shared && echo "OpenSSL configured successfully" || {
			echo "OpenSSL configuration failed"
			exit 1
		}

		# 编译
		make -j4 && echo "Make completed successfully" || {
			echo "Make failed"
			exit 1
		}
		echo "OpenSSL installed successfully!"
	)
	cd ../../
}

# 编译zlib-1.3.1
install_zlib() {
	chmod -R 744 "3rd/zlib"
	cd "3rd/zlib" || exit
	(
		rm -f *.o libz.*
		./configure
		make -j4
	)
	cd ../../
}

# 编译
compile() {
	chmod -R 744 skynet
	(
		make cleanall
		make linux -j4
	)
}

# 主程序
main() {
	install_dependencies
	install_perl
	install_openssl
	install_zlib
	compile
}

main