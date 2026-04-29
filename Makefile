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
$(LUA_CLIB_PATH)/lfs.so : 3rd/luafilesystem/src/lfs.c | $(LUA_CLIB_PATH) $(SKYNET_BUILDER)
	$(CC) $(CFLAGS) $(SHARED) -I3rd/luafilesystem/src $^ -o $@

$(LUA_CLIB_PATH)/cjson.so : 3rd/lua-cjson/lua_cjson.c 3rd/lua-cjson/strbuf.c 3rd/lua-cjson/fpconv.c | $(LUA_CLIB_PATH) $(SKYNET_BUILDER)
	$(CC) $(CFLAGS) $(SHARED) -I3rd/lua-cjson $^ -o $@

$(LUA_CLIB_PATH)/pb.so : 3rd/lua-protobuf/pb.c | $(LUA_CLIB_PATH) $(SKYNET_BUILDER)
	$(CC) $(CFLAGS) $(SHARED) -I3rd/lua-protobuf $^ -o $@

$(LUA_CLIB_PATH)/zlib.so : 3rd/lzlib/lzlib.c | $(LUA_CLIB_PATH) $(SKYNET_BUILDER)
	$(CC) $(CFLAGS) $(SHARED) -Werror -pedantic -I3rd/lzlib -I3rd/zlib $^ -o $@ 3rd/zlib/libz.a

$(LUA_CLIB_PATH)/chat_filter.so : 3rd/lua-chat_filter/lua-chat_filter.c | $(LUA_CLIB_PATH) $(SKYNET_BUILDER)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@ -I3rd/lua-chat_filter

$(LUA_CLIB_PATH)/skiplist.so : 3rd/lua-zset/skiplist.c 3rd/lua-zset/lua-skiplist.c | $(LUA_CLIB_PATH) $(SKYNET_BUILDER)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@ -I3rd/lua-zset

$(LUA_CLIB_PATH)/snapshot.so : 3rd/lua-snapshot/snapshot.c | $(LUA_CLIB_PATH) $(SKYNET_BUILDER)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@

$(LUA_CLIB_PATH)/frpcpack.so : lualib-src/lua-frpcpack.c | $(LUA_CLIB_PATH) $(SKYNET_BUILDER)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@ -Iskynet/skynet-src

# OpenSSL 动态库生成
# 注意: ec_util.c / group.c / point.c 通过 #include 被 ec.c 内联，不能单独编译
# 参考 3rd/lua-openssl/Makefile 中的 OBJS 列表
SSL_SRC_DIR  := 3rd/lua-openssl/src
SSL_DEP_DIR  := 3rd/lua-openssl/deps

SSL_SRCS := \
	$(SSL_SRC_DIR)/asn1.c \
	$(SSL_SRC_DIR)/bio.c \
	$(SSL_SRC_DIR)/callback.c \
	$(SSL_SRC_DIR)/cipher.c \
	$(SSL_SRC_DIR)/cms.c \
	$(SSL_SRC_DIR)/compat.c \
	$(SSL_SRC_DIR)/crl.c \
	$(SSL_SRC_DIR)/csr.c \
	$(SSL_SRC_DIR)/dh.c \
	$(SSL_SRC_DIR)/digest.c \
	$(SSL_SRC_DIR)/dsa.c \
	$(SSL_SRC_DIR)/ec.c \
	$(SSL_SRC_DIR)/engine.c \
	$(SSL_SRC_DIR)/hmac.c \
	$(SSL_SRC_DIR)/kdf.c \
	$(SSL_SRC_DIR)/lbn.c \
	$(SSL_SRC_DIR)/lhash.c \
	$(SSL_SRC_DIR)/mac.c \
	$(SSL_SRC_DIR)/misc.c \
	$(SSL_SRC_DIR)/ocsp.c \
	$(SSL_SRC_DIR)/openssl.c \
	$(SSL_SRC_DIR)/ots.c \
	$(SSL_SRC_DIR)/param.c \
	$(SSL_SRC_DIR)/pkcs12.c \
	$(SSL_SRC_DIR)/pkcs7.c \
	$(SSL_SRC_DIR)/pkey.c \
	$(SSL_SRC_DIR)/provider.c \
	$(SSL_SRC_DIR)/rsa.c \
	$(SSL_SRC_DIR)/srp.c \
	$(SSL_SRC_DIR)/ssl.c \
	$(SSL_SRC_DIR)/th-lock.c \
	$(SSL_SRC_DIR)/util.c \
	$(SSL_SRC_DIR)/x509.c \
	$(SSL_SRC_DIR)/xalgor.c \
	$(SSL_SRC_DIR)/xattrs.c \
	$(SSL_SRC_DIR)/xexts.c \
	$(SSL_SRC_DIR)/xname.c \
	$(SSL_SRC_DIR)/xstore.c \
	$(SSL_DEP_DIR)/auxiliar/auxiliar.c \
	$(SSL_DEP_DIR)/auxiliar/subsidiar.c

SSL_CFLAGS  = $(CFLAGS)
SSL_CFLAGS += -I$(SSL_SRC_DIR) -I$(SSL_DEP_DIR) -I$(SSL_DEP_DIR)/auxiliar -I$(SSL_DEP_DIR)/lua-compat/c-api

$(LUA_CLIB_PATH)/openssl.so : $(SSL_SRCS) | $(LUA_CLIB_PATH) $(SKYNET_BUILDER)
	$(CC) $(SSL_CFLAGS) $(SHARED) $^ -o $@ -I$(TLS_INC) $(TLS_LIB)/libssl.a $(TLS_LIB)/libcrypto.a

# LuaSocket 生成，依赖 Skynet
$(LUA_CLIB_PATH)/socket.so: | $(SKYNET_BUILDER)
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
