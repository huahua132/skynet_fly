local log = require "skynet-fly.log"
local skynet = require "skynet"
local container_client = require "skynet-fly.client.container_client"
local pb_netpack = require "skynet-fly.netpack.pb_netpack"
local sp_netpack = require "skynet-fly.netpack.sp_netpack"
local timer = require "skynet-fly.timer"
local errorcode = require "enum.errorcode"
local errors_msg = require "msg.errors_msg"
local login_msg = require "msg.login_msg"
local msg_id = require "enum.msg_id"
local pack_helper = require "common.pack_helper"

local pbnet_byid = require "skynet-fly.utils.net.pbnet_byid"
local ws_pbnet_byid = require "skynet-fly.utils.net.ws_pbnet_byid"

local spnet_byid = require "skynet-fly.utils.net.spnet_byid"
local ws_spnet_byid = require "skynet-fly.utils.net.ws_spnet_byid"

local assert = assert

local test_proto = skynet.getenv("test_proto")

local g_interface_mgr = nil

local M = {}

--登录检测的超时时间
M.time_out = timer.second * 5
--发包函数
if test_proto == 'pb' then
	M.unpack = pbnet_byid.unpack
	M.send = pbnet_byid.send
	M.broadcast = pbnet_byid.broadcast
	M.ws_unpack = ws_pbnet_byid.unpack
	M.ws_send = ws_pbnet_byid.send
	M.ws_broadcast = ws_pbnet_byid.broadcast
else
	--解包函数
	M.unpack = spnet_byid.unpack
	M.send = spnet_byid.send
	--广播函数
	M.broadcast = spnet_byid.broadcast
	--发包函数
	M.ws_unpack = ws_spnet_byid.unpack
	M.ws_send = ws_spnet_byid.send
	--广播函数
	M.ws_broadcast = ws_spnet_byid.broadcast
end

function M.init(interface_mgr)
	g_interface_mgr = interface_mgr
	errors_msg = errors_msg:new(g_interface_mgr)
	login_msg = login_msg:new(g_interface_mgr)
	pb_netpack.load('./proto') --pb方式 
	sp_netpack.load('./sproto') --sp方式
	pack_helper.set_packname_id()
	pack_helper.set_sp_packname_id()
end

--登录检测函数 packid,req是解包函数返回的
--登入成功后返回玩家id
function M.check(packid,pack_body)
	if packid ~= msg_id.login_LoginReq then
		log.error("login_check msg err ",packid)
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
	errors_msg:errors(player_id,errorcode.REPAET_LOGIN,"repeat_login")
end

return M