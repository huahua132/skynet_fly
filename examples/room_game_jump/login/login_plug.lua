local log = require "skynet-fly.log"
local skynet = require "skynet"
local pb_netpack = require "skynet-fly.netpack.pb_netpack"
local timer = require "skynet-fly.timer"
local errorcode = require "enum.errorcode"
local errors_msg = require "msg.errors_msg"
local login_msg = require "msg.login_msg"

local ws_pbnet_util = require "skynet-fly.utils.net.ws_pbnet_util"

local assert = assert

local g_interface_mgr = nil

local M = {}

--登录检测的超时时间
M.time_out = timer.second * 5
--发包函数
M.ws_unpack = ws_pbnet_util.unpack
M.ws_send = ws_pbnet_util.send
M.ws_broadcast = ws_pbnet_util.broadcast

--是否跳转到新的game_hall 服务
M.is_jump_new = true
M.jump_once_cnt = 1

function M.init(interface_mgr)
	g_interface_mgr = interface_mgr
	errors_msg = errors_msg:new(g_interface_mgr)
	login_msg = login_msg:new(g_interface_mgr)
	pb_netpack.load('./proto')
end

--登录检测函数 packname,req是解包函数返回的
--登入成功后返回玩家id
function M.check(packname,pack_body)
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
function M.disconnect(player_id)
	log.info('disconnect:',player_id)
end

--正在登录中
function M.logining(player_id)
	log.info("logining >>> ",player_id)
end

--重复登录
function M.repeat_login(player_id)
	log.info("repeat_login >>> ",player_id)
end

return M