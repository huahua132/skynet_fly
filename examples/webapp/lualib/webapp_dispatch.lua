local skynet = require "skynet"
local log = require "log"
local engine_web = require "engine_web"
local HTTP_STATUS = require "HTTP_STATUS"

local string = string
local M = {}

--[[
	这是一个最简单的示例
]]

--默认使用logger中间件
local app = engine_web:new()
--请求处理
M.dispatch = engine_web.dispatch(app)

--初始化
function M.init()
	app:get("/",function(c)
		c.res:set_rsp("hello skynet_fly",HTTP_STATUS.OK)
	end)

	app:run()
end

--服务退出
function M.exit()

end

return M