local skynet = require "skynet"
local log = require "log"
local engine_web = require "engine_web"
local logger_mid = require "logger_mid"
local HTTP_STATUS = require "HTTP_STATUS"
local assert = assert

local string = string
local M = {}

--[[
	这是一个演示query 和 post from的示例

	测试调用
	curl -X POST -d 'name=skynet_fly&email=skynet_fly@email.com' 'http://127.0.0.1:80/login?player_id=10001&nickname=skynet_fly'
]]

--初始化一个纯净版
local app = engine_web:new()
--请求处理
M.dispatch = engine_web.dispatch(app)

--初始化
function M.init()
	--注册全局中间件
	app:use(logger_mid())

	app:post("/login",function(c)
		local player_id = c.req.query.player_id
		assert(player_id)

		log.error("query:",c.req.query)
		log.error("post from:",c.req.body)

		c.res:set_rsp("hello " .. player_id,HTTP_STATUS.OK)
	end)

	app:run()
end

--服务退出
function M.exit()

end

return M