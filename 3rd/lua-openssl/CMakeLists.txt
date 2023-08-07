cmake_minimum_required(VERSION 2.8.9)
project(lua-openssl C)

set(CMAKE_MACOSX_RPATH 1)
set(CMAKE_MODULE_PATH ${CMAKE_MODULE_PATH}
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake/Modules")
option(BUILD_SHARED_LUA_OPENSSL "Shared or Static lua-openssl" ON)

include(GNUInstallDirs)

find_package(LuaJIT)
if(NOT LUAJIT_FOUND)
    find_package(Lua REQUIRED)
endif()
find_package(OpenSSL REQUIRED)

set(CMAKE_THREAD_PREFER_PTHREAD TRUE)
set(THREADS_PREFER_PTHREAD_FLAG TRUE)
find_package(Threads REQUIRED)

if(BUILD_SHARED_LUA_OPENSSL)
    set(LUA_OPENSSL_LIBTYPE MODULE)
    if(WIN32)
        add_definitions(-DLUA_BUILD_AS_DLL)
        set(EXTRA_LIBS "ws2_32.lib" "crypt32.lib")
    endif()
else()
    set(LUA_OPENSSL_LIBTYPE STATIC)
endif()

add_library(lua-openssl ${LUA_OPENSSL_LIBTYPE}
    deps/auxiliar/auxiliar.c
    deps/auxiliar/subsidiar.c
    src/asn1.c
    src/bio.c
    src/callback.c
    src/cipher.c
    src/cms.c
    src/compat.c
    src/crl.c
    src/csr.c
    src/dh.c
    src/digest.c
    src/dsa.c
    src/ec.c
    src/engine.c
    src/mac.c
    src/hmac.c
    src/lbn.c
    src/lhash.c
    src/misc.c
    src/ocsp.c
    src/oids.txt
    src/openssl.c
    src/ots.c
    src/pkcs12.c
    src/pkcs7.c
    src/pkey.c
    src/private.h
    src/rsa.c
    src/sk.h
    src/srp.c
    src/ssl.c
    src/th-lock.c
    src/util.c
    src/x509.c
    src/xattrs.c
    src/xexts.c
    src/xname.c
    src/xalgor.c
    src/xstore.c
)

target_include_directories(lua-openssl PUBLIC
    ${OPENSSL_INCLUDE_DIR}
    ${LUA_INCLUDE_DIR}
    deps
    deps/lua-compat/c-api
    deps/auxiliar
)

target_link_libraries(lua-openssl PUBLIC
    ${OPENSSL_LIBRARIES}
    ${EXTRA_LIBS}
    Threads::Threads
)

if(WIN32)
    target_link_libraries(lua-openssl PUBLIC
        ${LUA_LIBRARIES}
    )
endif()

if(APPLE)
    target_link_options(lua-openssl PUBLIC -bundle -undefined dynamic_lookup)
endif()

target_compile_options(lua-openssl PRIVATE -DLUA_LIB)

set_target_properties(lua-openssl PROPERTIES
    PREFIX ""
    OUTPUT_NAME "openssl"
)

install(TARGETS lua-openssl
    LIBRARY DESTINATION
    ${CMAKE_INSTALL_LIBDIR}/lua/${LUA_VERSION_MAJOR}.${LUA_VERSION_MINOR}
)
