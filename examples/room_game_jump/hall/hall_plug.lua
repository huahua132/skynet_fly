
local log = require "skynet-fly.log"
local skynet = require "skynet"
local container_client = require "skynet-fly.client.container_client"
local queue = require "skynet.queue"
local timer = require "skynet-fly.timer"
local pb_netpack = require "skynet-fly.netpack.pb_netpack"
local errors_msg = require "msg.errors_msg"
local login_msg = require "msg.login_msg"
local pcall = pcall
local next = next
local assert = assert

local ws_pbnet_util = require "skynet-fly.utils.net.ws_pbnet_util"
local pbnet_util = require "skynet-fly.utils.net.pbnet_util"

local g_interface_mgr = nil

local M = {}

--发包函数
M.unpack = pbnet_util.unpack
M.send = pbnet_util.send
M.broadcast = pbnet_util.broadcast
M.ws_unpack = ws_pbnet_util.unpack
M.ws_send = ws_pbnet_util.send
M.ws_broadcast = ws_pbnet_util.broadcast

M.disconn_time_out = timer.minute                   --掉线一分钟就清理

local function login_out_req(player_id,packname,pack_body)
	local ok,errorcode,errormsg = g_interface_mgr:goout(player_id)
	if ok then
		login_msg:login_out_res(player_id,{player_id = player_id})
	end
	return ok,errorcode,errormsg
end

local function match_req(player_id,packname,pack_body)
	local ok,errorcode,errormsg = g_interface_mgr:match_join_table(player_id,pack_body.table_name)
	if ok then
		login_msg:match_res(player_id,{table_id = errorcode})
	end
	return ok,errorcode,errormsg
end

local function server_info_req(player_id,packname,pack_body)
	local server_info = {
		player_id = player_id,
		hall_server_id = g_interface_mgr:get_hall_server_id(),
		alloc_server_id = g_interface_mgr:get_alloc_server_id(player_id),
		table_server_id = g_interface_mgr:get_table_server_id(player_id),
		table_id = g_interface_mgr:get_table_id(player_id),
	}
	login_msg:server_info_res(player_id,server_info)
	return true
end

function M.init(interface_mgr)
	g_interface_mgr = interface_mgr
	errors_msg = errors_msg:new(interface_mgr)
	login_msg = login_msg:new(interface_mgr)
	--pb
	g_interface_mgr:handle('.login.LoginOutReq',login_out_req)
	g_interface_mgr:handle('.login.matchReq',match_req)
	g_interface_mgr:handle('.login.serverInfoReq',server_info_req)
	pb_netpack.load("./proto")
end

function M.connect(player_id, is_jump_join)
	log.info("hall_plug connect ",player_id, g_interface_mgr:get_addr(player_id), is_jump_join, skynet.address(skynet.self()))
	return {
		player_id = player_id,
	}
end

function M.disconnect(player_id)
	log.info("hall_plug disconnect ",player_id)
end

function M.reconnect(player_id)
	log.info("hall_plug reconnect ",player_id, g_interface_mgr:get_addr(player_id))
	return {
		player_id = player_id,
	}
end

function M.goout(player_id, is_jump_exit)
	log.info("hall_plug goout ",player_id, is_jump_exit, skynet.address(skynet.self()))
end

-- 客户端消息处理结束
function M.handle_end(player_id, packname, pack_body, ret, errcode, errmsg)
	log.info("handle_end >>> ", packname, ret, errcode, errmsg)
	if not ret then
		errors_msg:errors(player_id, errcode, errmsg, packname)
	end
end

--进入桌子回调
function M.join_table(player_id, table_name, table_id)
	log.info("join_table >>> ", player_id, table_name, table_id)
end

--离开桌子回调
function M.leave_table(player_id, table_name, table_id)
	log.info("leave_table >>> ", player_id, table_name, table_id)
end

local CMD = {}

function CMD.hello(player_id)
	log.info("hello >>> ", g_interface_mgr:is_online(player_id))
	return g_interface_mgr:is_online(player_id)
end

M.register_cmd = CMD

return M