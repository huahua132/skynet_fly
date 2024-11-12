#!/bin/bash

# 安装编译skynet依赖的一些库
install_dependencies() {
    apt-get update
	apt-get install -y git gcc autoconf automake make libtool curl libgdbm-dev libdb-dev libgdbm-compat-dev sudo
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
		echo -e "\033[31m Failed to move perl \033[0m"
        exit 1
    }
	fi
	sudo cp -f $HOME/localperl/bin/perl /usr/local/bin/perl && echo "Copied perl successfully" || {
		echo -e "\033[31m Failed to copy perl \033[0m"
		exit 1
	}
	sudo ln -s /usr/local/bin/perl /usr/bin/perl && echo "Created symlink successfully" || {
		echo -e "\033[31m Failed to create symlink \033[0m"
		exit 1
	}

	echo "Perl $perl_version has been installed and linked successfully."
	cd ../../
}

# 编译openssl-3.4.0
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
			echo -e "\033[31m OpenSSL configuration failed \033[0m"
			exit 1
		}

		# 编译
		make -j4 && echo "Make completed successfully" || {
			echo -e "\033[31m Make failed \033[0m"
			exit 1
		}
		echo -e "\033[32m OpenSSL installed successfully! \033[0m"
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
	git submodule update --init
	chmod -R 744 skynet
	(
		make cleanall
		make linux -j4
	)
}

# 还原perl环境
revert_perl() {
	(
		sudo mv /usr/bin/perl.old /usr/bin/perl && echo "revert perl successfully" || {
			echo -e "\033[31m Failed to revert perl \033[0m"
			exit 1
    	}
	)
}

# 主程序
main() {
	install_dependencies
	install_perl
	install_openssl
	install_zlib
	compile
	revert_perl
}

main