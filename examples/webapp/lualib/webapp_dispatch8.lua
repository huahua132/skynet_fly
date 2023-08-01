local skynet = require "skynet"
local log = require "log"
local engine_web = require "engine_web"
local logger_mid = require "logger_mid"
local HTTP_STATUS = require "HTTP_STATUS"
local assert = assert

local string = string
local M = {}

--[[
	这是一个演示多路由中间件的示例
]]

--初始化一个纯净版
local app = engine_web:new()
--请求处理
M.dispatch = engine_web.dispatch(app)

--初始化
function M.init()
	--注册全局中间件
	app:use(logger_mid())
	do
		local v1 = app:group("v1")
		--注册v1路由组的中间件
		v1:use(function(c)
			log.info("process begin v1 mid ",c.req.path,c.req.method)
			c:next()
			log.info("process end v1 mid ",c.req.path,c.req.method)
		end)
		v1:get('/login',function(c)
			log.info("v1 login ")
		end)

		v1:get('/logout',function(c)
			log.info("v1 logout ")
		end)
	end

	do
		local v2 = app:group("v2")
		--注册v2路由组的中间件
		v2:use(function(c)
			log.info("process begin v2 mid ",c.req.path,c.req.method)
			c:next()
			log.info("process end v2 mid ",c.req.path,c.req.method)
		end)
		v2:get('/login',function(c)
			log.info("v2 login ")
		end)

		v2:get('/logout',function(c)
			log.info("v2 logout ")
		end)
	end

	app:run()
end

--服务退出
function M.exit()

end

return M