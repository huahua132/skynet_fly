local skynet = require "skynet"
local log = require "log"
local engine_web = require "engine_web"
local logger_mid = require "logger_mid"
local HTTP_STATUS = require "HTTP_STATUS"

local string = string
local M = {}

--[[
	这是一个演示params的示例
]]

--初始化一个纯净版
local app = engine_web:new()
--请求处理
M.dispatch = engine_web.dispatch(app)

--初始化
function M.init()
	--注册全局中间件
	app:use(logger_mid())
	
	--/login 路径不会命中
	--/login/123 会命中
	app:get("/login/:player_id/*",function(c)
		local params = c.params
		local player_id = params.player_id

		log.error("params:",params)
		log.error("path:",c.req.path)
		log.error("body:",c.req.body,c.req.body_raw)

		c.res:set_rsp("hello " .. player_id,HTTP_STATUS.OK)
	end)

	app:run()
end

--服务退出
function M.exit()

end

return M