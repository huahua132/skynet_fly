Building and Installation
=========================

How to Build
------------

To build and install OpenSSL GOST Engine, you will need

* OpenSSL 3.0 development version
* an ANSI C compiler
* CMake (3.0 or newer, 3.18 recommended)

Here is a quick build guide:

    $ git clone https://github.com/gost-engine/engine
    $ cd engine
    $ git submodule update --init
    $ mkdir build
    $ cd build
    $ cmake -DCMAKE_BUILD_TYPE=Release ..
    $ cmake --build . --config Release

Instead of `Release` you can use `Debug`, `RelWithDebInfo` or `MinSizeRel` configuration.
See [cmake docs](https://cmake.org/cmake/help/latest/variable/CMAKE_BUILD_TYPE.html) for details.
You will find built binaries in `../bin` directory.

If you want to build against a specific OpenSSL instance (you will need it if
you have more than one OpenSSL instance for example), you can use the `cmake`
variable `OPENSSL_ROOT_DIR` to specify absolute path of the desirable OpenSSL
instance:

    $ cmake -DOPENSSL_ROOT_DIR=/PATH/TO/OPENSSL/ ..

Building against OpenSSL 3.0 requires openssl detection module
(FindOpenSSL.cmake) from CMake 3.18 or higher. More earlier versions may have
problems with it.

If you use Visual Studio, you can also set `CMAKE_INSTALL_PREFIX` variable
to set install path, like this:

    > cmake -G "Visual Studio 15 Win64" -DCMAKE_PREFIX_PATH=c:\OpenSSL\vc-win64a\ -DCMAKE_INSTALL_PREFIX=c:\OpenSSL\vc-win64a\ ..

Also instead of `cmake --build` tool you can just open `gost-engine.sln`
in Visual Studio, select configuration and call `Build Solution` manually.

Instructions how to build OpenSSL 1.1.0 with Microsoft Visual Studio
you can find [there](https://gist.github.com/terrillmoore/995421ea6171a9aa50552f6aa4be0998).

How to Install
--------------

To install GOST Engine you can call:

    # cmake --build . --target install --config Release

or old plain and Unix only:

    # make install

The engine library `gost.so` should be installed into OpenSSL engine directory.

To ensure that it is installed propery call:

    $ openssl version -e
    ENGINESDIR: "/usr/lib/i386-linux-gnu/engines-1.1"

Then check that `gost.so` there

    # ls /usr/lib/i386-linux-gnu/engines-1.1

Finally, to start using GOST Engine through OpenSSL, you should edit
`openssl.cnf` configuration file as specified below.


How to Configure
----------------

The very minimal example of the configuration file is provided in this
distribution and named `example.conf`.

Configuration file should include following statement in the global
section, i.e. before first bracketed section header (see config(5) for details)

    openssl_conf = openssl_def

where `openssl_def` is name of the section in configuration file which
describes global defaults.

This section should contain following statement:

    [openssl_def]
    engines = engine_section

which points to the section which describes list of the engines to be
loaded. This section should contain:

    [engine_section]
    gost = gost_section

And section which describes configuration of the engine should contain

    [gost_section]
    engine_id = gost
    dynamic_path = /usr/lib/ssl/engines/libgost.so
    default_algorithms = ALL

Various cryptoproviders (e.g. BouncyCastle) has some problems with private key
parsing from PrivateKeyInfo, so if you want to use old private key
representation format, which supported by BC, you will have to add:

    GOST_PK_FORMAT = LEGACY_PK_WRAP

to `[gost_section]`.

Where `engine_id` parameter specifies name of engine (should be `gost`).

`dynamic_path is` a location of the loadable shared library implementing the
engine. If the engine is compiled statically or is located in the OpenSSL
engines directory, this line can be omitted.

`default_algorithms` parameter specifies that all algorithms, provided by
engine, should be used.

The `CRYPT_PARAMS` parameter is engine-specific. It allows the user to choose
between different parameter sets of symmetric cipher algorithm. [RFC 4357][1]
specifies several parameters for the GOST 28147-89 algorithm, but OpenSSL
doesn't provide user interface to choose one when encrypting. So use engine
configuration parameter instead. It SHOULD NOT be used nowadays because all
the parameters except the default one are deprecated now.

Value of this parameter can be either short name, defined in OpenSSL
`obj_dat.h` header file or numeric representation of OID, defined in
[RFC 4357][1].

[1]:https://tools.ietf.org/html/rfc4357 "RFC 4357"
