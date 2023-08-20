all : help

help:
	@echo "支持下面命令:"
	@echo "make build       # 编译 skynet"
	@echo "make clean       # 清理"
	@echo "make cleanall    # 清理所有"

LUA_CLIB_PATH ?= luaclib
CSERVICE_PATH ?= cservice
LUA_INC ?= skynet/3rd/lua
CFLAGS = -g -O0 -Wall -I$(LUA_INC)
SHARED := -fPIC --shared

$(LUA_CLIB_PATH) :
	mkdir $(LUA_CLIB_PATH)

$(CSERVICE_PATH) :
	mkdir $(CSERVICE_PATH)

#新增的c module服务
CSERVICE = 
#新增 lua-c库
LUA_CLIB = lfs cjson pb zlib chat_filter rax openssl

define CSERVICE_TEMP
  $$(CSERVICE_PATH)/$(1).so : service-src/service_$(1).c | $$(CSERVICE_PATH)
	$$(CC) $$(CFLAGS) $$(SHARED) $$< -o $$@ -Iskynet-src
endef

$(LUA_CLIB_PATH)/lfs.so : 3rd/luafilesystem-1_8_0/src/lfs.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I3rd/luafilesystem-1_8_0/src $^ -o $@

$(LUA_CLIB_PATH)/cjson.so : 3rd/lua-cjson/lua_cjson.c 3rd/lua-cjson/strbuf.c 3rd/lua-cjson/fpconv.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I3rd/lua-cjson $^ -o $@

$(LUA_CLIB_PATH)/pb.so : 3rd/lua-protobuf-0.4.0/pb.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I3rd/lua-protobuf-0.4.0 $^ -o $@

$(LUA_CLIB_PATH)/zlib.so : 3rd/lzlib/lzlib.c | $(LUA_CLIB_PATH)
	$(CC) -g -Werror -I$(LUA_INC) -Wall -pedantic -O0 -fPIC -shared -lz -I3rd/lzlib -L$(LUA_INC)  $^ -o $@

$(LUA_CLIB_PATH)/chat_filter.so : 3rd/lua-chat_filter/lua-chat_filter.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@ -I3rd/lua-chat_filter

$(LUA_CLIB_PATH)/rax.so : 3rd/lua-rax/rax.c 3rd/lua-rax/lua_rax.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@ -I3rd/lua-rax

# 递归查找 3rd/lua-openssl 目录及其子目录下的所有 .c 文件和 .h 文件
SRCS := $(shell find 3rd/lua-openssl-0.8.5-0 -name '*.c')
HDRS := $(shell find 3rd/lua-openssl-0.8.5-0 -name '*.h')
INCS := $(sort $(dir $(HDRS)))  # 获取所有子目录路径
CFLAGS += $(foreach dir,$(INCS),-I$(dir))  # 添加递归搜索路径

TLS_LIB=/usr/bin/openssl
TLS_INC=/usr/include/openssl

$(LUA_CLIB_PATH)/openssl.so : $(SRCS) | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) $^ -o $@ -I$(LUA_INC) -L$(LUA_INC) -L$(TLS_LIB) -I$(TLS_INC) -lssl

build: \
 	$(LUA_CLIB_PATH) \
	$(foreach v,$(LUA_CLIB), $(LUA_CLIB_PATH)/$(v).so)
	$(foreach v, $(CSERVICE), $(eval $(call CSERVICE_TEMP,$(v))))
	cd skynet && $(MAKE) linux TLS_MODULE=ltls TLS_LIB=$(TLS_LIB) TLS_INC=$(TLS_INC)

clean:
	cd skynet && $(MAKE) clean
	rm -f $(LUA_CLIB_PATH)/*.so
	rm -f $(CSERVICE_PATH)/*.so

cleanall: clean
	cd skynet && $(MAKE) cleanall