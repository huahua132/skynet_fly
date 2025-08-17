local args = {}
for word in string.gmatch(..., "%S+") do
	table.insert(args, word)
end

SERVICE_NAME = args[1]
LOG_SERVICE_NAME = args[1]
if args[1] == 'service_cell' then
	LOG_SERVICE_NAME = args[1] .. '-' .. args[2]
elseif args[1] == 'hot_container' then
	LOG_SERVICE_NAME = args[2] .. '-' .. args[#args - 1] .. '-' .. args[3]
end

local main, pattern

local err = {}
for pat in string.gmatch(LUA_SERVICE, "([^;]+);*") do
	local filename = string.gsub(pat, "?", SERVICE_NAME)
	local f, msg = loadfile(filename)
	if not f then
		table.insert(err, msg)
	else
		pattern = pat
		main = f
		break
	end
end

if not main then
	error(table.concat(err, "\n"))
end

LUA_SERVICE = nil
LUA_PRELOAD = nil
package.path , LUA_PATH = LUA_PATH, nil
package.cpath , LUA_CPATH = LUA_CPATH, nil

local service_path = string.match(pattern, "(.*/)[^/?]+$")

if service_path then
	service_path = string.gsub(service_path, "?", args[1])
	package.path = service_path .. "?.lua;" .. package.path
	SERVICE_PATH = service_path
else
	local p = string.match(pattern, "(.*/).+$")
	SERVICE_PATH = p
end
local skynet = require "skynet"
skynet.cache.mode "OFF"                --不启用代码缓存
local skynet_fly_path = skynet.getenv('skynet_fly_path')
local env_util = loadfile(skynet_fly_path .. '/lualib/skynet-fly/utils/env_util.lua')()
local pre_load = nil
local after_load = nil

pre_load = env_util.get_pre_load()
after_load = env_util.get_after_load()

local new_loaded = {}

local old_require = (require "skynet.require").require
local loaded = package.loaded
_G.require = function(name)
	if not loaded[name] then
		new_loaded[name] = true
	end
	return old_require(name)
end

_G._loaded = new_loaded

if pre_load then
	for pat in string.gmatch(pre_load, "([^;]+);*") do
		loadfile(pat)()
	end
	pre_load = nil
end

main(select(2, table.unpack(args)))

if after_load then
	for pat in string.gmatch(after_load, "([^;]+);*") do
		loadfile(pat)()
	end
	after_load = nil
end

_G._loaded = nil