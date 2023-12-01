
local log = require "log"
local skynet = require "skynet"
local contriner_client = require "contriner_client"
local queue = require "skynet.queue"
local timer = require "timer"
local module_cfg = require "module_info".get_cfg()
local pb_netpack = require "pb_netpack"
local errors_msg = require "errors_msg"
local login_msg = require "login_msg"
local pcall = pcall
local next = next
local assert = assert

local g_fd_map = {}
local g_interface_mgr = nil

local M = {}

M.unpack = require(module_cfg.net_util).unpack
M.send = require(module_cfg.net_util).send
--广播函数
M.broadcast = require(module_cfg.net_util).broadcast
M.disconn_time_out = timer.minute                   --掉线一分钟就清理

local function login_out_req(player_id,packname,pack_body)
	local ok,errorcode,errormsg = g_interface_mgr:goout(player_id)
	if not ok then
		log.error("dispatch err ",errorcode,errormsg)
		errors_msg:errors(player_id,errorcode,errormsg,packname)
	else
		login_msg:login_out_res(player_id,{player_id = player_id})
	end
end

local function match_req(player_id,packname,pack_body)
	local ok,errorcode,errormsg = g_interface_mgr:match_join_table(player_id,pack_body.table_name)
	if not ok then
		log.error("dispatch err ",errorcode,errormsg)
		errors_msg:errors(player_id,errorcode,errormsg,packname)
	else
		login_msg:match_res(player_id,{table_id = errorcode})
	end
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
	g_interface_mgr:handle('.login.LoginOutReq',login_out_req)
	g_interface_mgr:handle('.login.matchReq',match_req)
	g_interface_mgr:handle('.login.serverInfoReq',server_info_req)
	pb_netpack.load("./proto")
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

return M