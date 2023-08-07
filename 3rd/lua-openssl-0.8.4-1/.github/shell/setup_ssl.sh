#!/bin/bash

if [ -z "$SSL" ]; then
        echo '$SSL not set, use default openssl' >&2
        exit 0
fi

case "$SSL" in
openssl-0.9.*)
        SSLURL=https://www.openssl.org/source/old/0.9.x/$SSL.tar.gz
        ;;
openssl-1.0.0*)
        SSLURL=https://www.openssl.org/source/old/1.0.0/$SSL.tar.gz
        ;;
openssl-1.0.1*)
        SSLURL=https://www.openssl.org/source/old/1.0.1/$SSL.tar.gz
        ;;
openssl-*)
        SSLURL=https://www.openssl.org/source/$SSL.tar.gz
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
        wget "$SSLURL" || exit 1
        tar -xzf "$SSL.tar.gz" || exit 1
        cd "$SSL" || exit 1
        export OPENSSL_DIR=$HOME/.usr
        if [ "$RUNNER_OS" == "Linux" ]; then
                ./config shared --prefix="$OPENSSL_DIR" || exit 1
        fi
        if [ "$RUNNER_OS" == "macOS" ]; then
                if [ -z "$LIBRESSL" ]; then
                        ./Configure darwin64-x86_64-cc shared --prefix="$OPENSSL_DIR" || exit 1
                else
                        ./config --prefix="$OPENSSL_DIR" || exit 1
                fi
        fi
        make && make install_sw || {
                rm -rf "$OPENSSL_DIR"
                exit 1
        }
        cd ..
fi

# vim: ts=8 sw=8 noet tw=79 fen fdm=marker
