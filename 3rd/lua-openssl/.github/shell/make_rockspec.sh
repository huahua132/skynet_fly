#!/bin/bash

version=$1
if [ -z "$version" ]; then
  echo "must specify a version" >&2
  exit 1
fi

# .rockspec
cp openssl-scm-0.rockspec openssl-${version}.rockspec
script="/^version/s@\"[^\"]\\+\"@\"${version}\"@"
sed -e "${script}" -i.bak openssl-${version}.rockspec
script="s@https://github.com/zhaozg/lua-openssl/archive/master.zip@https://github.com/zhaozg/lua-openssl/releases/download/$version/openssl-$version.tar.gz@"
sed -e "${script}" -i.bak openssl-${version}.rockspec

# .tar.gz
rm -rf openssl-${version}
mkdir -p openssl-${version}/deps
cp -r LICENSE README.md *.win test Makefile src deps openssl-${version}/
COPYFILE_DISABLE=true tar -czf openssl-${version}.tar.gz openssl-${version}
rm -rf openssl-${version}
