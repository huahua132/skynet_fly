
local log = require "skynet-fly.log"
local skynet = require "skynet"
local container_client = require "skynet-fly.client.container_client"
local queue = require "skynet.queue"
local timer = require "skynet-fly.timer"
local pb_netpack = require "skynet-fly.netpack.pb_netpack"
local sp_netpack = require "skynet-fly.netpack.sp_netpack"
local errors_msg = require "msg.errors_msg"
local rsp_msg = require "msg.rsp_msg"
local msg_id = require "enum.msg_id"
local pack_helper = require "common.pack_helper"
local pcall = pcall
local next = next
local assert = assert
local tunpack = table.unpack

local pbnet_byrpc = require "skynet-fly.utils.net.pbnet_byrpc"
local ws_pbnet_byrpc = require "skynet-fly.utils.net.ws_pbnet_byrpc"

local spnet_byrpc = require "skynet-fly.utils.net.spnet_byrpc"
local ws_spnet_byrpc = require "skynet-fly.utils.net.ws_spnet_byrpc"

local g_interface_mgr = nil

local test_proto = skynet.getenv("test_proto")

local M = {}

--发包函数
if test_proto == 'pb' then
	M.unpack = pbnet_byrpc.unpack
	M.send = pbnet_byrpc.send
	M.broadcast = pbnet_byrpc.broadcast
	M.ws_unpack = ws_pbnet_byrpc.unpack
	M.ws_send = ws_pbnet_byrpc.send
	M.ws_broadcast = ws_pbnet_byrpc.broadcast
else
	--解包函数
	M.unpack = spnet_byrpc.unpack
	M.send = spnet_byrpc.send
	--广播函数
	M.broadcast = spnet_byrpc.broadcast
	--发包函数
	M.ws_unpack = ws_spnet_byrpc.unpack
	M.ws_send = ws_spnet_byrpc.send
	--广播函数
	M.ws_broadcast = ws_spnet_byrpc.broadcast
end
--rpc包处理工具
M.rpc_pack = require "skynet-fly.utils.net.rpc_server"

M.disconn_time_out = timer.minute                   --掉线一分钟就清理

local function login_out_req(player_id, packname, pack_body, rsp_session)
	local ok,errorcode,errormsg = g_interface_mgr:goout(player_id)
	if ok then
		return {player_id = player_id}
	end
	return ok, errorcode, errormsg
end

local function match_req(player_id, packname, pack_body, rsp_session)
	local ok, errorcode, errormsg = g_interface_mgr:match_join_table(player_id,pack_body.table_name)
	if ok then
		return {table_id = ok}
	end
	return ok, errorcode, errormsg
end

local function server_info_req(player_id, packname, pack_body, rsp_session)
	local server_info = {
		player_id = player_id,
		hall_server_id = g_interface_mgr:get_hall_server_id(),
		alloc_server_id = g_interface_mgr:get_alloc_server_id(player_id),
		table_server_id = g_interface_mgr:get_table_server_id(player_id),
		table_id = g_interface_mgr:get_table_id(player_id),
	}
	
	return server_info
end

function M.init(interface_mgr)
	g_interface_mgr = interface_mgr
	errors_msg = errors_msg:new(interface_mgr)
	rsp_msg = rsp_msg:new(interface_mgr)
	g_interface_mgr:handle(msg_id.login_LoginOutReq,login_out_req)
	g_interface_mgr:handle(msg_id.login_matchReq,match_req)
	g_interface_mgr:handle(msg_id.login_serverInfoReq,server_info_req)
	pb_netpack.load("./proto")
	sp_netpack.load("./sproto")
	pack_helper.set_packname_id()
	pack_helper.set_sp_packname_id()
end

function M.connect(player_id)
	local test_big = ""
	-- for i = 1, 1024 * 64 do
	-- 	test_big = test_big .. "a"
	-- end
	log.info("hall_plug connect ",player_id)
	return {
		player_id = player_id,
		test_big = test_big,
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
function M.handle_end_rpc(player_id, packid, pack_body, rsp_session, handle_res)
	log.info("handle_end_rpc >>> ", player_id, packid, pack_body, rsp_session, handle_res)
	local ret, errcode, errmsg = tunpack(handle_res)
	if not ret then
		errors_msg:errors(player_id, errcode, errmsg, packid, rsp_session)
	else
		rsp_msg:rsp_msg(player_id, packid, ret, rsp_session)
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