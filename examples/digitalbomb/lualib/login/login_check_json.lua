local log = require "log"
local skynet = require "skynet"
local contriner_client = require "contriner_client"
local jsonet_util = require "jsonet_util"
local timer = require "timer"
local errorcode = require "errorcode"
local errors_msg_json = require "errors_msg_json"
local login_msg_json = require "login_msg_json"

local assert = assert
local x_pcall = x_pcall

local M = {}

--登录检测的超时时间
M.time_out = timer.second * 5

function M.init()

end

--解包函数
M.unpack = jsonet_util.unpack

--登录检测函数 packname,req是解包函数返回的
--登入成功后返回玩家id
function M.check(gate,fd,packname,req)
	if not packname then
		log.error("unpack err ",packname,req)
		return false
	end
	if packname ~= '.login.LoginReq' then
		log.error("login_check msg err ",fd)
		return false,errorcode.NOT_LOGIN,"please login"
	end

	local player_id = req.player_id
	if not player_id then
		log.error("req err ",fd,req)
		return false,errorcode.REQ_PARAM_ERR,"not player_id"
	end

	if req.password ~= '123456' then
		log.error("login err ",req)
		return false,errorcode.LOGIN_PASS_ERR,"pass err"
	end

	return player_id
end

--登录失败
function M.login_failed(gate,fd,player_id,errcode,errmsg)
	errors_msg_json.errors(gate,fd,errcode,errmsg)
end

--登录成功
function M.login_succ(gate,fd,player_id,login_res)
	log.info("login_succ:",gate,fd,player_id,login_res)
	login_msg_json.login_res(gate,fd,login_res)
end

--登出回调
function M.login_out(player_id)
	log.info("login_out ",player_id)
end

--掉线回调
function M.disconnect(gate,fd,player_id)
	log.info('disconnect:',fd,player_id)
end

--正在登录中
function M.logining(gate,fd,player_id)
	errors_msg_json.errors(gate,fd,errorcode.LOGINING,"logining please waiting...")
end

--重复登录
function M.repeat_login(gate,fd,player_id)
	errors_msg_json.errors(gate,fd,errorcode.REPAET_LOGIN,"repeat_login")
end

return M