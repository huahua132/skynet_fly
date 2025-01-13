---#API
---#content ---
---#content title: env_util env相关
---#content date: 2024-06-29 22:00:00
---#content categories: ["skynet_fly API 文档","工具函数"]
---#content category_bar: true
---#content tags: [skynet_fly_api]
---#content ---
---#content [env_util](https://github.com/huahua132/skynet_fly/blob/master/lualib/skynet-fly/utils/env_util.lua)
local skynet = require "skynet"
local assert = assert
local loadfile = loadfile
local tostring = tostring

local g_svr_id = tonumber(skynet.getenv('svr_id'))
local g_svr_name = skynet.getenv('svr_name')

local M = {}

---#desc 添加服务启动之前加载的lua文件
---@param path string 路径
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

---#desc 添加服务启动之后加载的lua文件
---@param path string 路径
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

---#desc 获取cluster svr_id
function M.get_svr_id()
	return g_svr_id
end

---#desc 获取cluster svrname
function M.get_svr_name()
	return g_svr_name
end

return M