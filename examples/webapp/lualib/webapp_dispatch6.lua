local skynet = require "skynet"
local log = require "log"
local engine_web = require "engine_web"
local logger_mid = require "logger_mid"
local HTTP_STATUS = require "HTTP_STATUS"
local assert = assert

local string = string
local M = {}

--[[
	这是一个演示自定义中间件的示例
]]

--初始化一个纯净版
local app = engine_web:new()
--请求处理
M.dispatch = engine_web.dispatch(app)

--初始化
function M.init()
	--注册全局中间件
	app:use(logger_mid())

	--自定义中间件
	app:use(function(c)
		log.info("process begin :",c.req.path,c.req.method)

		--执行下一个中间件
		c:next()

		log.info("process end :",c.req.path,c.req.method)
	end)

	app:get("/",function(c)
		log.info("end point process ",c.req.path,c.req.method)
		c.res:set_rsp("hello skynet_fly",HTTP_STATUS.OK)
	end)

	app:run()
end

--服务退出
function M.exit()

end

return M