local skynet = require "skynet"
local log = require "log"
local engine_web = require "engine_web"
local logger_mid = require "logger_mid"
local HTTP_STATUS = require "HTTP_STATUS"
local assert = assert

local string = string
local M = {}

--[[
	这是一个演示文件的示例

	浏览器访问:http://192.168.1.164/login/test.webp
]]

--初始化一个纯净版
local app = engine_web:new()
--请求处理
M.dispatch = engine_web.dispatch(app)

--初始化
function M.init()
	--注册全局中间件
	app:use(logger_mid())

	app:static_file('/login/test.webp','/test.webp')

	app:run()
end

--服务退出
function M.exit()

end

return M