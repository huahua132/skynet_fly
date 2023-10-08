local log = require "log"
local skynet = require "skynet"
local contriner_client = require "contriner_client"
local pbnet_util = require "pbnet_util"
local pb_netpack = require "pb_netpack"
local timer = require "timer"
local errorcode = require "errorcode"
local errors_msg = require "errors_msg"
local login_msg = require "login_msg"

local assert = assert
local x_pcall = x_pcall

local agent_mgr = nil

local M = {}

--登录检测的超时时间
M.time_out = timer.second * 5
--解包函数
M.unpack = pbnet_util.unpack
--发包函数
M.send = pbnet_util.send

function M.init(agent_mgr)
	agent_mgr = agent_mgr
	errors_msg = errors_msg:new(agent_mgr)
	login_msg = login_msg:new(agent_mgr)
	pb_netpack.load('./proto')
end

--登录检测函数 packname,req是解包函数返回的
--登入成功后返回玩家id
function M.check(packname,pack_body)
	if not packname then
		log.error("unpack err ",packname,pack_body)
		return false
	end
	if packname ~= '.login.LoginReq' then
		log.error("login_check msg err ",packname)
		return false,errorcode.NOT_LOGIN,"please login"
	end

	local player_id = pack_body.player_id
	if not player_id then
		log.error("req err ",pack_body)
		return false,errorcode.REQ_PARAM_ERR,"not player_id"
	end

	if pack_body.password ~= '123456' then
		log.error("login err ",pack_body)
		return false,errorcode.LOGIN_PASS_ERR,"pass err"
	end

	return player_id
end

--登录失败
function M.login_failed(player_id,errcode,errmsg)
	log.info("login_failed:",player_id,errcode,errmsg)
	errors_msg:errors(player_id,errcode,errmsg)
end

--登录成功
function M.login_succ(player_id,login_res)
	login_msg:login_res(player_id,login_res)
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
function M.logining(player_id)
	errors_msg:errors(player_id,errorcode.LOGINING,"logining please waiting...")
end

--重复登录
function M.repeat_login(player_id)
	errors_msg:errors(player_id,errorcode.REPAET_LOGIN,"repeat_login")
end

return M