local skynet = require "skynet"
local log = require "skynet-fly.log"
local engine_web = require "skynet-fly.web.engine_web"
local logger_mid = require "skynet-fly.web.middleware.logger_mid"
local HTTP_STATUS = require "skynet-fly.web.HTTP_STATUS"
local assert = assert

local string = string
local M = {}

--[[
	这是一个演示静态文件夹的示例

	浏览器访问:http://127.0.0.1/login/2.PNG
	浏览器访问:http://127.0.0.1/login/1.jpg
]]

--初始化一个纯净版
local app = engine_web:new()
--请求处理
M.dispatch = engine_web.dispatch(app)

--初始化
function M.init()
	--注册全局中间件
	app:use(logger_mid())

	app:static_dir("/login","./static/imgs")

	app:run()
end

--服务退出
function M.exit()

end

return M