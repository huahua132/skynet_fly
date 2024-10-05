#!/bin/bash -efux

# Download cpanm and make it executable as a standalone script
curl -L https://cpanmin.us -o cpanm
chmod 0755 cpanm

sudo ./cpanm --notest Test2::V0 > build.log 2>&1 \
    || (cat build.log && exit 1)

if [ "${APT_INSTALL-}" ]; then
    sudo apt-get install -y $APT_INSTALL
fi

git clone --depth 1 -b $OPENSSL_BRANCH https://github.com/openssl/openssl.git
cd openssl
git describe --always --long

PREFIX=$HOME/opt

${SETARCH-} ./config shared -d --prefix=$PREFIX --libdir=lib --openssldir=$PREFIX ${USE_RPATH:+-Wl,-rpath=$PREFIX/lib}
${SETARCH-} make -s -j$(nproc) build_libs
${SETARCH-} make -s -j$(nproc) build_programs
make -s install_sw
