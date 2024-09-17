local skynet = require "skynet"
local log = require "skynet-fly.log"
local engine_web = require "skynet-fly.web.engine_web"
local HTTP_STATUS = require "skynet-fly.web.HTTP_STATUS"
local time_util = require "skynet-fly.utils.time_util"

local string = string
local M = {}

--[[
	这是一个最简单的示例
]]

--初始化一个纯净版
local app = engine_web:new()
--请求处理
M.dispatch = engine_web.dispatch(app)

--初始化
function M.init()
	app:get("/",function(c)
		c.res:set_rsp("hello skynet_fly " .. os.date("%Y%m%d %H:%M:%S",time_util.time()),HTTP_STATUS.OK)
	end)

	app:get("/ping",function(c)
		c.res:set_json_rsp({
			message = "pong"
		})
	end)

	app:run()
end

--服务退出
function M.exit()

end

return M