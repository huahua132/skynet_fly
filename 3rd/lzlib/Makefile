# $Id: Makefile,v 1.8 2004/07/22 19:10:47 tngd Exp $
# makefile for zlib library for Lua

# dist location
DISTDIR=dist
TMP=/tmp

# change these to reflect your Lua installation
LUA= ../lua
LUAINC= $(LUA)
LUALIB= $(LUA)
LUABIN= $(LUA)

ZLIB=../zlib-1.2.3

# no need to change anything below here
CFLAGS= $(INCS) $(DEFS) $(WARN) -O0 -fPIC
WARN= -g -Werror -Wall -pedantic #-ansi
INCS= -I$(LUAINC) -I$(ZLIB)
LIBS= -L$(ZLIB) -lz -L$(LUALIB) -L$(LUABIN) #-llua51

MYLIB=lzlib

ZLIB_NAME = zlib
GZIP_NAME = gzip

T_ZLIB= $(ZLIB_NAME).so
T_GZIP= $(GZIP_NAME).so

VER=0.4-work3
TARFILE = $(DISTDIR)/$(MYLIB)-$(VER).tar.gz
TARFILES = Makefile README README.lgzip CHANGES \
	lzlib.c gzip.lua \
	test_zlib2.lua \
	test_zlib3.lua \
	test_gzip.lua \
	test_prologue.lua

all: $(T_ZLIB) # $(T_GZIP)

test: $(T_ZLIB) # $(T_GZIP)
	$(LUABIN)/lua -lluarc test_prologue.lua
	$(LUABIN)/lua -lluarc test_gzip.lua
	$(LUABIN)/lua -lluarc test_zlib2.lua
	$(LUABIN)/lua -lluarc test_zlib3.lua

$(T_ZLIB): lzlib.o
	$(CC) -o $@ -shared $< $(LIBS)

$(T_GZIP): lgzip.o
	$(CC) -o $@ -shared $< $(LIBS)

clean:
	rm -f *.o *.so core core.* a.out

dist: $(TARFILE)

$(TARFILE): $(TARFILES)
	@ln -sf `pwd` $(TMP)/$(MYLIB)-$(VER)
	tar -zcvf $(TARFILE) -C $(TMP) $(addprefix $(MYLIB)-$(VER)/,$(TARFILES))
	@rm -f $(TMP)/$(MYLIB)-$(VER)
	@# @lsum $(TARFILE) $(DISTDIR)/md5sums.txt
