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
SKYNET_BULDER := skynet/skynet

TLS_LIB=/usr/bin/openssl
TLS_INC=/usr/include/openssl

macosx : SHARED := -fPIC -dynamiclib -Wl,-undefined,dynamic_lookup

$(LUA_CLIB_PATH) :
	mkdir $(LUA_CLIB_PATH)

$(CSERVICE_PATH) :
	mkdir $(CSERVICE_PATH)

#新增的c module服务
CSERVICE = 
#新增 lua-c库
LUA_CLIB = lfs cjson pb zlib chat_filter openssl

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
	$(CC) $(CFLAGS) $(SHARED) -Werror -pedantic -I3rd/lzlib $^ -L$(LUA_INC) -lz -o $@

$(LUA_CLIB_PATH)/chat_filter.so : 3rd/lua-chat_filter/lua-chat_filter.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@ -I3rd/lua-chat_filter

# 递归查找 3rd/lua-openssl 目录及其子目录下的所有 .c 文件和 .h 文件
SRCS := $(shell find 3rd/lua-openssl-0.9.0-0 -name '*.c')
HDRS := $(shell find 3rd/lua-openssl-0.9.0-0 -name '*.h')
INCS := $(sort $(dir $(HDRS)))  # 获取所有子目录路径
CFLAGS += $(foreach dir,$(INCS),-I$(dir))  # 添加递归搜索路径

$(LUA_CLIB_PATH)/openssl.so : $(SRCS) | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@ -I$(LUA_INC) -L$(LUA_INC) -L$(TLS_LIB) -I$(TLS_INC) -lssl

$(SKYNET):
	git submodule update --init
	chmod -R 744 skynet

$(SKYNET_BULDER):
	cd skynet && $(MAKE) PLAT=$(PLAT) TLS_MODULE=ltls TLS_LIB=$(TLS_LIB) TLS_INC=$(TLS_INC)

upskynet: $(SKYNET)
	git submodule update --remote

linux macosx freebsd: $(SKYNET) $(SKYNET_BULDER) \
 	$(LUA_CLIB_PATH) \
	$(foreach v,$(LUA_CLIB), $(LUA_CLIB_PATH)/$(v).so)
	$(foreach v, $(CSERVICE), $(eval $(call CSERVICE_TEMP,$(v))))

clean:
	cd skynet && $(MAKE) clean
	rm -f $(LUA_CLIB_PATH)/*.so
	rm -f $(CSERVICE_PATH)/*.so

cleanall: clean
	cd skynet && $(MAKE) cleanall