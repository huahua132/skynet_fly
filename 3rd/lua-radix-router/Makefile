.PHONY: install test test-coverage bench lint

install:
	luarocks make

test:
	busted spec/

test-coverage:
	busted --coverage spec/

lint:
	luacheck .

CMD=luajit
bench:
	RADIX_ROUTER_ROUTES=100000 RADIX_ROUTER_TIMES=10000000 $(CMD) benchmark/static-paths.lua
	RADIX_ROUTER_ROUTES=100000 RADIX_ROUTER_TIMES=10000000 $(CMD) benchmark/simple-variable.lua
	RADIX_ROUTER_ROUTES=1000000 RADIX_ROUTER_TIMES=10000000 $(CMD) benchmark/simple-variable.lua
	RADIX_ROUTER_ROUTES=100000 RADIX_ROUTER_TIMES=10000000 $(CMD) benchmark/simple-prefix.lua
	RADIX_ROUTER_ROUTES=100000 RADIX_ROUTER_TIMES=1000000 $(CMD) benchmark/complex-variable.lua
	RADIX_ROUTER_ROUTES=100000 RADIX_ROUTER_TIMES=10000000 $(CMD) benchmark/simple-variable-binding.lua
	RADIX_ROUTER_TIMES=1000000 $(CMD) benchmark/github-routes.lua
