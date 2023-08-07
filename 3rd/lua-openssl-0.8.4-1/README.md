lua-openssl toolkit - A free, MIT-licensed OpenSSL binding for Lua.

[![CI](https://github.com/zhaozg/lua-openssl/actions/workflows/ci.yml/badge.svg)](https://github.com/zhaozg/lua-openssl/actions/workflows/ci.yml)
[![LibreSSL](https://github.com/zhaozg/lua-openssl/actions/workflows/libressl.yml/badge.svg)](https://github.com/zhaozg/lua-openssl/actions/workflows/libressl.yml)
[![Coverage Status](https://coveralls.io/repos/github/zhaozg/lua-openssl/badge.svg?branch=master)](https://coveralls.io/github/zhaozg/lua-openssl?branch=master)
[![luarocks](https://img.shields.io/luarocks/v/zhaozg/openssl)](https://luarocks.org/modules/zhaozg/openssl)

# Index

1. [Introduction](#introduction)
2. [Documentation](#documentation)
3. [Howto](#howto)
4. [Examples](#example-usage)

## Introduction

I needed a full OpenSSL binding for Lua, after googled, I couldn't find a version
to fit my needs. I found the PHP openssl binding is a good implementation, and it
inspired me. So I decided to write this OpenSSL toolkit for Lua.

The goal is to fully support openssl, include:

- ASN1 Process.
- Symmetrical encrypt/decrypt.
- Message digest.
- Asymmetrical encrypt/decrypt/sign/verify/seal/open.
- X509 certificate.
- PKCS7/CMS.
- SSL/TLS.

This lua-openssl toolkit works with [Lua](https://www.lua.org/) 5.1/5.2/5.3/5.4
or [luajit](http://luajit.org/) 2.0/2.1, and [OpenSSL](https://www.openssl.org/)
above 1.0.0 or [LibreSSL](https://www.libressl.org/) v3.3.6

It is recommended to use the most up-to-date OpenSSL version because of the
recent security fixes.

Most of the lua-openssl functions require a key or certificate as argument, to
make things easy to use OpenSSL.

This rule allows you to specify certificates or keys in the following ways:

1. As an openssl.x509 object returned from `openssl.x509.read`
2. As an openssl.evp_pkey object return from `openssl.pkey.read` or `openssl.pkey.new`

Similarly, you can also specify a public key as a key object returned from
`x509:get_public()`.

### lua-openssl modules

digest, cipher, x509, pkcs7, cms and so on, be write as modules.

```lua
   local digest = require'openssl'.digest
   local cipher = require'openssl'.cipher
```

digest() equals with digest.digest(), same cipher() equals with cipher.cipher().

## documentation

Document please see [here](http://zhaozg.github.io/lua-openssl/index.html),
that are generate by [LDoc](https://github.com/stevedonovan/LDoc).

_Notice_: Document quality is low and stale, feel free to make a PR to improve it.

### lua-openssl Objects

The following are some important lua-openssl object types:

```
	openssl.bio,
	openssl.x509,
	openssl.stack_of_x509,
	openssl.x509_req,
	openssl.evp_pkey,
	openssl.evp_digest,
	openssl.evp_cipher,
	openssl.engine,
	openssl.pkcs7,
	openssl.cms,
	openssl.evp_cipher_ctx,
	openssl.evp_digest_ctx
	...
```

They are shortened as bio, x509, sk_x509, csr, pkey, digest, cipher,
engine, cipher_ctx, and digest_ctx.

### openssl.bn

- **_openssl.bn_** come from [lbn](http://www.tecgraf.puc-rio.br/~lhf/ftp/lua/#lbn), and thanks.

openssl.bn is a big-number library for Lua 5.1. It handles only integers and is
suitable for number-theoretical and cryptographic applications. It is based
on the bn subsystem of OpenSSL cryptographic library:
https://github.com/openssl/openssl/blob/OpenSSL_1_0_2-stable/crypto/bn/bn.h
If you're running Unix, you probably already have OpenSSL installed.

To try the library, just edit Makefile to reflect your installation of Lua and
then run make. This will build the library and run a simple test. For detailed
installation instructions, see
http://webserver2.tecgraf.puc-rio.br/~lhf/ftp/lua/index.html#lbn

There is no manual but the library is simple and intuitive; see the summary
below.

bn library:

```
 __add(x,y)        compare(x,y)          pow(x,y)
 __div(x,y)        div(x,y)              powmod(x,y,m)
 __eq(x,y)         divmod(x,y)           random(bits)
 __lt(x,y)         gcd(x,y)              rmod(x,y)
 __mod(x,y)        invmod(x)             sqr(x)
 __mul(x,y)        isneg(x)              sqrmod(x)
 __pow(x,y)        isodd(x)              sqrtmod(x)
 __sub(x,y)        isone(x)              sub(x,y)
 __tostring(x)     isprime(x,[checks])   submod(x,y,m)
 __unm(x)          iszero(x)             text(t)
 abs(x)            mod(x,y)              tohex(x)
 add(x,y)          mul(x,y)              tonumber(x)
 addmod(x,y,m)     mulmod(x,y,m)         tostring(x)
 aprime(bits)      neg(x)                totext(x)
 bits(x)           number(x)             version
```

### Version

You can get version of lua-openssl, lua and OpenSSL from a Lua script.

```lua
openssl = require "openssl"
-- get version string format
lua_openssl_version, lua_version, openssl_version = openssl.version()
-- get version number format
lua_openssl_version, lua_version, openssl_version = openssl.version(true)
```

### Style

Source code of lua-openssl tidy with [astyle](http://astyle.sourceforge.net/)
`--style=allman --indent=spaces=2`

### Bugs

Lua-Openssl is heavily updated, if you find a bug, please report to
[here](https://github.com/zhaozg/lua-openssl/issues/)

I try to use [luaunit](https://github.com/bluebird75/luaunit) to write unit
[test](tree/master/test), and welcome PR to improve it.

## Howto

### Howto 1: Build on Linux/Unix System.

    git clone --recurse https://github.com/zhaozg/lua-openssl.git lua-openssl
    cd lua-openssl
    make
    make install
    make clean

If you want to make lua-openssl static link with openssl, please given
`OPENSSL_STATIC` flags, default will do dynamic link.

    make OPENSSL_STAITC=1

### Howto 2: Build on Windows with MSVC.

Before building, please change the setting in the config.win file.
Works with Lua5.1 (should support Lua5.2 by updating the config.win file).

    git clone --recurse https://github.com/zhaozg/lua-openssl.git lua-openssl
    cd lua-openssl
    nmake -f makefile.win
    nmake -f makefile.win install
    nmake -f makefile.win clean

### Howto 3: Build on Windows with mingw.

    git clone --recurse https://github.com/zhaozg/lua-openssl.git lua-openssl
    cd lua-openssl
    make
    make install
    make clean

### Howto 4: Install using luarocks.

    luarocks install openssl

### Howto 5: Build with CMake

   Build shared lua-openssl.

   `cmake -Bbuild -H. -DOPENSSL_ROOT_DIR=... && cd build && make`

   Build static lua-openssl

   `cmake -Bbuild -H. -DOPENSSL_ROOT_DIR=... -DBUILD_SHARED_LUA_OPENSSL=OFF && cd build && make`

### Howto 5: Handle fail or error

Most lua-openssl function or methods return nil or false when error or
failed, followed by string type error _reason_ and number type error _code_,
_code_ can pass to openssl.error() to get more error information.

All SSL object IO operation methods return nil or false when fail or error.
When nil returned, it followed by 'ssl' or 'syscall', means SSL layer or
system layer error. When false returned, it is followed by number 0, 'want_read',
'want_write','want_x509_lookup','want_connect','want_accept'. Number 0 means
SSL connection closed, other numbers means you should do some SSL operation.

Please remember that when lua-openssl function or methods fail without an
error code, you can get the last error by openssl.error(), and repeat call
openssl.error() will walk through error stacks of current threads.
openssl.errors(true) will also clear error stacks after return all errors,
this is very useful to free memory when lua-openssl repeat calls or run long times.

## Example usage

### Example 1: short encrypt/decrypt

```lua
local evp_cipher = openssl.cipher.get('des')
m = 'abcdefghick'
key = m
cdata = evp_cipher:encrypt(m,key)
m1  = evp_cipher:decrypt(cdata,key)
assert(m==m1)
```

### Example 2: quick evp_digest

```lua
md = openssl.digest.get('md5')
m = 'abcd'
aa = md:digest(m)

mdc=md:new()
mdc:update(m)
bb = mdc:final()
assert(openssl.hex(aa,true)==bb)
```

### Example 3: Quick HMAC hash

```lua
local hmac = require "openssl".hmac

alg = 'sha256'
key = '0123456789'
msg = 'example message'

hmac.hmac(alg, msg, key, true) -- binary/"raw" output
hmac.hmac(alg, msg, key, false) -- hex output
```

### Example 4: Iterate a openssl.stack_of_x509(sk_x509) object

```lua
n = #sk
for i=1, n do
	x = sk:get(i)
end
```

### Example 5: read and parse certificate

```lua
local openssl = require('openssl')

function dump(t,i)
	for k,v in pairs(t) do
		if(type(v)=='table') then
			print( string.rep('\t',i),k..'={')
			dump(v,i+1)
			print( string.rep('\t',i),k..'=}')
		else
			print( string.rep('\t',i),k..'='..tostring(v))
		end
	end
end

function test_x509()
	local x = openssl.x509.read(certasstring)
	print(x)
	t = x:parse()
	dump(t,0)
	print(t)
end

test_x509()
```

### Example 5: bio network handle(TCP)

- server

```lua
local openssl = require'openssl'
local bio = openssl.bio

host = host or "127.0.0.1"; --only ip
port = port or "8383";

local srv = assert(bio.accept(host..':'..port))
print('listen at:'..port)
local cli = assert(srv:accept())
while 1 do
    cli = assert(srv:accept())
    print('CLI:',cli)
    while cli do
        local s = assert(cli:read())
        print(s)
        assert(cli:write(s))
    end
    print(openssl.error(true))
end
```

- client

```lua
local openssl = require'openssl'
local bio = openssl.bio
io.read()

host = host or "127.0.0.1"; --only ip
port = port or "8383";

local cli = assert(bio.connect(host..':'..port,true))

    while cli do
        s = io.read()
        if(#s>0) then
            print(cli:write(s))
            ss = cli:read()
            assert(#s==#ss)
        end
    end
    print(openssl.error(true))
```

For more examples, please see test lua script file.

---

**_lua-openssl License_**

Copyright (c) 2011 - 2023 zhaozg, zhaozg(at)gmail.com

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to
deal in the Software without restriction, including without limitation the
rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
sell copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

---
