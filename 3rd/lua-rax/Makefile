UNAME ?= $(shell uname)
LUA_INCLUDE_DIR ?= /usr/local/include
#LUA_INCLUDE_DIR = ../lua-5.4.4/src

CFLAGS := -O2 -g -Wall -fpic -std=c99 -Wno-pointer-to-int-cast -Wno-int-to-pointer-cast -I$(LUA_INCLUDE_DIR)
#-DRAX_DEBUG_MSG

C_SO_NAME := rax.so
LDFLAGS := -shared

# on Mac OS X, one should set instead:
# for Mac OS X environment, use one of options
ifeq ($(UNAME),Darwin)
	LDFLAGS := -bundle -undefined dynamic_lookup
endif

OBJS := rax.o lua_rax.o

.PHONY: default
default: compile

### clean:        Remove generated files
.PHONY: clean
clean:
	rm -f $(C_SO_NAME) $(OBJS)

### compile:      Compile library
.PHONY: compile

compile: $(C_SO_NAME)

${OBJS} : %.o : %.c
	$(CC) $(CFLAGS) -c $< -o $@

${C_SO_NAME} : ${OBJS}
	$(CC) $(LDFLAGS) $(OBJS) -o $@

### help:         Show Makefile rules
.PHONY: help
help:
	@echo Makefile rules:
	@echo
	@grep -E '^### [-A-Za-z0-9_]+:' Makefile | sed 's/###/   /'
