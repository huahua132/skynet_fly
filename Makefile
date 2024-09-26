all : help

help:
	@echo "make linux       # linux 编译 skynet fly"
	@echo "make freebsd     # freebsd 编译 skynet fly"
	@echo "make macosx      # macosx 编译 skynet fly"
	@echo "make clean       # 清理"
	@echo "make cleanall    # 清理所有"
	@echo "make upskynet    # 更新skynet仓库代码"

PLAT ?= none

linux : PLAT = linux
macosx : PLAT = macosx
freebsd : PLAT = freebsd

LUA_CLIB_PATH ?= luaclib
CSERVICE_PATH ?= cservice
LUA_INC ?= skynet/3rd/lua
CFLAGS = -g -O0 -Wall -I$(LUA_INC)
SHARED := -fPIC --shared

SKYNET := skynet/Makefile
SKYNET_BULDER := skynet/skynet/skynet

TLS_LIB := 3rd/openssl
TLS_INC := 3rd/openssl/include
SSL_STATICCLIB := $(TLS_LIB)/libssl.a $(TLS_LIB)/libcrypto.a
SKYNET_SSL_STATICCLIB := ../$(TLS_LIB)/libssl.a

ZLIB_STATICLIB := 3rd/zlib/libz.a

macosx : SHARED := -fPIC -dynamiclib -Wl,-undefined,dynamic_lookup

$(LUA_CLIB_PATH) :
	mkdir $(LUA_CLIB_PATH)

$(CSERVICE_PATH) :
	mkdir $(CSERVICE_PATH)

#新增的c module服务
CSERVICE = 
#新增 lua-c库
LUA_CLIB = lfs cjson pb zlib chat_filter openssl skiplist snapshot frpcpack socket

define CSERVICE_TEMP
  $$(CSERVICE_PATH)/$(1).so : service-src/service_$(1).c | $$(CSERVICE_PATH)
	$$(CC) $$(CFLAGS) $$(SHARED) $$< -o $$@ -Iskynet_fly-src
endef

$(LUA_CLIB_PATH)/lfs.so : 3rd/luafilesystem-1_8_0/src/lfs.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I3rd/luafilesystem-1_8_0/src $^ -o $@

$(LUA_CLIB_PATH)/cjson.so : 3rd/lua-cjson/lua_cjson.c 3rd/lua-cjson/strbuf.c 3rd/lua-cjson/fpconv.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I3rd/lua-cjson $^ -o $@

$(LUA_CLIB_PATH)/pb.so : 3rd/lua-protobuf-0.4.0/pb.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I3rd/lua-protobuf-0.4.0 $^ -o $@

$(LUA_CLIB_PATH)/zlib.so : 3rd/lzlib/lzlib.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -Werror -pedantic -I3rd/lzlib $^ -o $@ $(ZLIB_STATICLIB)

$(LUA_CLIB_PATH)/chat_filter.so : 3rd/lua-chat_filter/lua-chat_filter.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@ -I3rd/lua-chat_filter

$(LUA_CLIB_PATH)/skiplist.so : 3rd/lua-zset/skiplist.c 3rd/lua-zset/lua-skiplist.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@ -I3rd/lua-zset

$(LUA_CLIB_PATH)/snapshot.so : 3rd/lua-snapshot/snapshot.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@

$(LUA_CLIB_PATH)/frpcpack.so : lualib-src/lua-frpcpack.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@ -Iskynet/skynet-src

# 递归查找 3rd/lua-openssl 目录及其子目录下的所有 .c 文件和 .h 文件
SSL_SRCS := $(shell find 3rd/lua-openssl-0.9.0-0 -name '*.c')
SSL_HDRS := $(shell find 3rd/lua-openssl-0.9.0-0 -name '*.h')
SSL_INCS := $(sort $(dir $(SSL_HDRS)))  # 获取所有子目录路径
SSL_CFLAGS = $(CFLAGS)
SSL_CFLAGS += $(foreach dir,$(SSL_INCS),-I$(dir))  # 添加递归搜索路径

$(LUA_CLIB_PATH)/openssl.so : $(SSL_SRCS) | $(LUA_CLIB_PATH)
	$(CC) $(SSL_CFLAGS) $(SHARED) $^ -o $@ -I$(TLS_INC) $(SSL_STATICCLIB)

$(LUA_CLIB_PATH)/socket.so:
	cd 3rd/luasocket && $(MAKE) PLAT=$(PLAT) LUAV=5.4 prefix=../../../$(LUA_CLIB_PATH) LUAINC_$(PLAT)=../../../$(LUA_INC) LUALIB_$(PLAT)=../../../$(LUA_INC)
	mv 3rd/luasocket/src/socket-3.1.0.so $(LUA_CLIB_PATH)/socket.so

$(SKYNET):
	git submodule update --init
	chmod -R 744 skynet

$(SKYNET_BULDER): $(SKYNET)
	cd skynet && $(MAKE) PLAT=$(PLAT) TLS_MODULE=ltls TLS_INC=../$(TLS_INC) TLS_LIB=../$(TLS_LIB)

upskynet: $(SKYNET)
	git submodule update --remote

linux macosx freebsd: $(SKYNET_BULDER) \
 	$(LUA_CLIB_PATH) \
	$(foreach v,$(LUA_CLIB), $(LUA_CLIB_PATH)/$(v).so)
	$(foreach v, $(CSERVICE), $(eval $(call CSERVICE_TEMP,$(v))))

clean:
	cd skynet && $(MAKE) clean
	rm -f $(LUA_CLIB_PATH)/*.so
	rm -f $(CSERVICE_PATH)/*.so

cleanall: clean
	cd skynet && $(MAKE) cleanall
