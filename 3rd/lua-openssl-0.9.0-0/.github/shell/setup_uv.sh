#! /bin/bash

source .travis/platform.sh

cd $TRAVIS_BUILD_DIR

if [[ "$PLATFORM" == "linux" && -z "$SSL" ]]; then
  git clone https://github.com/luvit/luv
  cd luv
  git submodule update --init --recursive
  git submodule update --recursive
  sudo add-apt-repository --yes ppa:kalakris/cmake
  sudo apt-get update -qq
  sudo apt-get install cmake
  make
fi

cp luv.so $TRAVIS_BUILD_DIR
cd $TRAVIS_BUILD_DIR
