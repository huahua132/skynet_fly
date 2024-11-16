cmake_minimum_required(VERSION 3.10)
project(skynet_fly)

# 添加编译选项
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON) 

# 把lua头文件添加到全局搜索路径
include_directories(skynet/3rd/lua/)

# Windows
if (CMAKE_SYSTEM_NAME MATCHES "Windows")
    message(STATUS "current platform: Windows")
    add_compile_definitions(NOUSE_JEMALLOC LUA_BUILD_AS_DLL)

    set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wno-int-conversion -Wno-implicit-function-declaration -Wno-deprecated-declarations")
    set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS ON)

    #设置输出目录
    set(CMAKE_BINARY_DIR ${CMAKE_BINARY_DIR}/skynet_fly)
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/skynet)
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_DEBUG ${CMAKE_RUNTIME_OUTPUT_DIRECTORY})
    message(STATUS "The value of CMAKE_BINARY_DIR is: ${CMAKE_BINARY_DIR}")

    # 添加到全局搜索路径
    include_directories(win3rd/posix win3rd/pthread-win32)
    add_compile_options(/FI ${CMAKE_SOURCE_DIR}/win3rd/posix/unistd.h)

    aux_source_directory(skynet/3rd/lua LUA_LIB_SRC)
    list(REMOVE_ITEM LUA_LIB_SRC 
        "skynet/3rd/lua/lua.c"
        "skynet/3rd/lua/luac.c"
        "skynet/3rd/lua/onelua.c"
        "skynet/3rd/lua/ltests.c")
    message(STATUS "The value of LUA_LIB_SRC is: ${LUA_LIB_SRC}")

    aux_source_directory(skynet/skynet-src LIB_SKYNET_SRC)
    list(REMOVE_ITEM LIB_SKYNET_SRC skynet/skynet-src/skynet_main.c)
    aux_source_directory(win3rd/posix POSIX_SRC)
    add_subdirectory(win3rd/pthread-win32)
    add_library(liblua SHARED ${LUA_LIB_SRC})

    target_include_directories(liblua PRIVATE skynet/skynet-src)
    add_library(libposix SHARED ${POSIX_SRC})
    target_compile_definitions(libposix PRIVATE POSIX_LIBRARY)
    target_link_libraries(libposix ws2_32)
    add_library(libskynet SHARED ${LIB_SKYNET_SRC})
    target_include_directories(libskynet PRIVATE skynet/skynet-src)
    target_link_libraries(libskynet liblua libposix pthreadVC3)

    # 编译 skynet 可执行文件
    add_executable(skynet skynet/skynet-src/skynet_main.c)
    target_link_libraries(skynet ws2_32 liblua libposix libskynet pthreadVC3)

    # 重新设置动态库输出路径
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/skynet/3rd/lua)
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY_DEBUG ${CMAKE_LIBRARY_OUTPUT_DIRECTORY})
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/skynet/3rd/lua)
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_DEBUG ${CMAKE_RUNTIME_OUTPUT_DIRECTORY})
    # 编译 lua 可执行文件
    add_executable(lua skynet/3rd/lua/lua.c)
    add_library(lualibb SHARED ${LUA_LIB_SRC})
    target_include_directories(lualibb PRIVATE skynet/skynet-src)
    target_link_libraries(lua lualibb)

    # 重新设置动态库输出路径
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/skynet/luaclib)
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY_DEBUG ${CMAKE_LIBRARY_OUTPUT_DIRECTORY})
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/skynet/luaclib)
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_DEBUG ${CMAKE_RUNTIME_OUTPUT_DIRECTORY})

    # 生成动态库 skynet.so
    set(LUA_CLIB_SKYNET_SRC
        skynet/lualib-src/lua-skynet.c
        skynet/lualib-src/lua-seri.c
        skynet/lualib-src/lua-socket.c
        skynet/lualib-src/lua-mongo.c
        skynet/lualib-src/lua-netpack.c
        skynet/lualib-src/lua-memory.c
        skynet/lualib-src/lua-multicast.c
        skynet/lualib-src/lua-cluster.c
        skynet/lualib-src/lua-crypt.c
        skynet/lualib-src/lsha1.c
        skynet/lualib-src/lua-sharedata.c
        skynet/lualib-src/lua-stm.c
        skynet/lualib-src/lua-debugchannel.c
        skynet/lualib-src/lua-datasheet.c
        skynet/lualib-src/lua-sharetable.c 
        lualib-src/lua-frpcpack.c)
    message(STATUS "The value of LIB_SKYNET_SRC is: ${LIB_SKYNET_SRC}")
    add_library(skynetso SHARED ${LUA_CLIB_SKYNET_SRC})
    target_include_directories(skynetso PRIVATE skynet/skynet-src)
    target_compile_definitions(skynetso PUBLIC LUA_LIB)
    set_target_properties(skynetso PROPERTIES OUTPUT_NAME skynet)
    target_link_libraries(skynetso ws2_32 libskynet)

    # 生成动态库 bson.so
    add_library(bson SHARED skynet/lualib-src/lua-bson.c)
    target_include_directories(bson PRIVATE skynet/skynet-src)
    target_link_libraries(bson ws2_32 liblua)

    # 生成动态库 md5.so
    aux_source_directory(skynet/3rd/lua-md5 LUA_MD5_SRC)
    add_library(md5 SHARED ${LUA_MD5_SRC})
    target_link_libraries(md5 liblua)

    # 生成动态库 client.so
    add_library(client SHARED skynet/lualib-src/lua-clientsocket.c
                        skynet/lualib-src/lua-crypt.c
                        skynet/lualib-src/lsha1.c)
    target_include_directories(client PRIVATE skynet/skynet-src)
    target_link_libraries(client ws2_32 liblua libposix pthreadVC3)

    # 生成动态库 sproto.so
    aux_source_directory(skynet/lualib-src/sproto SPROTO_SRC)
    add_library(sproto SHARED ${SPROTO_SRC})
    target_link_libraries(sproto liblua)

    # 生成动态库 lpeg.so
    aux_source_directory(skynet/3rd/lpeg LPEG_SRC)
    add_library(lpeg SHARED ${LPEG_SRC})
    target_link_libraries(lpeg liblua)

    # 生成动态库 ltls.so
    add_library(ltls SHARED skynet/lualib-src/ltls.c)
    target_include_directories(ltls PRIVATE skynet/skynet-src)
    target_include_directories(ltls PRIVATE win3rd/openssl/include/)
    target_link_directories(ltls PRIVATE win3rd/openssl/lib/windows/)
    target_link_libraries(ltls ws2_32 mswsock liblua libposix pthreadVC3 libssl libcrypto Crypt32)

    # 重新设置动态库输出路径
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/luaclib)
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY_DEBUG ${CMAKE_LIBRARY_OUTPUT_DIRECTORY})
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/luaclib)
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_DEBUG ${CMAKE_RUNTIME_OUTPUT_DIRECTORY})

    # 生成动态库 pb.so
    aux_source_directory(3rd/lua-protobuf-0.4.0 PB_SRC)
    add_library(pb SHARED ${PB_SRC})
    target_link_libraries(pb liblua)

    # 生成动态库 lfs.so
    aux_source_directory(3rd/luafilesystem-1_8_0/src LFS_SRC)
    add_library(lfs SHARED ${LFS_SRC})
    target_link_libraries(lfs liblua)

    # 生成动态库 cjson.so
    add_library(cjson SHARED 3rd/lua-cjson/lua_cjson.c 3rd/lua-cjson/strbuf.c 3rd/lua-cjson/fpconv.c)
    target_include_directories(cjson PRIVATE 3rd/lua-cjson)
    target_link_libraries(cjson liblua)

    # 生成动态库 skiplist.so
    aux_source_directory(3rd/lua-zset ZSET_SRC)
    add_library(skiplist SHARED ${ZSET_SRC})
    target_link_libraries(skiplist liblua)

    # 生成动态库 chat_filter.so
    aux_source_directory(3rd/lua-chat_filter CHAT_FILTER_SRC)
    add_library(chat_filter SHARED ${CHAT_FILTER_SRC})
    target_link_libraries(chat_filter liblua)

    # 生成动态库 snapshot.so
    add_library(snapshot SHARED 3rd/lua-snapshot/snapshot.c)
    target_link_libraries(snapshot liblua)

    # 生成动态库 openssl.so
    aux_source_directory(3rd/lua-openssl-0.9.0-0 OPENSSL_SRC)
    aux_source_directory(3rd/lua-openssl-0.9.0-0/deps/auxiliar OPENSSL_AUX_SRC)
    aux_source_directory(3rd/lua-openssl-0.9.0-0/deps/lua-compat OPENSSL_COMPAT_SRC)
    add_library(openssl SHARED ${OPENSSL_COMPAT_SRC} ${OPENSSL_AUX_SRC} ${OPENSSL_SRC})
    target_include_directories(openssl PRIVATE win3rd/openssl/include/ 3rd/lua-openssl-0.9.0-0 3rd/lua-openssl-0.9.0-0/deps/auxiliar 3rd/lua-openssl-0.9.0-0/deps/lua-compat)
    target_link_directories(openssl PRIVATE win3rd/openssl/lib/windows/)
    target_link_libraries(openssl ws2_32 mswsock liblua libposix pthreadVC3 libssl libcrypto Crypt32)

    # 设置动态库属性
    set_target_properties(
        lpeg sproto client md5 bson skynetso ltls
        pb lfs skiplist chat_filter snapshot openssl cjson
        PROPERTIES
        PREFIX ""
        SUFFIX .so )

    # 重新设置动态库输出路径
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/skynet/cservice)
    set(CMAKE_LIBRARY_OUTPUT_DIRECTORY_DEBUG ${CMAKE_LIBRARY_OUTPUT_DIRECTORY})
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/skynet/cservice)
    set(CMAKE_RUNTIME_OUTPUT_DIRECTORY_DEBUG ${CMAKE_RUNTIME_OUTPUT_DIRECTORY})

    # 生成c服务
    file(GLOB CSERVICE_FILE_LIST "skynet/service-src/*.c")
    message(STATUS "The value of CSERVICE_FILE_LIST is: ${CSERVICE_FILE_LIST}")
    foreach(FILE_PATH IN LISTS CSERVICE_FILE_LIST)
        message(STATUS "Processing file: ${FILE_PATH}")
        string(REGEX REPLACE ".*skynet/service-src/service_" "" LIB_NAME "${FILE_PATH}")
        string(REGEX REPLACE ".c$" "" LIB_NAME "${LIB_NAME}")
        message(STATUS "The value of LIB_NAME is: ${LIB_NAME}")
        add_library(${LIB_NAME} SHARED ${FILE_PATH})
        target_include_directories(${LIB_NAME} PRIVATE skynet/skynet-src)
        target_link_libraries(${LIB_NAME} ws2_32 libskynet)
        set_target_properties(${LIB_NAME} PROPERTIES PREFIX "" SUFFIX .so ENABLE_EXPORTS ON)
    endforeach()
endif ()

# 拷贝其他文件
message(STATUS "The value of CMAKE_SOURCE_DIR is: ${CMAKE_SOURCE_DIR}")
file(COPY ${CMAKE_SOURCE_DIR}/skynet/lualib/ DESTINATION skynet_fly/skynet/lualib NO_SOURCE_PERMISSIONS)
file(COPY ${CMAKE_SOURCE_DIR}/skynet/test/ DESTINATION skynet_fly/skynet/test NO_SOURCE_PERMISSIONS)
file(COPY ${CMAKE_SOURCE_DIR}/skynet/service/ DESTINATION skynet_fly/skynet/service NO_SOURCE_PERMISSIONS)
file(COPY ${CMAKE_SOURCE_DIR}/skynet/examples/ DESTINATION skynet_fly/skynet/examples NO_SOURCE_PERMISSIONS)

file(COPY ${CMAKE_SOURCE_DIR}/lualib/ DESTINATION skynet_fly/lualib NO_SOURCE_PERMISSIONS)
file(COPY ${CMAKE_SOURCE_DIR}/test/ DESTINATION skynet_fly/test NO_SOURCE_PERMISSIONS)
file(COPY ${CMAKE_SOURCE_DIR}/service/ DESTINATION skynet_fly/service NO_SOURCE_PERMISSIONS)
file(COPY ${CMAKE_SOURCE_DIR}/examples/ DESTINATION skynet_fly/examples NO_SOURCE_PERMISSIONS)
file(COPY ${CMAKE_SOURCE_DIR}/module/ DESTINATION skynet_fly/module NO_SOURCE_PERMISSIONS)
file(COPY ${CMAKE_SOURCE_DIR}/script/ DESTINATION skynet_fly/script NO_SOURCE_PERMISSIONS)