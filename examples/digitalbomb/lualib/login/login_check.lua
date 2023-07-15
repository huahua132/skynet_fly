local log = require "log"
local skynet = require "skynet"
local contriner_client = require "contriner_client"
local pbnet_util = require "pbnet_util"
local pb_util = require "pb_util"
local timer = require "timer"
local errorcode = require "errorcode"
local errors_msg = require "errors_msg"
local login_msg = require "login_msg"

local assert = assert
local x_pcall = x_pcall

local g_player_map = {}
local g_login_lock_map = {}
local g_gate = nil

local M = {}

--登录检测的超时时间
M.time_out = timer.second * 5

function M.init(gate)
	g_gate = gate
	pb_util.load('./proto')
end

--解包函数
M.unpack = pbnet_util.unpack

local function check_join(req,fd,player_id)
	--登录检查
	local login_res,errcode,errmsg
	if req.password ~= '123456' then
		log.error("login err ",req)
		return false,errorcode.LOGIN_PASS_ERR,"pass err"
	else
		local old_agent = g_player_map[player_id]
		local hall_client = nil
		if old_agent then
			hall_client = old_agent.hall_client
			skynet.send(g_gate,'lua','kick',old_agent.fd)
		else
			hall_client = contriner_client:new("hall_m",nil,function() return false end)
			hall_client:set_mod_num(player_id)
		end
		login_res,errcode,errmsg = hall_client:mod_call("join",player_id,req,fd,g_gate)
		if login_res then
			g_player_map[player_id] = {
				player_id = player_id,
				hall_client = hall_client,
				fd = fd,
			}
		else
			log.error("join hall err ",player_id)
			return false,errcode,errmsg
		end
	end
	return login_res
end

--登录检测函数 packname,req是解包函数返回的
--登入成功后返回玩家id
function M.check(fd,packname,req)
	if not packname then
		log.error("unpack err ",packname,req)
		return
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
	g_login_lock_map[player_id] = true
	local isok,login_res,code,errmsg = x_pcall(check_join,req,fd,player_id)
	g_login_lock_map[player_id] = false
	if not isok or not login_res then
		log.error("login err ",login_res,code,errmsg)
		errors_msg.errors(login_res,code,errmsg)
		return nil
	else
		login_msg.login_res(fd,login_res)
		return player_id
	end
end

--登出回调
function M.login_out(player_id)
	g_player_map[player_id] = nil
end

--掉线回调
function M.disconnect(fd,player_id)
	log.info('disconnect:',fd,player_id)
	assert(g_player_map[player_id])
	local agent = g_player_map[player_id]
	local hall_client = agent.hall_client

	hall_client:mod_send('disconnect',fd,player_id)
end

return M