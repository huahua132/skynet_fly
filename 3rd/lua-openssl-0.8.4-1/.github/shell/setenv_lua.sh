source .travis/platform.sh

export PATH=$HOME/.usr/bin:${PATH}
export PKG_CONFIG_PATH=$HOME/.usr/lib/pkgconfig:$PKG_CONFIG_PATH
export LD_LIBRARY_PATH=$HOME/.usr/lib:$LD_LIBRARY_PATH

if [ "$PLATFORM" == "macosx" ]; then
  if [ -z "$SSL" ]; then
    export PKG_CONFIG_PATH=/usr/local/opt/openssl/lib/pkgconfig:$PKG_CONFIG_PATH
    export LD_LIBRARY_PATH=/usr/local/opt/openssl/lib:$LD_LIBRARY_PATH
  fi
fi
if [[ "$PLATFORM" == "linux" && "$SSL" =~ ^libressl ]]; then
  sudo apt-get -y update
  sudo apt install -y valgrind
fi

bash .travis/setup_lua.sh
if [ -x $HOME/.usr/bin/luarocks ]; then
  eval $($HOME/.usr/bin/luarocks path)
fi
