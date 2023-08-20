T=openssl

PREFIX		?=/usr/local
PKG_CONFIG	?=pkg-config
CC		:= $(CROSS)$(CC)
AR		:= $(CROSS)$(AR)
LD		:= $(CROSS)$(LD)
LUA		:=

#OS auto detect
ifneq (,$(TARGET_SYS))
  SYS		:= $(TARGET_SYS)
else
  SYS		:= $(shell gcc -dumpmachine)
endif

#Lua auto detect
LUA_VERSION	:= $(shell $(PKG_CONFIG) luajit --print-provides)
ifeq ($(LUA_VERSION),)
  # Not found luajit package, try lua
  LUA_VERSION	:= $(shell $(PKG_CONFIG) lua --print-provides)
  ifeq ($(LUA_VERSION),)
    # Not found lua package, try from prefix
    LUA_VERSION := $(shell lua -e "_,_,v=string.find(_VERSION,'Lua (.+)');print(v)")
    LUA_CFLAGS	?= -I$(PREFIX)/include
    LUA_LIBS	?= -L$(PREFIX)/lib #-llua
    LUA_LIBDIR	?= $(PREFIX)/lib/lua/$(LUA_VERSION)
    LUA		:= lua
  else
    # Found lua package
    LUA_VERSION	:= $(shell lua -e "_,_,v=string.find(_VERSION,'Lua (.+)');print(v)")
    LUA_CFLAGS	?= $(shell $(PKG_CONFIG) lua --cflags)
    LUA_LIBS	?= $(shell $(PKG_CONFIG) lua --libs)
    LUA_LIBDIR	?= $(PREFIX)/lib/lua/$(LUA_VERSION)
    LUA		:= lua
  endif
else
  # Found luajit package
  LUA_VERSION	:= $(shell luajit -e "_,_,v=string.find(_VERSION,'Lua (.+)');print(v)")
  LUA_CFLAGS	?= $(shell $(PKG_CONFIG) luajit --cflags)
  LUA_LIBS	?= $(shell $(PKG_CONFIG) luajit --libs)
  LUA_LIBDIR	?= $(PREFIX)/lib/lua/$(LUA_VERSION)
  LUA		:= luajit
endif

#OpenSSL auto detect
OPENSSL_CFLAGS	?= $(shell $(PKG_CONFIG) openssl --cflags)
ifeq (${OPENSSL_STATIC},)
OPENSSL_LIBS	?= $(shell $(PKG_CONFIG) openssl --static --libs)
else
OPENSSL_LIBDIR  ?= $(shell $(PKG_CONFIG) openssl --variable=libdir)
OPENSSL_LIBS    ?= $(OPENSSL_LIBDIR)/libcrypto.a $(OPENSSL_LIBDIR)/libssl.a
endif

TARGET  = $(MAKECMDGOALS)
ifeq (coveralls, ${TARGET})
  CFLAGS	+=-g -fprofile-arcs -ftest-coverage
  LDFLAGS	+=-g -fprofile-arcs
endif

# asan {{{

ifeq (asan, ${TARGET})
ifneq (, $(findstring apple, $(SYS)))
  ASAN_LIB       = $(shell dirname $(shell dirname $(shell clang -print-libgcc-file-name)))/darwin/libclang_rt.asan_osx_dynamic.dylib
  LDFLAGS       +=-g -fsanitize=address
endif
ifneq (, $(findstring linux, $(SYS)))
  ASAN_LIB       = $(shell dirname $(shell cc -print-libgcc-file-name))/libasan.so
  LDFLAGS       +=-g -fsanitize=address -lubsan
endif
CC            ?= clang
LD            ?= clang
CFLAGS	+=-g -O0 -fsanitize=address,undefined
endif

# asan }}}

# tsan {{{

ifeq (tsan, ${TARGET})
ifneq (, $(findstring apple, $(SYS)))
  ASAN_LIB       = $(shell dirname $(shell dirname $(shell clang -print-libgcc-file-name)))/darwin/libclang_rt.tsan_osx_dynamic.dylib
  LDFLAGS       +=-g -fsanitize=thread
endif

ifneq (, $(findstring linux, $(SYS)))
  ASAN_LIB       = $(shell dirname $(shell cc -print-libgcc-file-name))/libtsan.so
  LDFLAGS       +=-g -fsanitize=thread -lubsan -ltsan
endif
CC            ?= clang
LD            ?= clang
CFLAGS	+=-g -O0 -fsanitize=thread
endif

# tsan }}}

ifeq (debug, ${TARGET})
  CFLAGS	+=-g -Og
  LDFLAGS       +=-g -Og
endif

ifeq (valgrind, ${TARGET})
  CFLAGS	+=-g -O0
  LDFLAGS	+=-g -O0
endif

ifneq (, $(findstring linux, $(SYS)))
  # Do linux things
  CFLAGS	+= -fPIC
  LDFLAGS	+= -fPIC # -Wl,--no-undefined
endif

ifneq (, $(findstring apple, $(SYS)))
  # Do darwin things
  CFLAGS	+= -fPIC
  LDFLAGS	+= -fPIC -Wl,-undefined,dynamic_lookup -ldl
  MACOSX_DEPLOYMENT_TARGET="10.12"
  CC		:= MACOSX_DEPLOYMENT_TARGET=${MACOSX_DEPLOYMENT_TARGET} $(CC)
endif

ifneq (, $(findstring mingw, $(SYS)))
  # Do mingw things
  CFLAGS	+= -DLUA_LIB -DLUA_BUILD_AS_DLL -DWIN32_LEAN_AND_MEAN
endif

ifneq (, $(findstring cygwin, $(SYS)))
  # Do cygwin things
  CFLAGS	+= -fPIC
endif

ifneq (, $(findstring iOS, $(SYS)))
  # Do iOS things
  CFLAGS	+= -fPIC
  LDFLAGS	+= -fPIC -ldl
endif

#custom config
ifeq (.config, $(wildcard .config))
  include .config
endif

CFLAGS		+= $(OPENSSL_CFLAGS) $(LUA_CFLAGS) $(TARGET_FLAGS)
LDFLAGS		+= $(OPENSSL_LIBS)
# Compilation directives
WARN_MIN	 = -Wall -Wno-unused-value -Wno-unused-function
WARN		 = -Wall
WARN_MOST	 = $(WARN) -W -Waggregate-return -Wcast-align -Wmissing-prototypes \
		   -Wnested-externs -Wshadow -Wwrite-strings -pedantic
CFLAGS		+= $(WARN_MIN) -Ideps -Ideps/lua-compat/c-api -Ideps/auxiliar

OBJS=src/asn1.o deps/auxiliar/auxiliar.o src/bio.o src/cipher.o src/cms.o src/compat.o \
     src/crl.o src/csr.o src/dh.o src/digest.o src/dsa.o src/ec.o src/engine.o         \
     src/hmac.o src/lbn.o src/lhash.o src/misc.o src/ocsp.o src/openssl.o src/ots.o    \
     src/pkcs12.o src/pkcs7.o src/pkey.o src/rsa.o src/ssl.o src/th-lock.o src/util.o  \
     src/x509.o src/xattrs.o src/xexts.o src/xname.o src/xstore.o src/xalgor.o         \
     src/callback.o src/srp.o src/mac.o deps/auxiliar/subsidiar.o

.PHONY: all install test info doc coveralls asan

.c.o:
	$(CC) $(CFLAGS) -c -o $@ $?

all: $T.so
	@echo "Target system: "$(SYS)

$T.so: lib$T.a
	$(CC) -shared -o $@ src/openssl.o -L. -l$T $(LDFLAGS)

lib$T.a: $(OBJS)
	$(AR) rcs $@ $?

install: all
	mkdir -p $(LUA_LIBDIR)
	cp $T.so $(LUA_LIBDIR)
doc:
	ldoc src -d doc

info:
	@echo "Target system: "$(SYS)
	@echo "CC:" $(CC)
	@echo "AR:" $(AR)
	@echo "PREFIX:" $(PREFIX)

test:	all
	cd test && LUA_CPATH=$(shell pwd)/?.so $(shell which $(LUA)) test.lua -v && cd ..

debug: all

coveralls: test
ifeq ($(CI),)
	lcov -c -d src -o ${T}.info
	genhtml -o ${T}.html -t "${T} coverage" --num-spaces 2 ${T}.info
endif

valgrind: all
	cd test && LUA_CPATH=$(shell pwd)/?.so \
	valgrind --gen-suppressions=all --suppressions=../.github/lua-openssl.supp \
	--error-exitcode=1 --leak-check=full --show-leak-kinds=all \
	--child-silent-after-fork=yes $(LUA) test.lua && cd ..

asan: all
ifneq (, $(findstring apple, $(SYS)))
	cd test && LUA_CPATH=$(shell pwd)/?.so \
	ASAN_LIB=$(ASAN_LIB) \
	LSAN_OPTIONS=suppressions=${shell pwd}/.github/asan.supp \
	DYLD_INSERT_LIBRARIES=$(ASAN_LIB) \
	$(LUA) test.lua && cd ..
endif
ifneq (, $(findstring linux, $(SYS)))
	cd test && LUA_CPATH=$(shell pwd)/?.so \
	ASAN_LIB=$(ASAN_LIB) \
	LSAN_OPTIONS=suppressions=${shell pwd}/.github/asan.supp \
	LD_PRELOAD=$(ASAN_LIB) \
	$(LUA) test.lua && cd ..
endif

tsan: all
ifneq (, $(findstring apple, $(SYS)))
	cd test && LUA_CPATH=$(shell pwd)/?.so \
	ASAN_LIB=$(ASAN_LIB) \
	LSAN_OPTIONS=suppressions=${shell pwd}/.github/asan.supp \
	DYLD_INSERT_LIBRARIES=$(ASAN_LIB) \
	$(LUA) test.lua && cd ..
endif
ifneq (, $(findstring linux, $(SYS)))
	cd test && LUA_CPATH=$(shell pwd)/?.so \
	ASAN_LIB=$(ASAN_LIB) \
	LSAN_OPTIONS=suppressions=${shell pwd}/.github/asan.supp \
	LD_PRELOAD=$(ASAN_LIB) \
	$(LUA) test.lua && cd ..
endif

clean:
	rm -rf $T.* lib$T.a $(OBJS) src/*.g*

# vim: ts=8 sw=8 noet
