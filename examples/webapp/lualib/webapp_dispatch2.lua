local skynet = require "skynet"
local log = require "log"
local engine_web = require "engine_web"
local logger_mid = require "logger_mid"
local HTTP_STATUS = require "HTTP_STATUS"

local string = string
local M = {}

--[[
	这是一个演示处理没有命中路由的示例
]]

--初始化一个纯净版
local app = engine_web:new()
--请求处理
M.dispatch = engine_web.dispatch(app)

--初始化
function M.init()
	--注册全局中间件
	app:use(logger_mid())

	--注册没有找到的路径处理函数
	app:set_no_route(function(c)
		local method = c.req.method
		log.error("no route handle begin 1:",method)

		c:next()
	
		log.error("not route handle end 1:",c.res.status,c.res.resp_header,c.res.body)
	end,
	function(c)
		local method = c.req.method
		log.error("no route handle begin 2:",method)

		c:next()
	
		log.error("not route handle end 2:",c.res.status,c.res.resp_header,c.res.body)
	end)
	
	app:run()
end

--服务退出
function M.exit()

end

return M