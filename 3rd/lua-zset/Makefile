all: skiplist.so

CC = gcc
CFLAGS = -g3 -O0 -Wall -fPIC --shared
LUA_INCLUDE_DIR ?= /usr/local/include
DEFS = -DLUA_COMPAT_5_2

luajit: LUA_INCLUDE_DIR = /usr/local/include/luajit-2.1
luajit: skiplist.so

skiplist.so: skiplist.h skiplist.c lua-skiplist.c
	$(CC)  $(CFLAGS)  -I$(LUA_INCLUDE_DIR) $(DEFS)  $^ -o $@

test:
	lua test_sl.lua

clean:
	-rm skiplist.so
