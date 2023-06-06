package.cpath = "../../skynet/luaclib/?.so"
local lfs = require "lfs"
local args = {...}
local server_name = args[1]
assert(server_name)

local config = {
	thread = 4,
	bootstrap = "snlua bootstrap",   -- The service for bootstrap
	start = "main",  -- main script
	harbor = 0,
	server_path = '"./"',
	root_path = '"../"',
	skynet_path = '"../../skynet/"',

	cpath = 'root_path .. "cservice/?.so;" .. skynet_path .. "cservice/?.so"',
	lua_cpath = 'root_path .. "luaclib/?.so;" .. skynet_path .. "luaclib/?.so"',
	lualoader = 'skynet_path .. "/lualib/loader.lua"',
}



