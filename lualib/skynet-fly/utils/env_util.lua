local skynet = require "skynet"
local assert = assert
local loadfile = loadfile
local tostring = tostring

local g_svr_id = tonumber(skynet.getenv('svr_id'))
local g_svr_name = skynet.getenv('svr_name')

local M = {}

--添加服务启动之前加载的文件
function M.add_pre_load(path)
	assert(loadfile(path),"can`t loadfile :" ..tostring(path))
	local pre_load = M.get_pre_load()
	if not pre_load then
		pre_load = ""
	end

	pre_load = pre_load .. path .. ";"
	skynet.setenv("preload",pre_load)
end

function M.get_pre_load()
	return skynet.getenv("preload")
end

--添加服务启动之后加载的文件
function M.add_after_load(path)
	assert(loadfile(path),"can`t loadfile :" ..tostring(path))
	local old_after_load = M.get_after_load()
	if not old_after_load then
		old_after_load = ""
	end
	old_after_load = old_after_load .. path .. ";"

	skynet.setenv('afterload',old_after_load)
end

function M.get_after_load()
	return skynet.getenv('afterload')
end

--获取cluster svr_id
function M.get_svr_id()
	return g_svr_id
end

--获取cluster svrname
function M.get_svr_name()
	return g_svr_name
end

return M