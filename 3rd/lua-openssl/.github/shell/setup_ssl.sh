#!/bin/bash

if [ -z "$SSL" ]; then
        echo '$SSL not set, use default openssl' >&2
        exit 0
fi

case "$SSL" in
openssl-*)
	# Remove prefix and suffix
	version="${SSL#openssl-}"
	version="${version%.tar.gz}"
	case "$version" in
		0.9.*|1.0.0*|1.0.1*|1.0.2*|1.1.1*)
			converted="${version//./_}"
			SSLURL=https://github.com/openssl/openssl/releases/download/OpenSSL_$converted/$SSL.tar.gz
			;;
		*)
			SSLURL=https://github.com/openssl/openssl/releases/download/$SSL/$SSL.tar.gz
			;;
	esac
        ;;
libressl-*)
        SSLURL=https://ftp.openbsd.org/pub/OpenBSD/LibreSSL/$SSL.tar.gz
        LIBRESSL=$SSL
        ;;
*)
        echo $SSL where to download?
        exit 1
        ;;
esac

if [ ! -d "$HOME/opt/$SSL" ]; then
	echo "Downloading... $SSLURL"
        wget "$SSLURL" || exit 1
        tar -xzf "$SSL.tar.gz" || exit 1
        cd "$SSL" || exit 1
        export OPENSSL_DIR=$HOME/.usr
        if [ "$RUNNER_OS" == "Linux" ]; then
                case "$SSL" in
                openssl-1.0*)
                        FLAGS=shared
                        ;;
                *)
                        FLAGS=no-shared
                esac
                ./config zlib no-tests $FLAGS --prefix="$OPENSSL_DIR" || exit 1
        fi
        if [ "$RUNNER_OS" == "macOS" ]; then
                if [ -z "$LIBRESSL" ]; then
                        ./Configure zlib darwin64-x86_64-cc no-tests no-shared --prefix="$OPENSSL_DIR" || exit 1
                else
                        ./config zlib no-tests no-shared --prefix="$OPENSSL_DIR" || exit 1
                fi
        fi
        make && make install_sw || {
                rm -rf "$OPENSSL_DIR"
                exit 1
        }
        cd ..
fi

# vim: ts=8 sw=8 noet tw=79 fen fdm=marker
