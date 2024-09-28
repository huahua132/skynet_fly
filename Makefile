all: help

help:
	@echo "make linux       # linux 编译 skynet fly"
	@echo "make freebsd     # freebsd 编译 skynet fly"
	@echo "make macosx      # macosx 编译 skynet fly"
	@echo "make clean       # 清理"
	@echo "make cleanall    # 清理所有"
	@echo "make upskynet    # 更新skynet仓库代码"

# 定义平台默认变量
PLAT ?= none

linux : PLAT = linux
macosx : PLAT = macosx
freebsd : PLAT = freebsd

# 路径定义
LUA_CLIB_PATH ?= luaclib
CSERVICE_PATH ?= cservice
LUA_INC ?= skynet/3rd/lua
CFLAGS = -g -O0 -Wall -I$(LUA_INC)
SHARED := -fPIC --shared

# Skynet 编译路径
SKYNET := skynet/Makefile  # Skynet 的 makefile
SKYNET_BUILDER := skynet/skynet/skynet  # 在构建后生成的 Skynet 文件

# 密钥库路径
TLS_LIB := 3rd/openssl
TLS_INC := 3rd/openssl/include

macosx : SHARED := -fPIC -dynamiclib -Wl,-undefined,dynamic_lookup

# 创建目录 (仅当需要时创建)
$(LUA_CLIB_PATH) :
	mkdir $(LUA_CLIB_PATH)
    
$(CSERVICE_PATH) :
	mkdir $(CSERVICE_PATH)

# 新增的 C 服务
CSERVICE =

# 新增 Lua C 库
LUA_CLIB = lfs cjson pb zlib chat_filter openssl skiplist snapshot frpcpack socket

# Skynet 初始化（通过子模块）
$(SKYNET):
	git submodule update --init
	chmod -R 744 skynet

# 编译 Skynet（生成 skynet/skynet/skynet 文件）
$(SKYNET_BUILDER): $(SKYNET)
	cd skynet && $(MAKE) PLAT=$(PLAT) TLS_MODULE=ltls TLS_INC=../$(TLS_INC) TLS_LIB=../$(TLS_LIB)

# 创建 Lua 模块并依赖 Skynet 完成编译
$(LUA_CLIB_PATH)/lfs.so : $(SKYNET_BUILDER) 3rd/luafilesystem-1_8_0/src/lfs.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I3rd/luafilesystem-1_8_0/src $^ -o $@

$(LUA_CLIB_PATH)/cjson.so : $(SKYNET_BUILDER) 3rd/lua-cjson/lua_cjson.c 3rd/lua-cjson/strbuf.c 3rd/lua-cjson/fpconv.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I3rd/lua-cjson $^ -o $@

$(LUA_CLIB_PATH)/pb.so : $(SKYNET_BUILDER) 3rd/lua-protobuf-0.4.0/pb.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I3rd/lua-protobuf-0.4.0 $^ -o $@

$(LUA_CLIB_PATH)/zlib.so : $(SKYNET_BUILDER) 3rd/lzlib/lzlib.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -Werror -pedantic -I3rd/lzlib -I3rd/zlib $^ -o $@ 3rd/zlib/libz.a

$(LUA_CLIB_PATH)/chat_filter.so : $(SKYNET_BUILDER) 3rd/lua-chat_filter/lua-chat_filter.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@ -I3rd/lua-chat_filter

$(LUA_CLIB_PATH)/skiplist.so : $(SKYNET_BUILDER) 3rd/lua-zset/skiplist.c 3rd/lua-zset/lua-skiplist.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@ -I3rd/lua-zset

$(LUA_CLIB_PATH)/snapshot.so : $(SKYNET_BUILDER) 3rd/lua-snapshot/snapshot.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@

$(LUA_CLIB_PATH)/frpcpack.so : $(SKYNET_BUILDER) lualib-src/lua-frpcpack.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@ -Iskynet/skynet-src

# OpenSSL 动态库生成
SSL_SRCS := $(shell find 3rd/lua-openssl-0.9.0-0 -name '*.c')
SSL_HDRS := $(shell find 3rd/lua-openssl-0.9.0-0 -name '*.h')
SSL_INCS := $(sort $(dir $(SSL_HDRS)))

SSL_CFLAGS = $(CFLAGS)
SSL_CFLAGS += $(foreach dir,$(SSL_INCS),-I$(dir))

$(LUA_CLIB_PATH)/openssl.so : $(SKYNET_BUILDER) $(SSL_SRCS) | $(LUA_CLIB_PATH)
    $(CC) $(SSL_CFLAGS) $(SHARED) $^ -o $@ -I$(TLS_INC) $(TLS_LIB)/libssl.a $(TLS_LIB)/libcrypto.a

# LuaSocket 生成，依赖 Skynet
$(LUA_CLIB_PATH)/socket.so : $(SKYNET_BUILDER)
	cd 3rd/luasocket && $(MAKE) PLAT=$(PLAT) LUAV=5.4 prefix=../../../$(LUA_CLIB_PATH) LUAINC_$(PLAT)=../../../$(LUA_INC) LUALIB_$(PLAT)=../../../$(LUA_INC)
	mv 3rd/luasocket/src/socket-3.1.0.so $(LUA_CLIB_PATH)/socket.so

$(SKYNET):
	git submodule update --init
	chmod -R 744 skynet

# 编译 Skynet，依赖 Makefile 和子模块
$(SKYNET_BULDER): $(SKYNET)
	cd skynet && $(MAKE) PLAT=$(PLAT) TLS_MODULE=ltls TLS_INC=../$(TLS_INC) TLS_LIB=../$(TLS_LIB)

# 更新 Skynet 子模块
upskynet: $(SKYNET)
	git submodule update --remote

# 依赖 Skynet 完全编译再去编译 Lua 模块
linux macosx freebsd: $(SKYNET_BUILDER) $(LUA_CLIB_PATH) \
	$(foreach v,$(LUA_CLIB), $(LUA_CLIB_PATH)/$(v).so)

# 清理生成的 .so 文件
clean:
	cd skynet && $(MAKE) clean
	rm -f $(LUA_CLIB_PATH)/*.so
	rm -f $(CSERVICE_PATH)/*.so

cleanall: clean
	cd skynet && $(MAKE) cleanall
