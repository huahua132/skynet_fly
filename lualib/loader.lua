local args = {}
for word in string.gmatch(..., "%S+") do
	table.insert(args, word)
end

SERVICE_NAME = args[1]

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
package.path , LUA_PATH = LUA_PATH
package.cpath , LUA_CPATH = LUA_CPATH

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
local skynet_fly_path = skynet.getenv('skynet_fly_path')
local env_util = loadfile(skynet_fly_path .. '/lualib/utils/env_util.lua')()
local pre_load = env_util.get_pre_load()
local after_load = env_util.get_after_load()

if pre_load then
	for pat in string.gmatch(pre_load, "([^;]+);*") do
		loadfile(pat)()
	end
	pre_load = nil
end

_G.require = (require "skynet.require").require

main(select(2, table.unpack(args)))

if after_load then
	for pat in string.gmatch(after_load, "([^;]+);*") do
		loadfile (pat)()
	end
	after_load = nil
end
