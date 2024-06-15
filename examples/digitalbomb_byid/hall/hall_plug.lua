
local log = require "skynet-fly.log"
local skynet = require "skynet"
local contriner_client = require "skynet-fly.client.contriner_client"
local queue = require "skynet.queue"
local timer = require "skynet-fly.timer"
local module_cfg = require "skynet-fly.etc.module_info".get_cfg()
local pb_netpack = require "skynet-fly.netpack.pb_netpack"
local errors_msg = require "msg.errors_msg"
local login_msg = require "msg.login_msg"
local msg_id = require "enum.msg_id"
local pack_helper = require "common.pack_helper"
local pcall = pcall
local next = next
local assert = assert

local pbnet_byid = require "skynet-fly.utils.net.pbnet_byid"
local ws_pbnet_byid = require "skynet-fly.utils.net.ws_pbnet_byid"

local g_fd_map = {}
local g_interface_mgr = nil

local M = {}

--解包函数
M.unpack = pbnet_byid.unpack
--发包函数
M.send = pbnet_byid.send
--广播函数
M.broadcast = pbnet_byid.broadcast

--解包函数
M.ws_unpack = ws_pbnet_byid.unpack
--发包函数
M.ws_send = ws_pbnet_byid.send
--广播函数
M.ws_broadcast = ws_pbnet_byid.broadcast

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
end

function M.init(interface_mgr)
	g_interface_mgr = interface_mgr
	errors_msg = errors_msg:new(interface_mgr)
	login_msg = login_msg:new(interface_mgr)
	g_interface_mgr:handle(msg_id.login_LoginOutReq,login_out_req)
	g_interface_mgr:handle(msg_id.login_matchReq,match_req)
	g_interface_mgr:handle(msg_id.login_serverInfoReq,server_info_req)
	pb_netpack.load("./proto")
	pack_helper.set_packname_id()
end

function M.connect(player_id)
	log.info("hall_plug connect ",player_id)
	return {
		player_id = player_id,
	}
end

function M.disconnect(player_id)
	log.info("hall_plug disconnect ",player_id)
end

function M.reconnect(player_id)
	log.info("hall_plug reconnect ",player_id)
	return {
		player_id = player_id,
	}
end

function M.goout(player_id)
	log.info("hall_plug goout ",player_id)
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
------------------------------------服务退出回调-------------------------------------
function M.herald_exit()
    log.error("预告退出")
end

function M.exit()
    log.error("退出")
    return true
end

function M.fix_exit()
    log.error("确认要退出")
end

function M.cancel_exit()
    log.error("取消退出")
end

function M.check_exit()
    log.error("检查退出")
    return true
end

return M